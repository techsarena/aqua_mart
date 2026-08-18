import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'api_endpoints.dart';
import 'api_environment.dart';
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
      headers: {
        'Accept': 'application/json',
        // Frappe is multi-tenant: without this it resolves the site from the
        // Host header, which is wrong for every non-default site.
        'X-Frappe-Site-Name': ApiEnvironment.siteName,
      },
    );

    if (authInterceptor != null) _dio.interceptors.add(authInterceptor);
    _dio.interceptors.add(LoggingInterceptor());
  }

  final Dio _dio;

  Dio get raw => _dio;

  // ── Envelope ────────────────────────────────────────────────────────────
  // The backend answers `{"data": ...}` on success and `{"message": ...}` on
  // error (API_SPEC 1.2/1.3). The auth endpoints additionally put tokens at
  // the TOP level, so unwrapping is opt-in per call rather than automatic.

  /// A single object from under `data`.
  ///
  /// Returns `null` when the endpoint legitimately answers `data: null` —
  /// `/rider/seller-codes/{code}` does exactly that for "no such code".
  Future<Map<String, dynamic>?> getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final body = await get<Map<String, dynamic>?>(path, query: query);
    return _object(body);
  }

  /// A list from under `data`. An absent or null `data` reads as empty.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final body = await get<Map<String, dynamic>?>(path, query: query);
    return _list(body);
  }

  Future<Map<String, dynamic>?> postObject(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await post<Map<String, dynamic>?>(
      path,
      body: body,
      headers: headers,
    );
    return _object(response);
  }

  Future<Map<String, dynamic>?> putObject(String path, {Object? body}) async =>
      _object(await put<Map<String, dynamic>?>(path, body: body));

  Future<Map<String, dynamic>?> patchObject(String path, {Object? body}) async =>
      _object(await patch<Map<String, dynamic>?>(path, body: body));

  /// Unwraps `{"data": {...}}`.
  ///
  /// A 204 leaves an empty body, which Dio surfaces as `null` — that is a
  /// success, not a parse error, so it maps to `null` rather than throwing.
  Map<String, dynamic>? _object(Map<String, dynamic>? body) {
    if (body == null) return null;
    if (!body.containsKey('data')) return body;
    final data = body['data'];
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    throw const ParseFailure();
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic>? body) {
    if (body == null) return const [];
    final data = body.containsKey('data') ? body['data'] : body;
    if (data == null) return const [];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    throw const ParseFailure();
  }

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
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) => _request<T>(
    () => _dio.post<T>(
      path,
      data: body,
      queryParameters: query,
      cancelToken: cancelToken,
      options: headers == null ? null : Options(headers: headers),
    ),
  );

  Future<T> put<T>(String path, {Object? body, CancelToken? cancelToken}) =>
      _request<T>(
        () => _dio.put<T>(path, data: body, cancelToken: cancelToken),
      );

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
      final data = response.data;
      // Many endpoints answer 204 with an empty body (API_SPEC 1.2). Dio
      // surfaces that as null, which is a success — only a *non-nullable* T
      // makes it a genuine parse failure.
      if (data == null && !_acceptsNull<T>()) throw const ParseFailure();
      return data as T;
    } on DioException catch (e) {
      throw _toFailure(e);
    }
  }

  /// True when `T` is nullable or `void`, i.e. an empty body is expected.
  static bool _acceptsNull<T>() => null is T || T == dynamic;

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
