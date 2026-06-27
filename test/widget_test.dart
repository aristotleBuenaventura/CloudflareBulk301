import 'package:flutter_test/flutter_test.dart';
import 'package:cloudflare_bulk301/services/session_service.dart';

void main() {
  test('session stores token in memory only', () {
    final session = SessionService();

    expect(session.isAuthenticated, isFalse);

    session.startSession(apiToken: 'test-token', email: 'user@example.com');

    expect(session.isAuthenticated, isTrue);
    expect(session.apiToken, 'test-token');
    expect(session.accountEmail, 'user@example.com');

    session.endSession();

    expect(session.isAuthenticated, isFalse);
    expect(session.apiToken, isNull);
  });
}
