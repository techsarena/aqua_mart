import 'package:equatable/equatable.dart';

/// A rider who used the seller's code and is waiting to be let onto the team.
///
/// Carries none of [Rider]'s performance figures: an applicant has never
/// delivered for this seller, and printing zeroes for rating and on-time would
/// read as a bad record rather than an absent one.
class RiderApplicant extends Equatable {
  const RiderApplicant({
    required this.id,
    required this.name,
    required this.phone,
    required this.appliedAt,
    this.vehicle,
    this.registrationNumber,
    this.cnicLast4,
  });

  final String id;
  final String name;
  final String phone;
  final DateTime appliedAt;

  /// `motorbike` | `rickshaw` | `loader` | `onFoot`, as the backend spells it.
  final String? vehicle;
  final String? registrationNumber;

  /// Only the last four digits ever reach the client — enough to check
  /// against the card in the rider's hand, and no more.
  final String? cnicLast4;

  /// "Motorbike · KMR-4471", or just the vehicle when it needs no plate.
  String get vehicleLine {
    final label = switch (vehicle) {
      'motorbike' => 'Motorbike',
      'rickshaw' => 'Rickshaw',
      'loader' => 'Loader',
      'onFoot' => 'On foot',
      _ => null,
    };
    if (label == null) return 'Vehicle not given';

    final plate = registrationNumber;
    return plate == null || plate.isEmpty ? label : '$label · $plate';
  }

  @override
  List<Object?> get props => [id, name, phone, appliedAt];
}
