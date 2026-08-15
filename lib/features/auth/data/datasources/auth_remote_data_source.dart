import '../../../../core/error/failure.dart';
import '../../../../core/mock/mock_fixtures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user_role.dart';
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
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.requestOtp,
      body: {'phone': phone},
    );
    return (json['resend_after_seconds'] as num?)?.toInt() ?? 30;
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
    final json = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.completeProfile,
      body: {
        'full_name': draft.fullName,
        'gender': draft.gender.name,
        'date_of_birth': draft.dateOfBirth?.toIso8601String(),
      },
    );
    return UserDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<UserDto> fetchMe() async {
    final json = await _client.get<Map<String, dynamic>>(ApiEndpoints.me);
    return UserDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<void> signOut() => _client.post<void>(ApiEndpoints.logout);
}

/// Accepts any 6-digit code and returns the fixture user for the chosen role.
class MockAuthDataSource implements AuthRemoteDataSource {
  MockAuthDataSource(this._tokens);

  final TokenStorage _tokens;
  UserDto? _signedIn;

  static const _latency = Duration(milliseconds: 600);

  @override
  Future<int> requestOtp(String phone) async {
    await Future<void>.delayed(_latency);
    return 30;
  }

  @override
  Future<({UserDto user, String accessToken, String refreshToken})> verifyOtp({
    required String phone,
    required String code,
    required SignUpDraft draft,
  }) async {
    await Future<void>.delayed(_latency);
    if (code.length != 6) {
      throw const ValidationFailure('That code is not right. Check and retry.');
    }

    final base = switch (draft.role) {
      UserRole.customer => MockFixtures.customer,
      UserRole.seller => MockFixtures.sellerUser,
      UserRole.rider => MockFixtures.riderUser,
    };

    final user = UserDto.fromDomain(
      base.copyWith(
        fullName: draft.fullName.isEmpty ? base.fullName : draft.fullName,
      ),
    );
    _signedIn = user;
    return (
      user: user,
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
    );
  }

  @override
  Future<UserDto> completeProfile(SignUpDraft draft) async {
    await Future<void>.delayed(_latency);
    // The role is chosen during sign-up, so the fixture is picked from the
    // draft rather than defaulting to a customer.
    final base = switch (draft.role) {
      UserRole.customer => MockFixtures.customer,
      UserRole.seller => MockFixtures.sellerUser,
      UserRole.rider => MockFixtures.riderUser,
    };
    // `_signedIn` is whatever verifyOtp minted before the role was known, so
    // the draft's fixture wins on role.
    final current = _signedIn?.toDomain().role == draft.role
        ? _signedIn!.toDomain()
        : base;
    final updated = UserDto.fromDomain(
      current.copyWith(
        fullName: draft.fullName.isEmpty ? current.fullName : draft.fullName,
        gender: draft.gender,
        dateOfBirth: draft.dateOfBirth,
      ),
    );
    _signedIn = updated;
    return updated;
  }

  @override
  Future<UserDto> fetchMe() async {
    final token = await _tokens.readAccessToken();
    if (token == null) throw const AuthFailure('Not signed in.');
    return _signedIn ?? UserDto.fromDomain(MockFixtures.customer);
  }

  @override
  Future<void> signOut() async {
    _signedIn = null;
  }
}
