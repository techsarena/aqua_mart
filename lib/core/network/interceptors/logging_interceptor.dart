import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request/response logging. Silent in release builds, and never
/// prints the Authorization header or any payment payload.
class LoggingInterceptor extends Interceptor {
  static const _redactedHeaders = {'authorization', 'cookie', 'set-cookie'};
  static const _redactedPaths = {'/wallet/top-up', '/payment-methods/cards'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final headers = Map<String, dynamic>.from(options.headers)
        ..removeWhere((k, _) => _redactedHeaders.contains(k.toLowerCase()));
      final body = _shouldRedact(options.path) ? '<redacted>' : options.data;
      developer.log(
        '→ ${options.method} ${options.path}\n'
        '  headers: $headers\n'
        '  body: $body',
        name: 'api',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      developer.log(
        '← ${response.statusCode} ${response.requestOptions.path}',
        name: 'api',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      developer.log(
        '✗ ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.path}\n  ${err.message}',
        name: 'api',
        level: 1000,
      );
    }
    handler.next(err);
  }

  bool _shouldRedact(String path) =>
      _redactedPaths.any((p) => path.contains(p));
}
