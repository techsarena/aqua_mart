import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_dto.dart';

abstract interface class AuthRemoteDataSource {
  Future<int> requestOtp(String phone);
  Future<({UserDto user, String accessToken, String refreshToken})> verifyOtp({
    required String phone,
    required String code,
    required SignUpDraft draft,
  });
  Future<UserDto> completeProfile(SignUpDraft draft);
  Future<UserDto> fetchMe();
  Future<void> signOut();
}

class AuthApiDataSource implements AuthRemoteDataSource {
  const AuthApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<int> requestOtp(String phone) async {
    // resend_after_seconds rides under `data`, unlike the token endpoints.
    final json = await _client.postObject(
      ApiEndpoints.requestOtp,
      body: {'phone': phone},
    );
    return (json?['resend_after_seconds'] as num?)?.toInt() ?? 30;
  }

  @override
  Future<({UserDto user, String accessToken, String refreshToken})> verifyOtp({
    required String phone,
    required String code,
    required SignUpDraft draft,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.verifyOtp,
      body: {
        'phone': phone,
        'code': code,
        'full_name': draft.fullName,
        'role': draft.role.name,
      },
    );
    final access = json['access_token'] as String?;
    final refresh = json['refresh_token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    if (access == null || refresh == null || user == null) {
      throw const ParseFailure('The sign-in response was incomplete.');
    }
    return (
      user: UserDto.fromJson(user),
      accessToken: access,
      refreshToken: refresh,
    );
  }

  @override
  Future<UserDto> completeProfile(SignUpDraft draft) async {
    final json = await _client.patchObject(
      ApiEndpoints.completeProfile,
      body: {
        'full_name': draft.fullName,
        'gender': draft.gender.name,
        'date_of_birth': draft.dateOfBirth?.toIso8601String(),
      },
    );
    return UserDto.fromJson(json ?? const {});
  }

  @override
  Future<UserDto> fetchMe() async {
    final json = await _client.getObject(ApiEndpoints.me);
    return UserDto.fromJson(json ?? const {});
  }

  @override
  Future<void> signOut() => _client.post<void>(ApiEndpoints.logout);
}
