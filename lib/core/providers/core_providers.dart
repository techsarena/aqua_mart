import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../realtime/socket_client.dart';
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

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, bool>(
  SessionExpiredNotifier.new,
);

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

/// The app's one Socket.IO connection (API_SPEC 8).
///
/// Not connected here — [SessionController] opens it on sign-in and closes it
/// on sign-out, so a signed-out app holds no socket. Under mocks it stays
/// closed and every screen falls back to its REST/mock path, which is exactly
/// the behaviour required when a socket never connects (8.6).
final socketClientProvider = Provider<SocketClient>((ref) {
  final client = SocketClient(tokens: ref.watch(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// Streams one realtime event to whoever watches it.
///
/// Autodisposed: when the last screen watching an event goes away the
/// subscription goes with it, which is what keeps `rider:location` from
/// costing battery once nobody is looking at a map.
final socketEventProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, event) => ref.watch(socketClientProvider).on(event),
);
