import 'package:equatable/equatable.dart';

enum AddressLabel {
  home('Home'),
  office('Office'),
  other('Other');

  const AddressLabel(this.text);
  final String text;
}

class Address extends Equatable {
  const Address({
    required this.id,
    required this.label,
    required this.title,
    required this.area,
    this.houseNumber = '',
    this.riderNote = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.isServiceable = true,
  });

  final String id;
  final AddressLabel label;

  /// The name the customer gave it — "Home", "Ammi's house".
  final String title;

  /// `Gulberg III, Lahore`
  final String area;
  final String houseNumber;

  /// "Near Hafeez Centre. Ring the bell twice — gate is on the side street."
  final String riderNote;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  /// False when no seller delivers here yet — drives the "No sellers here yet"
  /// empty state.
  final bool isServiceable;

  /// `House 42-B, Gulberg III`
  String get shortLine =>
      houseNumber.isEmpty ? area : 'House $houseNumber, $area';

  /// `House 42-B, Gulberg III · near Hafeez Centre. Ring the bell twice.`
  String get fullLine =>
      riderNote.isEmpty ? shortLine : '$shortLine · $riderNote';

  Address copyWith({
    AddressLabel? label,
    String? title,
    String? area,
    String? houseNumber,
    String? riderNote,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) => Address(
    id: id,
    label: label ?? this.label,
    title: title ?? this.title,
    area: area ?? this.area,
    houseNumber: houseNumber ?? this.houseNumber,
    riderNote: riderNote ?? this.riderNote,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    isDefault: isDefault ?? this.isDefault,
    isServiceable: isServiceable,
  );

  @override
  List<Object?> get props => [id, label, title, area, houseNumber, isDefault];
}
