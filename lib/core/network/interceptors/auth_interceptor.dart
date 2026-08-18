import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';
import '../api_endpoints.dart';
import '../api_environment.dart';

/// Attaches the bearer token to every request and refreshes it once on a 401.
///
/// [onSessionExpired] fires when the refresh itself fails — the app listens and
/// kicks the user back to the sign-in flow.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshDio,
    this.onSessionExpired,
  }) : _tokens = tokenStorage,
       _refreshDio = refreshDio;

  final TokenStorage _tokens;
  final Dio _refreshDio;
  final void Function()? onSessionExpired;

  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthCall = err.requestOptions.path.startsWith('/auth');
    if (err.response?.statusCode != 401 || isAuthCall || _isRefreshing) {
      return handler.next(err);
    }

    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      onSessionExpired?.call();
      return handler.next(err);
    }

    _isRefreshing = true;
    var refreshSucceeded = false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.refreshToken}',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'X-Frappe-Site-Name': ApiEnvironment.siteName},
        ),
      );
      final data = response.data ?? const {};
      final newAccess = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String? ?? refreshToken;

      if (newAccess == null) {
        await _tokens.clear();
        onSessionExpired?.call();
        return handler.next(err);
      }

      await _tokens.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      refreshSucceeded = true;

      // FormData and MultipartFile streams are consumed by the first request.
      // Clone them before replaying an upload after token refresh; otherwise
      // Dio throws "FormData has already been finalized" and the valid,
      // freshly-refreshed session is incorrectly cleared.
      final original = err.requestOptions;
      final retryOptions = original.copyWith(
        data: original.data is FormData
            ? (original.data as FormData).clone()
            : original.data,
        headers: {...original.headers, 'Authorization': 'Bearer $newAccess'},
      );
      final retried = await _refreshDio.fetch<dynamic>(retryOptions);
      return handler.resolve(retried);
    } on DioException catch (retryError) {
      if (!refreshSucceeded) {
        await _tokens.clear();
        onSessionExpired?.call();
        return handler.next(err);
      }
      // The refreshed session is valid. Surface only the retry's transport or
      // server failure and keep the new tokens for the next attempt.
      return handler.next(retryError);
    } catch (_) {
      if (!refreshSucceeded) {
        await _tokens.clear();
        onSessionExpired?.call();
      }
      return handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
