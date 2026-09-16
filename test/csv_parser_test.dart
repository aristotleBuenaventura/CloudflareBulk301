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

  test('parses pasted Google Sheets / Excel column', () {
    const content = '''
ga888vn.ru.com
hayedi.sa.com
ga888.mobile
ga888vn.codes
''';

    expect(
      CsvParser.parsePastedDomains(content),
      [
        'ga888vn.ru.com',
        'hayedi.sa.com',
        'ga888.mobile',
        'ga888vn.codes',
      ],
    );
  });

  test('parses pasted comma and tab separated domains', () {
    expect(
      CsvParser.parsePastedDomains('a.com,b.com\tc.com;d.com'),
      ['a.com', 'b.com', 'c.com', 'd.com'],
    );
  });
}
