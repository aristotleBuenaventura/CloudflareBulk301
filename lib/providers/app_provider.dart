import 'package:flutter/foundation.dart';

import '../models/domain_result.dart';
import '../services/cloudflare_api.dart';
import '../services/session_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._session);

  final SessionService _session;

  bool _isLoading = false;
  String? _errorMessage;
  List<DomainResult> _results = [];

  bool get isAuthenticated => _session.isAuthenticated;

  bool get isAccountToken => _session.isAccountToken;

  String? get accountEmail => _session.accountEmail;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  List<DomainResult> get results => List.unmodifiable(_results);

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
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> applyBulkRedirects({
    required List<String> domains,
    required String targetUrl,
    required bool preservePath,
    required bool preserveQueryString,
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

    for (var i = 0; i < _results.length; i++) {
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
            preservePath: preservePath,
            preserveQueryString: preserveQueryString,
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
      onProgress?.call(completed, _results.length);
      notifyListeners();

      if (i < _results.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    _setLoading(false);
    notifyListeners();
  }

  void clearResults() {
    _results = [];
    notifyListeners();
  }

  String _normalizeToken(String token) {
    return token.trim().replaceAll(RegExp(r'\s+'), '');
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
