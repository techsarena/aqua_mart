import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth session.
///
/// Backed by SharedPreferences for now. Swap the body for
/// `flutter_secure_storage` before shipping — the interface will not change.
abstract interface class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

class PrefsTokenStorage implements TokenStorage {
  PrefsTokenStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';

  @override
  Future<String?> readAccessToken() async => _prefs.getString(_accessKey);

  @override
  Future<String?> readRefreshToken() async => _prefs.getString(_refreshKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_accessKey, accessToken);
    await _prefs.setString(_refreshKey, refreshToken);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }
}
