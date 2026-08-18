import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_dto.dart';

abstract interface class AuthRemoteDataSource {
  Future<int> requestOtp(String phone);
  Future<
    ({UserDto user, String accessToken, String refreshToken, bool isNewUser})
  >
  verifyOtp({
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
  Future<
    ({UserDto user, String accessToken, String refreshToken, bool isNewUser})
  >
  verifyOtp({
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
    final explicitNew =
        _boolValue(json['is_new_user']) ??
        _boolValue(user['is_new_user']) ??
        _boolValue(json['profile_incomplete']) ??
        _boolValue(user['profile_incomplete']);
    final explicitRegistered =
        _boolValue(json['is_registered']) ??
        _boolValue(user['is_registered']) ??
        _boolValue(json['profile_complete']) ??
        _boolValue(user['profile_complete']);
    return (
      user: UserDto.fromJson(user),
      accessToken: access,
      refreshToken: refresh,
      // Missing metadata must never let a newly created account bypass its
      // registration screens. Updated backends should always send the flag.
      isNewUser:
          explicitNew ??
          (explicitRegistered == null ? true : !explicitRegistered),
    );
  }

  bool? _boolValue(Object? value) => switch (value) {
    bool value => value,
    num value => value != 0,
    String value when value.toLowerCase() == 'true' || value == '1' => true,
    String value when value.toLowerCase() == 'false' || value == '0' => false,
    _ => null,
  };

  @override
  Future<UserDto> completeProfile(SignUpDraft draft) async {
    final json = await _client.patchObject(
      ApiEndpoints.completeProfile,
      body: {
        'full_name': draft.fullName,
        // The role is set once while the OTP-created profile is incomplete.
        // Backends must ignore/reject role changes for completed profiles.
        'role': draft.role.name,
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
