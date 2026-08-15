import '../../domain/entities/address.dart';

class AddressDto {
  const AddressDto({
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
  final String label;
  final String title;
  final String area;
  final String houseNumber;
  final String riderNote;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final bool isServiceable;

  factory AddressDto.fromJson(Map<String, dynamic> json) => AddressDto(
    id: '${json['id']}',
    label: json['label'] as String? ?? 'other',
    title: json['title'] as String? ?? '',
    area: json['area'] as String? ?? '',
    houseNumber: json['house_number'] as String? ?? '',
    riderNote: json['rider_note'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    isDefault: json['is_default'] as bool? ?? false,
    isServiceable: json['is_serviceable'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'label': label,
    'title': title,
    'area': area,
    'house_number': houseNumber,
    'rider_note': riderNote,
    'latitude': latitude,
    'longitude': longitude,
    'is_default': isDefault,
  };

  AddressDto copyWith({String? id, bool? isDefault}) => AddressDto(
    id: id ?? this.id,
    label: label,
    title: title,
    area: area,
    houseNumber: houseNumber,
    riderNote: riderNote,
    latitude: latitude,
    longitude: longitude,
    isDefault: isDefault ?? this.isDefault,
    isServiceable: isServiceable,
  );

  Address toDomain() => Address(
    id: id,
    label:
        AddressLabel.values.where((l) => l.name == label).firstOrNull ??
        AddressLabel.other,
    title: title,
    area: area,
    houseNumber: houseNumber,
    riderNote: riderNote,
    latitude: latitude,
    longitude: longitude,
    isDefault: isDefault,
    isServiceable: isServiceable,
  );

  static AddressDto fromDomain(Address address) => AddressDto(
    id: address.id,
    label: address.label.name,
    title: address.title,
    area: address.area,
    houseNumber: address.houseNumber,
    riderNote: address.riderNote,
    latitude: address.latitude,
    longitude: address.longitude,
    isDefault: address.isDefault,
    isServiceable: address.isServiceable,
  );
}
