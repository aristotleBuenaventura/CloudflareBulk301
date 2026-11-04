import 'package:flutter/material.dart';

import '../models/domain_result.dart';
import '../services/canonical_parser.dart';
import '../services/canonical_worker_source.dart';
import '../services/cloudflare_api.dart';
import '../services/session_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._session);

  final SessionService _session;

  bool _isLoading = false;
  String? _errorMessage;
  List<DomainResult> _results = [];
  List<DomainResult> _canonicalResults = [];
  ThemeMode _themeMode = ThemeMode.light;

  bool get isAuthenticated => _session.isAuthenticated;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  bool get isAccountToken => _session.isAccountToken;

  String? get accountEmail => _session.accountEmail;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  List<DomainResult> get results => List.unmodifiable(_results);

  List<DomainResult> get canonicalResults =>
      List.unmodifiable(_canonicalResults);

  Future<bool> login(String apiToken) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final api = CloudflareApi(_normalizeToken(apiToken));
      final user = await api.verifyToken();
      _session.startSession(
        apiToken: _normalizeToken(apiToken),
        email: user.email,
        isAccountToken: user.isAccountToken,
      );
      notifyListeners();
      return true;
    } on CloudflareApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      _errorMessage = 'Connection failed: $error';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _session.endSession();
    _results = [];
    _canonicalResults = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Max concurrent Cloudflare API jobs. High enough for speed; capped to
  /// reduce rate-limit risk on large lists.
  static const int _bulkConcurrency = 25;

  Future<void> applyBulkRedirects({
    required List<String> domains,
    required String targetUrl,
    bool wildcard = true,
    void Function(int completed, int total)? onProgress,
  }) async {
    final token = _session.apiToken;
    if (token == null) {
      throw StateError('Not authenticated.');
    }

    final uniqueDomains = domains
        .map((domain) => domain.trim())
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList();

    _results = uniqueDomains
        .map((domain) => DomainResult(domain: domain))
        .toList();
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    final api = CloudflareApi(token);
    var completed = 0;
    final total = _results.length;

    Future<void> processIndex(int i) async {
      final domain = _results[i].domain;

      try {
        final zone = await api.findZone(domain);
        if (zone == null) {
          _results[i] = _results[i].copyWith(
            status: DomainResultStatus.failed,
            message: 'Zone not found for "$domain". '
                'Check: (1) domain is added in Cloudflare, '
                '(2) API token includes All zones, '
                '(3) use apex name e.g. example.com not www.example.com.',
          );
        } else {
          final result = await api.createFullDomainRedirect(
            zoneId: zone.id,
            sourceDomain: domain,
            targetBaseUrl: targetUrl,
            wildcard: wildcard,
          );

          var message = result.message;
          if (zone.pendingNote.isNotEmpty) {
            message = '$message\n${zone.pendingNote}';
          }

          _results[i] = _results[i].copyWith(
            status: result.created
                ? DomainResultStatus.success
                : DomainResultStatus.skipped,
            zoneId: zone.id,
            message: message,
          );
        }
      } on CloudflareApiException catch (error) {
        _results[i] = _results[i].copyWith(
          status: DomainResultStatus.failed,
          message: error.message,
        );
      } catch (error) {
        _results[i] = _results[i].copyWith(
          status: DomainResultStatus.failed,
          message: error.toString(),
        );
      }

      completed++;
      onProgress?.call(completed, total);
      notifyListeners();
    }

    await _runConcurrent(
      total: total,
      concurrency: _bulkConcurrency,
      run: processIndex,
    );

    _setLoading(false);
    notifyListeners();
  }

  Future<void> applyCanonicalRules({
    required String leftText,
    required String rightText,
    void Function(int completed, int total)? onProgress,
  }) async {
    final token = _session.apiToken;
    if (token == null) {
      throw StateError('Not authenticated.');
    }

    final rules = CanonicalParser.parse(
      leftText: leftText,
      rightText: rightText,
    );
    if (rules.isEmpty) {
      throw ArgumentError('No valid source URLs found.');
    }

    final byHost = <String, List<CanonicalRule>>{};
    for (final rule in rules) {
      final host = rule.hostname;
      if (host.isEmpty) {
        continue;
      }
      byHost.putIfAbsent(host, () => []).add(rule);
    }

    final hosts = byHost.keys.toList()..sort();
    _canonicalResults = [
      DomainResult(domain: 'Worker: ${CanonicalWorkerSource.scriptName}'),
      ...hosts.map((host) => DomainResult(domain: host)),
    ];
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    final api = CloudflareApi(token);
    final total = _canonicalResults.length;
    var completed = 0;

    void bumpProgress() {
      completed++;
      onProgress?.call(completed, total);
      notifyListeners();
    }

    String? accountId;
    try {
      accountId = await api.resolveAccountId();
      final existing = await api.getCanonicalMap(accountId);
      final merged = Map<String, String>.from(existing);
      for (final rule in rules) {
        merged[rule.sourceUrl] = rule.canonicalUrl;
        // Domain-root rules also apply to every page on that host.
        if (_isDomainRoot(rule.sourceUrl)) {
          merged['__host__:${rule.hostname}'] = rule.canonicalUrl;
        }
      }

      await api.uploadCanonicalWorker(
        accountId: accountId,
        canonicalMap: merged,
      );

      _canonicalResults[0] = _canonicalResults[0].copyWith(
        status: DomainResultStatus.success,
        message:
            'Worker uploaded with ${merged.length} URL mapping(s) '
            '(+${rules.length} from this apply).',
      );
    } on CloudflareApiException catch (error) {
      _canonicalResults[0] = _canonicalResults[0].copyWith(
        status: DomainResultStatus.failed,
        message: error.message,
      );
      for (var i = 1; i < _canonicalResults.length; i++) {
        _canonicalResults[i] = _canonicalResults[i].copyWith(
          status: DomainResultStatus.failed,
          message: 'Skipped — Worker upload failed.',
        );
      }
      bumpProgress();
      for (var i = 1; i < total; i++) {
        bumpProgress();
      }
      _setLoading(false);
      notifyListeners();
      return;
    } catch (error) {
      _canonicalResults[0] = _canonicalResults[0].copyWith(
        status: DomainResultStatus.failed,
        message: error.toString(),
      );
      for (var i = 1; i < _canonicalResults.length; i++) {
        _canonicalResults[i] = _canonicalResults[i].copyWith(
          status: DomainResultStatus.failed,
          message: 'Skipped — Worker upload failed.',
        );
      }
      bumpProgress();
      for (var i = 1; i < total; i++) {
        bumpProgress();
      }
      _setLoading(false);
      notifyListeners();
      return;
    }

    bumpProgress();

    Future<void> processHost(int resultIndex) async {
      final host = _canonicalResults[resultIndex].domain;
      final hostRules = byHost[host] ?? const <CanonicalRule>[];

      try {
        final zone = await api.findZone(host);
        if (zone == null) {
          _canonicalResults[resultIndex] = _canonicalResults[resultIndex]
              .copyWith(
            status: DomainResultStatus.failed,
            message: 'Zone not found for "$host". '
                'Add the domain in Cloudflare and ensure the token '
                'includes All zones.',
          );
        } else {
          final result = await api.ensureCanonicalRoute(
            zoneId: zone.id,
            hostname: host,
          );

          final sample = hostRules
              .take(3)
              .map((r) => '${r.sourceUrl} → ${r.canonicalUrl}')
              .join('\n');
          final more = hostRules.length > 3
              ? '\n…and ${hostRules.length - 3} more'
              : '';

          var message =
              '${result.message}\n${hostRules.length} canonical URL(s):\n$sample$more';
          if (zone.pendingNote.isNotEmpty) {
            message = '$message\n${zone.pendingNote}';
          }

          _canonicalResults[resultIndex] = _canonicalResults[resultIndex]
              .copyWith(
            status: result.created
                ? DomainResultStatus.success
                : DomainResultStatus.skipped,
            zoneId: zone.id,
            message: message,
          );
        }
      } on CloudflareApiException catch (error) {
        _canonicalResults[resultIndex] = _canonicalResults[resultIndex]
            .copyWith(
          status: DomainResultStatus.failed,
          message: error.message,
        );
      } catch (error) {
        _canonicalResults[resultIndex] = _canonicalResults[resultIndex]
            .copyWith(
          status: DomainResultStatus.failed,
          message: error.toString(),
        );
      }

      bumpProgress();
    }

    await _runConcurrent(
      total: hosts.length,
      concurrency: _bulkConcurrency,
      run: (i) => processHost(i + 1),
    );

    _setLoading(false);
    notifyListeners();
  }

  /// Runs [run] for indices `0..total-1` with up to [concurrency] in flight.
  Future<void> _runConcurrent({
    required int total,
    required int concurrency,
    required Future<void> Function(int index) run,
  }) async {
    if (total == 0) {
      return;
    }

    final limit = concurrency < 1 ? 1 : concurrency;
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final i = next;
        if (i >= total) {
          return;
        }
        next++;
        await run(i);
      }
    }

    final workers = List.generate(
      total < limit ? total : limit,
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  void clearResults() {
    _results = [];
    notifyListeners();
  }

  void clearCanonicalResults() {
    _canonicalResults = [];
    notifyListeners();
  }

  String _normalizeToken(String token) {
    return token.trim().replaceAll(RegExp(r'\s+'), '');
  }

  bool _isDomainRoot(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    return path == '/' && !uri.hasQuery;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
