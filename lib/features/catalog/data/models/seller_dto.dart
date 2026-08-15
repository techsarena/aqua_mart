import '../../domain/entities/bottle.dart';
import '../../domain/entities/seller.dart';

/// Wire model for a seller.
///
/// DTOs own JSON parsing so domain entities stay free of serialisation
/// concerns. When the real API arrives, only `fromJson` keys change here.
class SellerDto {
  const SellerDto({
    required this.id,
    required this.name,
    required this.rating,
    required this.ratingCount,
    required this.etaMinutes,
    this.purificationLabel,
    this.sizes = const [],
    this.cheapestRefillPrice,
    this.isOpen = true,
    this.opensAt,
    this.distanceMetres,
    this.freeDeliveryOver,
    this.logoUrl,
    this.isRegular = false,
    this.latitude,
    this.longitude,
    this.businessType,
    this.verificationStatus,
  });

  final String id;
  final String name;
  final double rating;
  final int ratingCount;
  final int etaMinutes;
  final String? purificationLabel;
  final List<int> sizes;
  final int? cheapestRefillPrice;
  final bool isOpen;
  final String? opensAt;
  final double? distanceMetres;
  final int? freeDeliveryOver;
  final String? logoUrl;
  final bool isRegular;
  final double? latitude;
  final double? longitude;
  final String? businessType;
  final String? verificationStatus;

  factory SellerDto.fromJson(Map<String, dynamic> json) => SellerDto(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 30,
    purificationLabel: json['purification'] as String?,
    sizes:
        (json['sizes'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [],
    cheapestRefillPrice: (json['cheapest_refill_price'] as num?)?.toInt(),
    isOpen: json['is_open'] as bool? ?? true,
    opensAt: json['opens_at'] as String?,
    distanceMetres: (json['distance_metres'] as num?)?.toDouble(),
    freeDeliveryOver: (json['free_delivery_over'] as num?)?.toInt(),
    logoUrl: json['logo_url'] as String?,
    isRegular: json['is_regular'] as bool? ?? false,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    businessType: json['business_type'] as String?,
    verificationStatus: json['verification_status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rating': rating,
    'rating_count': ratingCount,
    'eta_minutes': etaMinutes,
    'purification': purificationLabel,
    'sizes': sizes,
    'cheapest_refill_price': cheapestRefillPrice,
    'is_open': isOpen,
    'opens_at': opensAt,
    'distance_metres': distanceMetres,
    'free_delivery_over': freeDeliveryOver,
    'logo_url': logoUrl,
    'is_regular': isRegular,
    'latitude': latitude,
    'longitude': longitude,
    'business_type': businessType,
    'verification_status': verificationStatus,
  };

  Seller toDomain() => Seller(
    id: id,
    name: name,
    rating: rating,
    ratingCount: ratingCount,
    etaMinutes: etaMinutes,
    purificationLabel: purificationLabel ?? '',
    sizes: sizes.map(BottleSize.fromLitres).toList(),
    cheapestRefillPrice: cheapestRefillPrice,
    isOpen: isOpen,
    opensAt: opensAt,
    distanceMetres: distanceMetres,
    freeDeliveryOver: freeDeliveryOver,
    logoUrl: logoUrl,
    isRegular: isRegular,
    latitude: latitude,
    longitude: longitude,
    businessType: SellerBusinessType.values
        .where((t) => t.name == businessType)
        .firstOrNull ??
        SellerBusinessType.roPlant,
    verificationStatus: SellerVerificationStatus.values
        .where((s) => s.name == verificationStatus)
        .firstOrNull ??
        SellerVerificationStatus.approved,
  );

  static SellerDto fromDomain(Seller seller) => SellerDto(
    id: seller.id,
    name: seller.name,
    rating: seller.rating,
    ratingCount: seller.ratingCount,
    etaMinutes: seller.etaMinutes,
    purificationLabel: seller.purificationLabel,
    sizes: seller.sizes.map((s) => s.litres).toList(),
    cheapestRefillPrice: seller.cheapestRefillPrice,
    isOpen: seller.isOpen,
    opensAt: seller.opensAt,
    distanceMetres: seller.distanceMetres,
    freeDeliveryOver: seller.freeDeliveryOver,
    logoUrl: seller.logoUrl,
    isRegular: seller.isRegular,
    latitude: seller.latitude,
    longitude: seller.longitude,
    businessType: seller.businessType.name,
    verificationStatus: seller.verificationStatus.name,
  );
}
