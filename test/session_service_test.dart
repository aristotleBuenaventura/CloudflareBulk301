import 'package:flutter_test/flutter_test.dart';
import 'package:cloudflare_bulk301/services/session_service.dart';

void main() {
  test('session stores account token flag', () {
    final session = SessionService();

    session.startSession(
      apiToken: 'cfat_test',
      email: 'account@example.com',
      isAccountToken: true,
    );

    expect(session.isAccountToken, isTrue);

    session.endSession();

    expect(session.isAccountToken, isFalse);
  });
}
