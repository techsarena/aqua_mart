import '../error/failure.dart';

/// Explicit success/failure channel so repositories never throw across layers.
///
/// ```dart
/// final result = await repo.fetchSellers();
/// result.when(
///   success: (sellers) => ...,
///   failure: (f) => ...,
/// );
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = Error<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Error<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Error<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Error<T>(:final failure) => failure,
  };

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => switch (this) {
    Success<T>(value: final v) => success(v),
    Error<T>(failure: final f) => failure(f),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(value: final v) => Result.success(transform(v)),
    Error<T>(failure: final f) => Result.failure(f),
  };

  /// Runs [body], converting any [Failure] thrown inside into `Result.failure`.
  static Future<Result<T>> guard<T>(Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }
}

/// Normalises whatever an `AsyncError` carries into a [Failure], so error UI
/// can render uniformly whether the throw came from us or from the framework.
Failure asFailure(Object error) =>
    error is Failure ? error : UnknownFailure(error.toString());

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
