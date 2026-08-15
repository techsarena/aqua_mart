import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../storage/app_preferences.dart';
import '../storage/token_storage.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => PrefsTokenStorage(ref.watch(sharedPreferencesProvider)),
);

final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);

/// Fires when a token refresh fails — the router listens and redirects to the
/// language/role gate.
class SessionExpiredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void expire() => state = true;
  void reset() => state = false;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, bool>(SessionExpiredNotifier.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  return ApiClient(
    authInterceptor: AuthInterceptor(
      tokenStorage: tokens,
      refreshDio: Dio(),
      onSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).expire(),
    ),
  );
});

/// Flip to `false` to run every repository against the live REST API.
///
/// Kept as a single switch so the whole app can be moved over at once, or
/// feature by feature by editing the individual data-source providers.
const useMockData = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: true);
