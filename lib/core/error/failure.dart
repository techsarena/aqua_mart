import 'package:equatable/equatable.dart';

/// A domain-level error. Data sources translate transport errors (Dio,
/// platform, parsing) into these so that features never import `dio`.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType($code): $message';
}

/// No connectivity, DNS failure, or the request timed out.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Check your signal and try again.',
  ]);
}

/// Server returned a non-2xx status.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

/// 401/403 — the session is gone or the caller lacks permission.
final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Your session has expired. Sign in again.'])
    : super(code: 'unauthorized');
}

/// 422 — the server rejected the payload, usually per-field.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}})
    : super(code: 'validation');

  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// The response body did not match the expected shape.
final class ParseFailure extends Failure {
  const ParseFailure([
    super.message = 'We could not read the response from the server.',
  ]) : super(code: 'parse');
}

/// Local storage / cache error.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read saved data.'])
    : super(code: 'cache');
}

/// Anything not otherwise classified.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
