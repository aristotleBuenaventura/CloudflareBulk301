import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudflareApiException implements Exception {
  CloudflareApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CloudflareUser {
  const CloudflareUser({required this.email, required this.id});

  final String email;
  final String id;
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
    final response = await http.get(
      Uri.parse('$_baseUrl/user/tokens/verify'),
      headers: _headers,
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Invalid API token.',
        statusCode: response.statusCode,
      );
    }

    final userResponse = await http.get(
      Uri.parse('$_baseUrl/user'),
      headers: _headers,
    );
    final userBody = _decode(userResponse);
    if (!userBody.success) {
      throw CloudflareApiException(
        _firstError(userBody) ?? 'Could not load account details.',
        statusCode: userResponse.statusCode,
      );
    }

    final user = userBody.result as Map<String, dynamic>?;
    return CloudflareUser(
      email: user?['email'] as String? ?? 'Cloudflare account',
      id: user?['id'] as String? ?? '',
    );
  }

  Future<String?> findZoneId(String domain) async {
    final normalized = _normalizeDomain(domain);
    final response = await http.get(
      Uri.parse('$_baseUrl/zones?name=$normalized&status=active&match=all'),
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
    for (final zone in zones) {
      final map = zone as Map<String, dynamic>;
      if ((map['name'] as String?)?.toLowerCase() == normalized) {
        return map['id'] as String?;
      }
    }

    return null;
  }

  /// Returns `true` when a new rule was created, `false` when an identical rule already existed.
  Future<bool> createFullDomainRedirect({
    required String zoneId,
    required String targetBaseUrl,
    required bool preservePath,
    required bool preserveQueryString,
  }) async {
    final target = _normalizeTargetUrl(targetBaseUrl);
    final targetExpression = preservePath
        ? 'concat("$target", http.request.uri.path)'
        : '"$target"';

    final rule = {
      'description': 'Bulk 301 redirect (Cloudflare Bulk301 app)',
      'expression': 'true',
      'action': 'redirect',
      'action_parameters': {
        'from_value': {
          'status_code': 301,
          'target_url': {
            'expression': targetExpression,
          },
          'preserve_query_string': preserveQueryString,
        },
      },
      'enabled': true,
    };

    final entrypoint = await _getRedirectEntrypoint(zoneId);

    if (entrypoint == null) {
      await _createRedirectRuleset(zoneId, [rule]);
      return true;
    }

    final rulesetId = entrypoint['id'] as String;
    final existingRules =
        (entrypoint['rules'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final duplicate = existingRules.any(
      (existing) => _isDuplicateRedirectRule(existing, target, preservePath),
    );

    if (duplicate) {
      return false;
    }

    existingRules.add(rule);
    await _updateRuleset(zoneId, rulesetId, existingRules);
    return true;
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

  String? _firstError(_ApiResponse body) {
    if (body.errors.isEmpty) {
      return null;
    }
    return body.errors.first['message'] as String?;
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
      throw CloudflareApiException(
        message ?? 'Failed to read redirect rules.',
        statusCode: response.statusCode,
      );
    }

    return body.result as Map<String, dynamic>?;
  }

  Future<void> _createRedirectRuleset(
    String zoneId,
    List<Map<String, dynamic>> rules,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/zones/$zoneId/rulesets'),
      headers: _headers,
      body: jsonEncode({
        'name': 'Bulk 301 redirects',
        'kind': 'zone',
        'phase': 'http_request_dynamic_redirect',
        'rules': rules,
      }),
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to create redirect rule.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _updateRuleset(
    String zoneId,
    String rulesetId,
    List<Map<String, dynamic>> rules,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/zones/$zoneId/rulesets/$rulesetId'),
      headers: _headers,
      body: jsonEncode({'rules': rules}),
    );

    final body = _decode(response);
    if (!body.success) {
      throw CloudflareApiException(
        _firstError(body) ?? 'Failed to update redirect rule.',
        statusCode: response.statusCode,
      );
    }
  }

  bool _isDuplicateRedirectRule(
    Map<String, dynamic> rule,
    String target,
    bool preservePath,
  ) {
    if (rule['action'] != 'redirect') {
      return false;
    }

    final params = rule['action_parameters'] as Map<String, dynamic>?;
    final fromValue = params?['from_value'] as Map<String, dynamic>?;
    final targetUrl = fromValue?['target_url'] as Map<String, dynamic>?;
    final expression = targetUrl?['expression'] as String?;
    if (expression == null) {
      return false;
    }

    final expected = preservePath
        ? 'concat("$target", http.request.uri.path)'
        : '"$target"';

    return expression == expected;
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
