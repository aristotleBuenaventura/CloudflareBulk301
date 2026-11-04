import 'package:flutter_test/flutter_test.dart';

import 'package:cloudflare_bulk301/services/canonical_parser.dart';

void main() {
  test('blank right side maps each URL to itself', () {
    const left = '''
https://old.com/a/
https://old.com/b/
''';

    final rules = CanonicalParser.parse(leftText: left, rightText: '');
    expect(rules, hasLength(2));
    expect(rules[0].canonicalUrl, rules[0].sourceUrl);
    expect(rules[1].canonicalUrl, rules[1].sourceUrl);
  });

  test('single right line applies to all left URLs', () {
    const left = '''
https://old.com/a/
https://old.com/b/
''';
    const right = 'https://new.com/';

    final rules = CanonicalParser.parse(leftText: left, rightText: right);
    expect(rules, hasLength(2));
    expect(rules.every((r) => r.canonicalUrl == 'https://new.com/'), isTrue);
  });

  test('pairs lines by index', () {
    const left = '''
https://old.com/a/
https://old.com/b/
''';
    const right = '''
https://new.com/a/
https://new.com/b/
''';

    final rules = CanonicalParser.parse(leftText: left, rightText: right);
    expect(rules[0].canonicalUrl, 'https://new.com/a/');
    expect(rules[1].canonicalUrl, 'https://new.com/b/');
  });
}
