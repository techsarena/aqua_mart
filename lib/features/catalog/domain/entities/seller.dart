import 'package:equatable/equatable.dart';

import 'bottle.dart';

enum SellerBusinessType {
  roPlant('RO plant'),
  waterShop('Water shop'),
  distributor('Distributor'),
  mineralBrand('Mineral brand');

  const SellerBusinessType(this.label);
  final String label;
}

/// Where a seller sits in the verification pipeline.
enum SellerVerificationStatus {
  detailsReceived,
  documentsUploaded,
  inReview,
  approved,
  rejected;

  bool get isLive => this == SellerVerificationStatus.approved;
}

class Seller extends Equatable {
  const Seller({
    required this.id,
    required this.name,
    required this.rating,
    required this.ratingCount,
    required this.etaMinutes,
    this.purificationLabel = '',
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
    this.businessType = SellerBusinessType.roPlant,
    this.verificationStatus = SellerVerificationStatus.approved,
  });

  final String id;
  final String name;
  final double rating;
  final int ratingCount;
  final int etaMinutes;

  /// `RO + UV`, `Mineral`
  final String purificationLabel;
  final List<BottleSize> sizes;
  final int? cheapestRefillPrice;
  final bool isOpen;

  /// Shown as `Closed · opens 8:00 AM`.
  final String? opensAt;
  final double? distanceMetres;
  final int? freeDeliveryOver;
  final String? logoUrl;

  /// True when the customer has ordered from this seller before.
  final bool isRegular;
  final double? latitude;
  final double? longitude;
  final SellerBusinessType businessType;
  final SellerVerificationStatus verificationStatus;

  /// `RO + UV · 6L · 10L · 25L`
  String get subtitle {
    final sizeText = sizes.map((s) => '${s.litres}L').join(' · ');
    if (purificationLabel.isEmpty) return sizeText;
    return sizeText.isEmpty
        ? purificationLabel
        : '$purificationLabel · $sizeText';
  }

  @override
  List<Object?> get props => [id, name, rating, etaMinutes, isOpen];
}
