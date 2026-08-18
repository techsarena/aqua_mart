import 'package:equatable/equatable.dart';

/// Where a seller delivers: a radius around their shop, plus named areas.
///
/// Both halves matter on the server — a customer is served if their address
/// falls inside the radius **or** sits in one of the named areas — so the
/// centre is not decoration. Without it the radius covers nobody.
class ServiceArea extends Equatable {
  const ServiceArea({
    this.areas = const [],
    this.radiusKm = 0,
    this.latitude,
    this.longitude,
  });

  final List<String> areas;
  final double radiusKm;

  /// The shop's position — the point the radius is measured from.
  final double? latitude;
  final double? longitude;

  bool get hasCentre => latitude != null && longitude != null;

  ServiceArea copyWith({
    List<String>? areas,
    double? radiusKm,
    double? latitude,
    double? longitude,
  }) => ServiceArea(
    areas: areas ?? this.areas,
    radiusKm: radiusKm ?? this.radiusKm,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );

  factory ServiceArea.fromJson(Map<String, dynamic> json) => ServiceArea(
    areas: (json['areas'] as List?)?.map((e) => '$e').toList() ?? const [],
    radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 0,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'areas': areas,
    'radius_km': radiusKm,
    // Sent together or not at all: a half-set point would place the shop on
    // the equator and silently serve nobody.
    if (latitude != null && longitude != null) ...{
      'latitude': latitude,
      'longitude': longitude,
    },
  };

  @override
  List<Object?> get props => [areas, radiusKm, latitude, longitude];
}
