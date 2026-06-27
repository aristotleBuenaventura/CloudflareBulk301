import 'package:flutter_test/flutter_test.dart';

import 'package:cloudflare_bulk301/services/csv_parser.dart';

void main() {
  test('parses plain line-separated domains', () {
    const content = '''
old1.com
old2.com
''';

    expect(CsvParser.parseDomains(content), ['old1.com', 'old2.com']);
  });

  test('parses csv with domain header', () {
    const content = '''
domain,target
old1.com,https://new.com
old2.com,https://new.com
''';

    expect(CsvParser.parseDomains(content), ['old1.com', 'old2.com']);
  });
}
