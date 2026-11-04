class CanonicalRule {
  const CanonicalRule({
    required this.sourceUrl,
    required this.canonicalUrl,
  });

  /// Page URL that receives the canonical tag.
  final String sourceUrl;

  /// Canonical href. Equals [sourceUrl] when the right side was blank (self).
  final String canonicalUrl;

  String get hostname {
    final uri = Uri.tryParse(sourceUrl);
    return (uri?.host ?? '').toLowerCase();
  }
}

class CanonicalParser {
  /// Parses left/right paste boxes using the same rules as the reference tool:
  /// - blank right → each left URL canonicalizes to itself
  /// - single right line → that canonical applies to every left URL
  /// - multiple right lines → pair by index; missing right → self
  static List<CanonicalRule> parse({
    required String leftText,
    required String rightText,
  }) {
    final left = _lines(leftText);
    if (left.isEmpty) {
      return const [];
    }

    final right = _lines(rightText);
    final rules = <CanonicalRule>[];

    for (var i = 0; i < left.length; i++) {
      final source = _normalizeUrl(left[i]);
      if (source == null) {
        continue;
      }

      String canonical;
      if (right.isEmpty) {
        canonical = source;
      } else if (right.length == 1) {
        canonical = _normalizeUrl(right.first) ?? source;
      } else if (i < right.length) {
        final rightUrl = right[i].trim();
        canonical = rightUrl.isEmpty
            ? source
            : (_normalizeUrl(rightUrl) ?? source);
      } else {
        canonical = source;
      }

      rules.add(CanonicalRule(sourceUrl: source, canonicalUrl: canonical));
    }

    return rules;
  }

  static List<String> _lines(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String? _normalizeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final path = uri.path.isEmpty ? '/' : uri.path;
    final normalized = Uri(
      scheme: scheme,
      host: uri.host.toLowerCase(),
      port: uri.hasPort && uri.port != 80 && uri.port != 443 ? uri.port : null,
      path: path,
      query: uri.hasQuery ? uri.query : null,
    ).toString();

    return normalized;
  }
}
