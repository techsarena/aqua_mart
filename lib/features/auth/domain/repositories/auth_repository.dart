import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';
import '../entities/user_role.dart';

/// Draft collected across the three sign-up steps before the account exists.
class SignUpDraft {
  const SignUpDraft({
    this.fullName = '',
    this.phone = '',
    this.role = UserRole.customer,
    this.gender = Gender.unspecified,
    this.dateOfBirth,
  });

  final String fullName;
  final String phone;
  final UserRole role;
  final Gender gender;
  final DateTime? dateOfBirth;

  SignUpDraft copyWith({
    String? fullName,
    String? phone,
    UserRole? role,
    Gender? gender,
    DateTime? dateOfBirth,
  }) => SignUpDraft(
    fullName: fullName ?? this.fullName,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
  );
}

abstract interface class AuthRepository {
  /// Sends the 6-digit SMS code. Returns the seconds until a resend is allowed.
  Future<Result<int>> requestOtp(String phone);

  /// Verifies the code and persists the session tokens.
  Future<Result<AppUser>> verifyOtp({
    required String phone,
    required String code,
    required SignUpDraft draft,
  });

  /// Saves the optional third-step details.
  Future<Result<AppUser>> completeProfile(SignUpDraft draft);

  /// Restores the signed-in user from a stored token, or null if there is none.
  Future<Result<AppUser?>> currentUser();

  Future<Result<void>> signOut();
}
