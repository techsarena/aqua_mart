import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  Future<Result<int>> requestOtp(String phone) =>
      Result.guard(() => _remote.requestOtp(phone));

  @override
  Future<Result<AppUser>> verifyOtp({
    required String phone,
    required String code,
    required SignUpDraft draft,
  }) => Result.guard(() async {
    final result = await _remote.verifyOtp(
      phone: phone,
      code: code,
      draft: draft,
    );
    await _tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result.user.toDomain();
  });

  @override
  Future<Result<AppUser>> completeProfile(SignUpDraft draft) =>
      Result.guard(() async => (await _remote.completeProfile(draft)).toDomain());

  @override
  Future<Result<AppUser?>> currentUser() => Result.guard(() async {
    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) return null;
    return (await _remote.fetchMe()).toDomain();
  });

  @override
  Future<Result<void>> signOut() => Result.guard(() async {
    await _remote.signOut();
    await _tokens.clear();
  });
}
