/// Holds the Cloudflare API token in memory only for the current session.
/// The token is never written to disk or shared preferences.
class SessionService {
  String? _apiToken;
  String? _accountEmail;

  bool get isAuthenticated => _apiToken != null && _apiToken!.isNotEmpty;

  String? get apiToken => _apiToken;

  String? get accountEmail => _accountEmail;

  void startSession({required String apiToken, String? email}) {
    _apiToken = apiToken.trim();
    _accountEmail = email?.trim();
  }

  void endSession() {
    _apiToken = null;
    _accountEmail = null;
  }
}
