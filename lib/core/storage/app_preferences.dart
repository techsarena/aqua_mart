import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../localization/app_language.dart';

/// Non-sensitive local state that survives restarts: chosen language, role and
/// whether onboarding has been completed.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _languageKey = 'app.language';
  static const _roleKey = 'app.role';
  static const _onboardedKey = 'app.onboarded';

  AppLanguage? get language {
    final code = _prefs.getString(_languageKey);
    if (code == null) return null;
    return AppLanguage.fromCode(code);
  }

  Future<void> setLanguage(AppLanguage value) =>
      _prefs.setString(_languageKey, value.code);

  UserRole? get role {
    final name = _prefs.getString(_roleKey);
    if (name == null) return null;
    return UserRole.values.where((r) => r.name == name).firstOrNull;
  }

  Future<void> setRole(UserRole value) =>
      _prefs.setString(_roleKey, value.name);

  bool get hasOnboarded => _prefs.getBool(_onboardedKey) ?? false;

  Future<void> setOnboarded({bool value = true}) =>
      _prefs.setBool(_onboardedKey, value);

  Future<void> clear() async {
    await _prefs.remove(_roleKey);
    await _prefs.remove(_onboardedKey);
  }
}
