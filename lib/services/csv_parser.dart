class CsvParser {
  static List<String> parseDomains(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    final domains = <String>{};
    var skippedHeader = false;

    for (final line in lines) {
      final domain = _firstColumn(line);
      if (domain.isEmpty) {
        continue;
      }

      if (!skippedHeader && _looksLikeHeader(domain)) {
        skippedHeader = true;
        continue;
      }

      domains.add(domain);
    }

    return domains.toList();
  }

  /// Parses domains pasted from Google Sheets / Excel / plain text.
  /// Splits on newlines, tabs, commas, semicolons, and whitespace.
  static List<String> parsePastedDomains(String content) {
    final domains = <String>{};
    var skippedHeader = false;

    for (final part in content.split(RegExp(r'[\r\n,\t;]+|\s+'))) {
      final domain = part.trim();
      if (domain.isEmpty) {
        continue;
      }
      if (!skippedHeader && _looksLikeHeader(domain)) {
        skippedHeader = true;
        continue;
      }
      domains.add(domain);
    }

    return domains.toList();
  }

  static String _firstColumn(String line) {
    final commaIndex = line.indexOf(',');
    if (commaIndex == -1) {
      return line.trim();
    }
    return line.substring(0, commaIndex).trim();
  }

  static bool _looksLikeHeader(String value) {
    final first = value.toLowerCase();
    return first == 'domain' ||
        first == 'domains' ||
        first == 'hostname' ||
        first == 'site' ||
        first == 'zone';
  }
}
