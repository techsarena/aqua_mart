import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

class UserDto {
  const UserDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.gender,
    this.dateOfBirth,
    this.avatarUrl,
    this.walletBalance = 0,
    this.khataDue = 0,
    this.khataSellerName,
    this.khataDueDate,
    this.isVerified = false,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final String? gender;
  final String? dateOfBirth;
  final String? avatarUrl;
  final int walletBalance;
  final int khataDue;
  final String? khataSellerName;
  final String? khataDueDate;
  final bool isVerified;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    id: '${json['id']}',
    fullName: json['full_name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: json['role'] as String? ?? 'customer',
    gender: json['gender'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    walletBalance: (json['wallet_balance'] as num?)?.toInt() ?? 0,
    khataDue: (json['khata_due'] as num?)?.toInt() ?? 0,
    khataSellerName: json['khata_seller_name'] as String?,
    khataDueDate: json['khata_due_date'] as String?,
    isVerified: json['is_verified'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'phone': phone,
    'role': role,
    'gender': gender,
    'date_of_birth': dateOfBirth,
    'avatar_url': avatarUrl,
    'wallet_balance': walletBalance,
    'khata_due': khataDue,
    'khata_seller_name': khataSellerName,
    'khata_due_date': khataDueDate,
    'is_verified': isVerified,
  };

  AppUser toDomain() => AppUser(
    id: id,
    fullName: fullName,
    phone: phone,
    role:
        UserRole.values.where((r) => r.name == role).firstOrNull ??
        UserRole.customer,
    gender:
        Gender.values.where((g) => g.name == gender).firstOrNull ??
        Gender.unspecified,
    dateOfBirth: dateOfBirth == null ? null : DateTime.tryParse(dateOfBirth!),
    avatarUrl: avatarUrl,
    walletBalance: walletBalance,
    khataDue: khataDue,
    khataSellerName: khataSellerName,
    khataDueDate: khataDueDate == null
        ? null
        : DateTime.tryParse(khataDueDate!),
    isVerified: isVerified,
  );

  static UserDto fromDomain(AppUser user) => UserDto(
    id: user.id,
    fullName: user.fullName,
    phone: user.phone,
    role: user.role.name,
    gender: user.gender.name,
    dateOfBirth: user.dateOfBirth?.toIso8601String(),
    avatarUrl: user.avatarUrl,
    walletBalance: user.walletBalance,
    khataDue: user.khataDue,
    khataSellerName: user.khataSellerName,
    khataDueDate: user.khataDueDate?.toIso8601String(),
    isVerified: user.isVerified,
  );
}
