import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'api_endpoints.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Thin wrapper over Dio. Every network call in the app goes through here, and
/// every transport error leaves here as a [Failure].
///
/// Data sources depend on this class, never on Dio directly — so swapping the
/// HTTP engine or adding retry/caching stays a one-file change.
class ApiClient {
  ApiClient({Dio? dio, AuthInterceptor? authInterceptor})
    : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    );

    if (authInterceptor != null) _dio.interceptors.add(authInterceptor);
    _dio.interceptors.add(LoggingInterceptor());
  }

  final Dio _dio;

  Dio get raw => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _request<T>(
    () => _dio.get<T>(path, queryParameters: query, cancelToken: cancelToken),
  );

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => _request<T>(
    () => _dio.post<T>(
      path,
      data: body,
      queryParameters: query,
      cancelToken: cancelToken,
    ),
  );

  Future<T> put<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _request<T>(() => _dio.put<T>(path, data: body, cancelToken: cancelToken));

  Future<T> patch<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _request<T>(
        () => _dio.patch<T>(path, data: body, cancelToken: cancelToken),
      );

  Future<T> delete<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _request<T>(
        () => _dio.delete<T>(path, data: body, cancelToken: cancelToken),
      );

  /// Multipart upload — used for CNIC photos, water test certificates and
  /// complaint evidence.
  Future<T> upload<T>(
    String path, {
    required Map<String, dynamic> fields,
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) => _request<T>(
    () => _dio.post<T>(
      path,
      data: FormData.fromMap(fields),
      cancelToken: cancelToken,
      onSendProgress: onProgress,
    ),
  );

  Future<T> _request<T>(Future<Response<T>> Function() send) async {
    try {
      final response = await send();
      return response.data as T;
    } on DioException catch (e) {
      throw _toFailure(e);
    }
  }

  Failure _toFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(
          'The connection timed out. Try again when you have better signal.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const NetworkFailure();
      case DioExceptionType.cancel:
        return const UnknownFailure('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const ServerFailure('Could not verify a secure connection.');
      case DioExceptionType.badResponse:
        return _fromStatus(e.response);
      default:
        return const UnknownFailure();
    }
  }

  Failure _fromStatus(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final data = response?.data;
    final message = data is Map<String, dynamic>
        ? (data['message'] ?? data['error']) as String?
        : null;

    if (status == 401 || status == 403) {
      return AuthFailure(message ?? 'Your session has expired. Sign in again.');
    }
    if (status == 422) {
      final errors = <String, String>{};
      if (data is Map<String, dynamic> && data['errors'] is Map) {
        (data['errors'] as Map).forEach((k, v) {
          errors['$k'] = v is List ? '${v.first}' : '$v';
        });
      }
      return ValidationFailure(
        message ?? 'Please check the details you entered.',
        fieldErrors: errors,
      );
    }
    return ServerFailure(
      message ?? 'The server could not complete that request.',
      statusCode: status,
    );
  }
}
