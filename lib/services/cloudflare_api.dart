import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/redirect_create_result.dart';
import 'canonical_worker_source.dart';

class CloudflareApiException implements Exception {
  CloudflareApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CloudflareUser {
  const CloudflareUser({
    required this.email,
    required this.id,
    this.isAccountToken = false,
  });

  final String email;
  final String id;
  final bool isAccountToken;
}

class CloudflareZone {
  const CloudflareZone({
    required this.id,
    required this.name,
    required this.status,
  });

  final String id;
  final String name;
  final String status;

  bool get isNotYetActive =>
      status == 'pending' || status == 'initializing';

  String get pendingNote => isNotYetActive
      ? 'Rule saved. Redirect will work once nameservers point to Cloudflare '
          'and the zone status becomes Active.'
      : '';
}

class CloudflareApi {
  CloudflareApi(this._token);

  static const _baseUrl = 'https://api.cloudflare.com/client/v4';

  final String _token;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  Future<CloudflareUser> verifyToken() async {
    if (_token.startsWith('cfat_')) {
      return _verifyAccountToken();
    }
    return _verifyUserToken();
  }

  Future<CloudflareUser> _verifyUserToken() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/user/tokens/verify'),
      headers: _headers,
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _formatAuthError(body, response.statusCode),
        statusCode: response.statusCode,
      );
    }

    final userResponse = await http.get(
      Uri.parse('$_baseUrl/user'),
      headers: _headers,
    );
    final userBody = _decode(userResponse);
    if (userBody.success) {
      final user = userBody.result as Map<String, dynamic>?;
      return CloudflareUser(
        email: user?['email'] as String? ?? 'Cloudflare account',
        id: user?['id'] as String? ?? '',
      );
    }

    return const CloudflareUser(
      email: 'Cloudflare user token',
      id: '',
    );
  }

  Future<CloudflareUser> _verifyAccountToken() async {
    final accountsResponse = await http.get(
      Uri.parse('$_baseUrl/accounts'),
      headers: _headers,
    );

    final accountsBody = _decode(accountsResponse);
    if (!accountsBody.success) {
      throw CloudflareApiException(
        _formatAuthError(accountsBody, accountsResponse.statusCode),
        statusCode: accountsResponse.statusCode,
      );
    }

    final accounts = accountsBody.result as List<dynamic>? ?? [];
    if (accounts.isEmpty) {
      throw CloudflareApiException(
        'No Cloudflare accounts found for this token.',
        statusCode: accountsResponse.statusCode,
      );
    }

    final map = accounts.first as Map<String, dynamic>;
    final accountId = map['id'] as String?;
    if (accountId == null) {
      throw CloudflareApiException('Could not read Cloudflare account ID.');
    }

    return CloudflareUser(
      email: map['name'] as String? ?? 'Cloudflare account',
      id: accountId,
      isAccountToken: true,
    );
  }

  Future<String?> findZoneId(String domain) async {
    final zone = await findZone(domain);
    return zone?.id;
  }

  Future<CloudflareZone?> findZone(String domain) async {
    for (final candidate in _domainCandidates(domain)) {
      final zones = await _fetchZonesByName(candidate);
      for (final zone in zones) {
        if (zone.name == candidate) {
          return zone;
        }
      }
    }

    return null;
  }

  Future<List<CloudflareZone>> _fetchZonesByName(String name) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/zones?name=${Uri.encodeComponent(name)}&match=all'),
      headers: _headers,
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to look up zone.',
        statusCode: response.statusCode,
      );
    }

    final zones = body.result as List<dynamic>? ?? [];
    return zones.map((zone) {
      final map = zone as Map<String, dynamic>;
      return CloudflareZone(
        id: map['id'] as String,
        name: (map['name'] as String).toLowerCase(),
        status: map['status'] as String? ?? 'unknown',
      );
    }).toList();
  }

  List<String> _domainCandidates(String domain) {
    final normalized = _normalizeDomain(domain);
    final candidates = <String>{normalized};

    if (normalized.startsWith('www.')) {
      candidates.add(normalized.substring(4));
    } else {
      candidates.add('www.$normalized');
    }

    return candidates.toList();
  }

  /// Creates a 301 redirect using Page Rules (user tokens) or Redirect Rules (account tokens).
  Future<RedirectCreateResult> createFullDomainRedirect({
    required String zoneId,
    required String sourceDomain,
    required String targetBaseUrl,
    required bool wildcard,
  }) async {
    final target = _normalizeTargetUrl(targetBaseUrl);

    if (_token.startsWith('cfat_')) {
      await _removeAllPageRulesForDomain(zoneId, sourceDomain);
      return _createDynamicRedirectRule(
        zoneId: zoneId,
        sourceDomain: sourceDomain,
        target: target,
        wildcard: wildcard,
      );
    }

    try {
      try {
        await _removeBulk301RedirectRules(zoneId);
      } catch (_) {
        // Ignore — may not have Redirect Rules on this zone.
      }
      return await _createPageRule(
        zoneId: zoneId,
        sourceDomain: sourceDomain,
        target: target,
        wildcard: wildcard,
      );
    } on CloudflareApiException catch (error) {
      if (_isPageRulesUnsupportedMessage(error.message)) {
        await _removeAllPageRulesForDomain(zoneId, sourceDomain);
        return _createDynamicRedirectRule(
          zoneId: zoneId,
          sourceDomain: sourceDomain,
          target: target,
          wildcard: wildcard,
        );
      }
      rethrow;
    }
  }

  Future<RedirectCreateResult> _createPageRule({
    required String zoneId,
    required String sourceDomain,
    required String target,
    required bool wildcard,
  }) async {
    final domain = _normalizeDomain(sourceDomain);
    final pattern = _pageRulePattern(domain, wildcard);
    final forwardUrl = _pageRuleForwardUrl(target, wildcard);
    final summary = _redirectSummary(domain, target, wildcard);

    await _removeAllPageRulesForDomain(zoneId, domain);

    final existingRules = await _listPageRules(zoneId);
    final priority = _nextPageRulePriority(existingRules);

    final response = await http.post(
      Uri.parse('$_baseUrl/zones/$zoneId/pagerules'),
      headers: _headers,
      body: jsonEncode({
        'targets': [
          {
            'target': 'url',
            'constraint': {
              'operator': 'matches',
              'value': pattern,
            },
          },
        ],
        'actions': [
          {
            'id': 'forwarding_url',
            'value': {
              'url': forwardUrl,
              'status_code': 301,
            },
          },
        ],
        'priority': priority,
        'status': 'active',
      }),
    );

    final body = _decode(response);
    if (!body.success) {
      final message = _firstError(body) ?? 'Failed to create Page Rule.';
      if (_isPageRulesUnsupportedError(body, message)) {
        throw CloudflareApiException(message, statusCode: response.statusCode);
      }
      throw CloudflareApiException(message, statusCode: response.statusCode);
    }

    final verified = await _findActivePageRuleAfterCreate(
      zoneId,
      pattern,
      forwardUrl,
    );
    if (verified == null) {
      throw CloudflareApiException(
        'Cloudflare did not save the Page Rule. '
        'Ensure your token has Zone → Page Rules → Edit permission.',
      );
    }

    return RedirectCreateResult.created(
      'Page Rule created: $summary. Check Rules → Page Rules.',
    );
  }

  Future<RedirectCreateResult> _createDynamicRedirectRule({
    required String zoneId,
    required String sourceDomain,
    required String target,
    required bool wildcard,
  }) async {
    final domain = _normalizeDomain(sourceDomain);
    final summary = _redirectSummary(domain, target, wildcard);
    final targetUrl = _dynamicTargetUrl(target, wildcard);
    final expression = _redirectExpression(domain, wildcard);

    await _removeAllPageRulesForDomain(zoneId, domain);
    try {
      await _removeBulk301RedirectRules(zoneId);
    } on CloudflareApiException catch (error) {
      if (!_isRedirectRulesPermissionError(error)) {
        rethrow;
      }
    }

    final rulePayload = {
      'description': 'Bulk 301 redirect (Cloudflare Bulk301 app)',
      'expression': expression,
      'action': 'redirect',
      'action_parameters': {
        'from_value': {
          'status_code': 301,
          'target_url': targetUrl,
          'preserve_query_string': wildcard,
        },
      },
      'enabled': true,
    };

    final entrypoint = await _getRedirectEntrypoint(zoneId);
    if (entrypoint != null) {
      final rulesetId = entrypoint['id'] as String;
      await _addRuleToRuleset(
        zoneId,
        rulesetId,
        {
          'ref': 'bulk301_${domain.hashCode.abs()}',
          ...rulePayload,
        },
      );
    } else {
      await _createRedirectRuleset(zoneId, [
        {
          'ref': 'bulk301_${domain.hashCode.abs()}',
          ...rulePayload,
        },
      ]);
    }

    final verifiedEntrypoint = await _getRedirectEntrypoint(zoneId);
    final verifiedRules = (verifiedEntrypoint?['rules'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (!_hasMatchingDynamicRule(verifiedRules, target, wildcard)) {
      throw CloudflareApiException(
        'Cloudflare did not save the Redirect Rule. '
        'Ensure your token has Zone → Single Redirect → Edit permission.',
        statusCode: 403,
      );
    }

    Map<String, dynamic>? matchingRule;
    for (final rule in verifiedRules) {
      if (_isDuplicateDynamicRule(rule, target, wildcard)) {
        matchingRule = rule;
        break;
      }
    }

    final ruleId = matchingRule?['id'] as String?;

    return RedirectCreateResult.created(
      'Redirect Rule saved${ruleId != null ? ' (ID: $ruleId)' : ''}.\n'
      '⚠️ NOT in Page Rules — open Rules → Overview → Redirect Rules in Cloudflare.',
    );
  }

  Future<void> _removeAllPageRulesForDomain(
    String zoneId,
    String sourceDomain,
  ) async {
    final domain = _normalizeDomain(sourceDomain);
    final rules = await _listPageRules(zoneId);
    final deleted = <String>{};

    for (final rule in rules) {
      if (rule['status'] != 'active') {
        continue;
      }

      final actions = rule['actions'] as List<dynamic>? ?? [];
      final hasForwarding = actions.any(
        (action) => (action as Map<String, dynamic>)['id'] == 'forwarding_url',
      );
      if (!hasForwarding) {
        continue;
      }

      final targets = rule['targets'] as List<dynamic>? ?? [];
      final matchesDomain = targets.any((target) {
        final map = target as Map<String, dynamic>;
        final constraint = map['constraint'] as Map<String, dynamic>?;
        final pattern = constraint?['value'] as String?;
        return _isPageRulePatternForDomain(pattern, domain);
      });

      if (!matchesDomain) {
        continue;
      }

      final ruleId = rule['id'] as String?;
      if (ruleId == null || !deleted.add(ruleId)) {
        continue;
      }

      await _deletePageRule(zoneId, ruleId);
    }
  }

  Future<void> _removeBulk301RedirectRules(String zoneId) async {
    final entrypoint = await _getRedirectEntrypoint(zoneId);
    if (entrypoint == null) {
      return;
    }

    final rulesetId = entrypoint['id'] as String;
    final rules =
        (entrypoint['rules'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    for (final rule in rules) {
      if (!_isBulk301RedirectRule(rule)) {
        continue;
      }

      final ruleId = rule['id'] as String?;
      if (ruleId == null) {
        continue;
      }

      await _deleteRedirectRule(zoneId, rulesetId, ruleId);
    }
  }

  Future<void> _deletePageRule(String zoneId, String ruleId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/zones/$zoneId/pagerules/$ruleId'),
      headers: _headers,
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to remove Page Rule.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _deleteRedirectRule(
    String zoneId,
    String rulesetId,
    String ruleId,
  ) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/zones/$zoneId/rulesets/$rulesetId/rules/$ruleId'),
      headers: _headers,
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to remove Redirect Rule.',
        statusCode: response.statusCode,
      );
    }
  }

  bool _isPageRulePatternForDomain(String? pattern, String domain) {
    if (pattern == null) {
      return false;
    }

    final normalized = _normalizePattern(pattern) ?? '';
    final d = domain.toLowerCase();
    final candidates = {
      _normalizePattern('*$d/*'),
      _normalizePattern('https://$d/*'),
      _normalizePattern('$d/*'),
      _normalizePattern('http://$d/*'),
      _normalizePattern('*$d*'),
    };

    return candidates.contains(normalized);
  }

  bool _isBulk301RedirectRule(Map<String, dynamic> rule) {
    if (rule['action'] != 'redirect') {
      return false;
    }

    final description = rule['description'] as String? ?? '';
    return description.contains('Cloudflare Bulk301 app') ||
        description.contains('Bulk 301 redirect');
  }

  Future<void> _createRedirectRuleset(
    String zoneId,
    List<Map<String, dynamic>> rules,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/zones/$zoneId/rulesets'),
      headers: _headers,
      body: jsonEncode({
        'name': 'Redirect rules ruleset',
        'kind': 'zone',
        'phase': 'http_request_dynamic_redirect',
        'rules': rules,
      }),
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _formatRulesetError(body, response.statusCode) ??
            'Failed to create redirect rule.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _addRuleToRuleset(
    String zoneId,
    String rulesetId,
    Map<String, dynamic> rule,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/zones/$zoneId/rulesets/$rulesetId/rules'),
      headers: _headers,
      body: jsonEncode(rule),
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _formatRulesetError(body, response.statusCode) ??
            'Failed to add redirect rule.',
        statusCode: response.statusCode,
      );
    }
  }

  bool _hasMatchingDynamicRule(
    List<Map<String, dynamic>> rules,
    String target,
    bool wildcard,
  ) {
    return rules.any(
      (rule) => _isDuplicateDynamicRule(rule, target, wildcard),
    );
  }

  bool _isDuplicateDynamicRule(
    Map<String, dynamic> rule,
    String target,
    bool wildcard,
  ) {
    if (rule['action'] != 'redirect') {
      return false;
    }

    final params = rule['action_parameters'] as Map<String, dynamic>?;
    final fromValue = params?['from_value'] as Map<String, dynamic>?;
    final targetUrl = fromValue?['target_url'] as Map<String, dynamic>?;
    if (targetUrl == null) {
      return false;
    }

    if (wildcard) {
      return targetUrl['expression'] ==
          'concat("$target", http.request.uri.path)';
    }

    return _normalizeForwardUrl(targetUrl['value'] as String?) ==
        _normalizeForwardUrl(target);
  }

  bool _isPageRulesUnsupportedError(_ApiResponse body, String? message) {
    final code = body.errors.isNotEmpty ? body.errors.first['code'] : null;
    return code == 1011 || _isPageRulesUnsupportedMessage(message);
  }

  bool _isPageRulesUnsupportedMessage(String? message) {
    if (message == null) {
      return false;
    }
    final lower = message.toLowerCase();
    return lower.contains('account owned') ||
        lower.contains('account-owned') ||
        lower.contains('does not support account');
  }

  Future<Map<String, dynamic>?> _getRedirectEntrypoint(String zoneId) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/zones/$zoneId/rulesets/phases/http_request_dynamic_redirect/entrypoint',
      ),
      headers: _headers,
    );

    if (response.statusCode == 404) {
      return null;
    }

    final body = _decode(response);
    if (!body.success) {
      final message = _firstError(body);
      if (response.statusCode == 404 ||
          (message?.toLowerCase().contains('not found') ?? false)) {
        return null;
      }
      if (_isPermissionStatusCode(response.statusCode, message)) {
        throw CloudflareApiException(
          _formatRulesetError(body, response.statusCode) ??
              'Missing Redirect Rules permission.',
          statusCode: response.statusCode,
        );
      }
      return null;
    }

    return body.result as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> _listPageRules(String zoneId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/zones/$zoneId/pagerules'),
      headers: _headers,
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to list Page Rules.',
        statusCode: response.statusCode,
      );
    }

    return (body.result as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> _findActivePageRuleAfterCreate(
    String zoneId,
    String pattern,
    String forwardUrl,
  ) async {
    final rules = await _listPageRules(zoneId);
    return _findActivePageRule(rules, pattern, forwardUrl);
  }

  Map<String, dynamic>? _findActivePageRule(
    List<Map<String, dynamic>> rules,
    String pattern,
    String forwardUrl,
  ) {
    for (final rule in rules) {
      if (rule['status'] != 'active') {
        continue;
      }

      final targets = rule['targets'] as List<dynamic>? ?? [];
      final actions = rule['actions'] as List<dynamic>? ?? [];

      final matchesPattern = targets.any((target) {
        final map = target as Map<String, dynamic>;
        final constraint = map['constraint'] as Map<String, dynamic>?;
        return _normalizePattern(constraint?['value'] as String?) ==
            _normalizePattern(pattern);
      });

      final matchesForward = actions.any((action) {
        final map = action as Map<String, dynamic>;
        if (map['id'] != 'forwarding_url') {
          return false;
        }
        final value = map['value'] as Map<String, dynamic>?;
        final url = _normalizeForwardUrl(value?['url'] as String?);
        final statusCode = value?['status_code'];
        return url == _normalizeForwardUrl(forwardUrl) &&
            (statusCode == 301 || statusCode == '301');
      });

      if (matchesPattern && matchesForward) {
        return rule;
      }
    }

    return null;
  }

  String? _normalizePattern(String? pattern) {
    return pattern?.trim().toLowerCase();
  }

  String? _normalizeForwardUrl(String? url) {
    if (url == null) {
      return null;
    }
    var normalized = url.trim();
    if (normalized.endsWith('/') && !normalized.contains(r'$')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  int _nextPageRulePriority(List<Map<String, dynamic>> rules) {
    if (rules.isEmpty) {
      return 1;
    }

    var highest = 0;
    for (final rule in rules) {
      final priority = rule['priority'];
      if (priority is int && priority > highest) {
        highest = priority;
      }
    }

    return highest + 1;
  }

  String _pageRulePattern(String domain, bool wildcard) {
    if (wildcard) {
      return '*$domain/*';
    }
    return '$domain/*';
  }

  String _redirectExpression(String domain, bool wildcard) {
    if (wildcard) {
      return 'true';
    }
    return '(http.host eq "$domain")';
  }

  String _pageRuleForwardUrl(String target, bool wildcard) {
    if (wildcard) {
      return '$target/\$2';
    }
    return target;
  }

  Map<String, dynamic> _dynamicTargetUrl(String target, bool wildcard) {
    if (wildcard) {
      return {
        'expression': 'concat("$target", http.request.uri.path)',
      };
    }
    return {'value': target};
  }

  String _redirectSummary(String domain, String target, bool wildcard) {
    if (wildcard) {
      return '*$domain/* → $target/\$2';
    }
    return '$domain/* → $target';
  }

  _ApiResponse _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw CloudflareApiException('Unexpected response from Cloudflare.');
    }

    return _ApiResponse(
      success: decoded['success'] == true,
      result: decoded['result'],
      errors: (decoded['errors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }

  String? _formatRulesetError(_ApiResponse body, int statusCode) {
    final message = _firstError(body);
    if (_isPermissionStatusCode(statusCode, message)) {
      return 'Missing Redirect Rules permission. '
          'Add Zone → Single Redirect → Edit (or Dynamic URL Redirects Write) '
          'to your API token.\n\nCloudflare: ${message ?? 'HTTP $statusCode'}';
    }
    return message;
  }

  bool _isRedirectRulesPermissionError(CloudflareApiException error) {
    return _isPermissionStatusCode(error.statusCode, error.message);
  }

  bool _isPermissionStatusCode(int? statusCode, String? message) {
    if (statusCode == 401 || statusCode == 403) {
      return true;
    }

    final lower = message?.toLowerCase() ?? '';
    return lower.contains('authentication') ||
        lower.contains('unauthorized') ||
        lower.contains('permission') ||
        lower.contains('not allowed') ||
        lower.contains('forbidden') ||
        lower.contains('missing the permissions');
  }

  String? _firstError(_ApiResponse body) {
    if (body.errors.isEmpty) {
      return null;
    }
    return body.errors.first['message'] as String?;
  }

  String _formatAuthError(_ApiResponse body, int statusCode) {
    final message = _firstError(body);
    final code = body.errors.isNotEmpty ? body.errors.first['code'] : null;

    if (code == 9109 ||
        (message?.toLowerCase().contains('location') ?? false)) {
      final blockedIp = _extractBlockedIp(message);
      if (blockedIp != null) {
        return 'Cloudflare blocked IP: $blockedIp\n\n'
            'Add this exact IP to your token allowlist. '
            'Mac often uses IPv6 — add both IPv4 and IPv6, or remove IP filtering.';
      }
      return 'This token has IP restrictions. Add your current IPv4 and IPv6 '
          'to the token allowlist, or remove the IP filter.';
    }

    if (_token.startsWith('cfat_') &&
        message?.toLowerCase().contains('invalid api token') == true) {
      return 'Account API token could not be verified. Check that the token is active and has the required permissions.';
    }

    return message ?? 'Authentication failed (HTTP $statusCode).';
  }

  String? _extractBlockedIp(String? message) {
    if (message == null) {
      return null;
    }
    final match = RegExp(r'location:\s*(.+)$').firstMatch(message.trim());
    return match?.group(1)?.trim();
  }

  String _normalizeDomain(String domain) {
    var value = domain.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.split('/').first;
    return value;
  }

  String _normalizeTargetUrl(String url) {
    var value = url.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.parse(value);
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final host = uri.host.isEmpty ? uri.path : uri.host;
    var normalized = '$scheme://$host';
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      normalized = '$normalized:${uri.port}';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  // --- Canonical injection (Workers) -------------------------------------

  Future<String> resolveAccountId() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/accounts?per_page=50'),
      headers: _headers,
    );
    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ??
            'Failed to list Cloudflare accounts. '
                'Ensure the token can access account resources '
                '(Workers Scripts Edit).',
        statusCode: response.statusCode,
      );
    }

    final accounts = body.result as List<dynamic>? ?? [];
    if (accounts.isEmpty) {
      throw CloudflareApiException('No Cloudflare accounts found for this token.');
    }

    final map = accounts.first as Map<String, dynamic>;
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) {
      throw CloudflareApiException('Could not read Cloudflare account ID.');
    }
    return id;
  }

  /// Returns the existing canonical URL map from the Worker binding, or `{}`.
  Future<Map<String, String>> getCanonicalMap(String accountId) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/accounts/$accountId/workers/scripts/'
        '${CanonicalWorkerSource.scriptName}/settings',
      ),
      headers: _headers,
    );

    if (response.statusCode == 404) {
      return {};
    }

    final body = _decode(response);
    if (!body.success) {
      // Script may not exist yet.
      return {};
    }

    final result = body.result as Map<String, dynamic>? ?? {};
    final bindings = result['bindings'] as List<dynamic>? ?? [];
    for (final binding in bindings) {
      if (binding is! Map<String, dynamic>) {
        continue;
      }
      if (binding['name'] == 'CANONICAL_MAP_JSON' &&
          binding['type'] == 'plain_text') {
        final text = binding['text'] as String? ?? '{}';
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            return decoded.map(
              (key, value) => MapEntry(key, value?.toString() ?? ''),
            );
          }
        } catch (_) {
          return {};
        }
      }
    }
    return {};
  }

  /// Uploads / updates the shared canonical Worker with the given URL map.
  Future<void> uploadCanonicalWorker({
    required String accountId,
    required Map<String, String> canonicalMap,
  }) async {
    final metadata = jsonEncode({
      'main_module': 'worker.js',
      'compatibility_date': '2024-09-23',
      'bindings': [
        {
          'type': 'plain_text',
          'name': 'CANONICAL_MAP_JSON',
          'text': jsonEncode(canonicalMap),
        },
      ],
    });

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(
        '$_baseUrl/accounts/$accountId/workers/scripts/'
        '${CanonicalWorkerSource.scriptName}',
      ),
    );
    request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(
      http.MultipartFile.fromString(
        'metadata',
        metadata,
        contentType: MediaType('application', 'json'),
      ),
    );
    request.files.add(
      http.MultipartFile.fromString(
        'worker.js',
        CanonicalWorkerSource.javascript,
        filename: 'worker.js',
        contentType: MediaType('application', 'javascript+module'),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ??
            'Failed to upload canonical Worker. '
                'Ensure Account → Workers Scripts → Edit is on the token.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Ensures Workers routes for [hostname] point at the canonical Worker.
  ///
  /// Always rewrites existing routes (never skips). Uses `*{hostname}/*`
  /// so apex + www + all paths are covered. Legacy `hostname/*` routes are
  /// upgraded to the preferred pattern.
  Future<RedirectCreateResult> ensureCanonicalRoute({
    required String zoneId,
    required String hostname,
  }) async {
    final preferred = '*$hostname/*';
    final legacy = '$hostname/*';
    final existing = await _listWorkerRoutes(zoneId);

    Map<String, dynamic>? preferredMatch;
    Map<String, dynamic>? legacyMatch;
    for (final route in existing) {
      final pattern = route['pattern'] as String?;
      if (pattern == preferred) {
        preferredMatch = route;
      } else if (pattern == legacy) {
        legacyMatch = route;
      }
    }

    // Prefer updating an existing preferred route in place.
    if (preferredMatch != null) {
      final routeId = preferredMatch['id'] as String?;
      if (routeId != null) {
        await _updateWorkerRoute(
          zoneId: zoneId,
          routeId: routeId,
          pattern: preferred,
          script: CanonicalWorkerSource.scriptName,
        );
      }

      if (legacyMatch != null) {
        final legacyId = legacyMatch['id'] as String?;
        if (legacyId != null) {
          await _deleteWorkerRoute(zoneId: zoneId, routeId: legacyId);
        }
      }

      return RedirectCreateResult.created(
        'Workers route rewritten: $preferred → '
        '${CanonicalWorkerSource.scriptName}',
      );
    }

    // Upgrade legacy pattern to preferred.
    if (legacyMatch != null) {
      final routeId = legacyMatch['id'] as String?;
      if (routeId != null) {
        await _updateWorkerRoute(
          zoneId: zoneId,
          routeId: routeId,
          pattern: preferred,
          script: CanonicalWorkerSource.scriptName,
        );
        return RedirectCreateResult.created(
          'Workers route rewritten: $legacy → $preferred → '
          '${CanonicalWorkerSource.scriptName}',
        );
      }
    }

    await _createWorkerRoute(
      zoneId: zoneId,
      pattern: preferred,
      script: CanonicalWorkerSource.scriptName,
    );
    return RedirectCreateResult.created(
      'Workers route created: $preferred → '
      '${CanonicalWorkerSource.scriptName}',
    );
  }

  Future<void> _deleteWorkerRoute({
    required String zoneId,
    required String routeId,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/zones/$zoneId/workers/routes/$routeId'),
      headers: _headers,
    );
    final body = _decode(response);
    if (!body.success && response.statusCode != 404) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to delete Workers route.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _listWorkerRoutes(String zoneId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/zones/$zoneId/workers/routes'),
      headers: _headers,
    );
    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ??
            'Failed to list Workers routes. '
                'Ensure Zone → Workers Routes → Edit is on the token.',
        statusCode: response.statusCode,
      );
    }
    return (body.result as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> _createWorkerRoute({
    required String zoneId,
    required String pattern,
    required String script,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/zones/$zoneId/workers/routes'),
      headers: _headers,
      body: jsonEncode({
        'pattern': pattern,
        'script': script,
      }),
    );
    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to create Workers route for $pattern.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _updateWorkerRoute({
    required String zoneId,
    required String routeId,
    required String pattern,
    required String script,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/zones/$zoneId/workers/routes/$routeId'),
      headers: _headers,
      body: jsonEncode({
        'pattern': pattern,
        'script': script,
      }),
    );
    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to update Workers route for $pattern.',
        statusCode: response.statusCode,
      );
    }
  }
}

class _ApiResponse {
  const _ApiResponse({
    required this.success,
    required this.result,
    required this.errors,
  });

  final bool success;
  final dynamic result;
  final List<Map<String, dynamic>> errors;
}
