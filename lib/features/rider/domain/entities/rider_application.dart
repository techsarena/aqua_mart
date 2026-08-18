import 'package:equatable/equatable.dart';

/// What the rider delivers on. The capacity is the number of bottles a single
/// run can hold, which is what the seller schedules against.
enum RiderVehicle {
  motorbike,
  rickshaw,
  loader,
  onFoot;

  String get label => switch (this) {
    RiderVehicle.motorbike => 'Motorbike',
    RiderVehicle.rickshaw => 'Rickshaw',
    RiderVehicle.loader => 'Loader / pickup',
    RiderVehicle.onFoot => 'On foot',
  };

  String get capacityLabel => switch (this) {
    RiderVehicle.motorbike => 'Up to 4 bottles',
    RiderVehicle.rickshaw => 'Up to 15 bottles',
    RiderVehicle.loader => 'Up to 40 bottles',
    RiderVehicle.onFoot => '2 bottles, nearby only',
  };

  /// On foot is the one option with nothing to register.
  bool get needsRegistration => this != RiderVehicle.onFoot;
}

/// The seller a rider's invite code resolves to, shown for confirmation
/// before they commit to joining.
class RiderSellerMatch extends Equatable {
  const RiderSellerMatch({
    required this.code,
    required this.sellerName,
    required this.area,
    required this.riderCount,
    required this.joinedYear,
  });

  final String code;
  final String sellerName;

  /// "Gulberg III"
  final String area;
  final int riderCount;
  final int joinedYear;

  /// "Gulberg III · 4 riders · joined 2024"
  String get summary => '$area · $riderCount riders · joined $joinedYear';

  /// The two-letter monogram on the avatar disc — the initials of the first
  /// two words, or the first two letters of a single-word name.
  String get initials {
    final words = sellerName.trim().split(RegExp(r'\s+'));
    final source = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'
        : sellerName.padRight(2).substring(0, 2);
    return source.toUpperCase().trim();
  }

  @override
  List<Object?> get props => [code, sellerName];
}

/// Where a rider's registration stands while the seller reviews it.
enum RiderApprovalStep {
  numberConfirmed,
  documentsOnFile,
  sellerApproval;

  bool get isPending => this == RiderApprovalStep.sellerApproval;
}

/// The rider's registration, filled in across the five sign-up steps and
/// submitted to the seller who invited them.
class RiderApplication extends Equatable {
  const RiderApplication({
    this.fullName = '',
    this.cnic = '',
    this.phone = '',
    this.vehicle,
    this.registrationNumber = '',
    this.inviteCode = '',
    this.seller,
  });

  final String fullName;

  /// `35202-8841…` — held for the seller who hires them, never shown to
  /// customers.
  final String cnic;
  final String phone;
  final RiderVehicle? vehicle;

  /// The vehicle's plate, e.g. `KMR-4471`. Empty when [vehicle] is on foot.
  final String registrationNumber;
  final String inviteCode;

  /// Resolved from the invite code at step 5.
  final RiderSellerMatch? seller;

  /// The CNIC is 13 digits, conventionally written `#####-#######-#`.
  bool get hasValidCnic => cnic.replaceAll(RegExp(r'\D'), '').length == 13;

  bool get identityComplete => fullName.trim().isNotEmpty && hasValidCnic;

  bool get vehicleComplete =>
      vehicle != null &&
      (!vehicle!.needsRegistration || registrationNumber.trim().isNotEmpty);

  /// "CNIC and motorbike KMR-4471 on file"
  String get documentsLine {
    final v = vehicle;
    if (v == null) return 'CNIC on file';
    if (!v.needsRegistration) return 'CNIC on file · delivering on foot';
    return 'CNIC and ${v.label.toLowerCase()} $registrationNumber on file';
  }

  RiderApplication copyWith({
    String? fullName,
    String? cnic,
    String? phone,
    RiderVehicle? vehicle,
    String? registrationNumber,
    String? inviteCode,
    RiderSellerMatch? seller,
  }) => RiderApplication(
    fullName: fullName ?? this.fullName,
    cnic: cnic ?? this.cnic,
    phone: phone ?? this.phone,
    vehicle: vehicle ?? this.vehicle,
    registrationNumber: registrationNumber ?? this.registrationNumber,
    inviteCode: inviteCode ?? this.inviteCode,
    seller: seller ?? this.seller,
  );

  @override
  List<Object?> get props => [
    fullName,
    cnic,
    phone,
    vehicle,
    registrationNumber,
    inviteCode,
    seller,
  ];
}
