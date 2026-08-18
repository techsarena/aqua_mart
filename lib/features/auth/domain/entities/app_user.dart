import 'package:equatable/equatable.dart';

import 'user_role.dart';

enum Gender { female, male, unspecified }

/// The signed-in person, in whichever role they picked.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.gender = Gender.unspecified,
    this.dateOfBirth,
    this.avatarUrl,
    this.walletBalance = 0,
    this.khataDue = 0,
    this.khataSellerName,
    this.khataDueDate,
    this.isVerified = false,
    this.isProfileComplete = true,
  });

  final String id;
  final String fullName;
  final String phone;
  final UserRole role;
  final Gender gender;
  final DateTime? dateOfBirth;
  final String? avatarUrl;

  /// Customer wallet, in rupees.
  final int walletBalance;

  /// Monthly account ("khata") outstanding with a seller.
  final int khataDue;
  final String? khataSellerName;
  final DateTime? khataDueDate;

  /// Seller-only: whether verification has been approved.
  final bool isVerified;

  /// False only for an OTP-created account that still has registration steps.
  final bool isProfileComplete;

  bool get hasKhata => khataDue > 0;

  AppUser copyWith({
    String? fullName,
    Gender? gender,
    DateTime? dateOfBirth,
    String? avatarUrl,
    int? walletBalance,
    int? khataDue,
    bool? isVerified,
    bool? isProfileComplete,
  }) => AppUser(
    id: id,
    fullName: fullName ?? this.fullName,
    phone: phone,
    role: role,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    walletBalance: walletBalance ?? this.walletBalance,
    khataDue: khataDue ?? this.khataDue,
    khataSellerName: khataSellerName,
    khataDueDate: khataDueDate,
    isVerified: isVerified ?? this.isVerified,
    isProfileComplete: isProfileComplete ?? this.isProfileComplete,
  );

  @override
  List<Object?> get props => [
    id,
    fullName,
    phone,
    role,
    gender,
    dateOfBirth,
    walletBalance,
    khataDue,
    isVerified,
    isProfileComplete,
  ];
}
