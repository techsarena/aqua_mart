import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/bottle.dart';
import '../../../catalog/domain/entities/seller.dart';

/// A size the applicant offers, with the two prices they set for it.
class DraftBottle {
  const DraftBottle({
    required this.size,
    this.refillPrice = 0,
    this.newPrice = 0,
  });

  final BottleSize size;
  final int refillPrice;
  final int newPrice;

  bool get isPriced => refillPrice > 0 && newPrice > 0;

  DraftBottle copyWith({int? refillPrice, int? newPrice}) => DraftBottle(
    size: size,
    refillPrice: refillPrice ?? this.refillPrice,
    newPrice: newPrice ?? this.newPrice,
  );
}

/// The documents the verification team needs.
enum KycDocument {
  cnic('CNIC — front & back', true),
  waterTest('Water testing certificate', true),
  licence('NTN / business licence', false),
  plantPhoto('Photo of your plant', false);

  const KycDocument(this.label, this.isRequired);

  final String label;
  final bool isRequired;

  String get hint => switch (this) {
    KycDocument.cnic => 'Tap to photograph · required',
    KycDocument.waterTest => 'Tap to photograph · required',
    KycDocument.licence => 'Optional — speeds up approval',
    KycDocument.plantPhoto => 'Shown on your store page',
  };

  /// What the tile reads once the photos are in. The CNIC needs both faces,
  /// so it is the one document that reports a count.
  String get uploadedHint =>
      this == KycDocument.cnic ? 'Uploaded · 2 photos' : 'Uploaded';
}

/// Everything collected across the four seller sign-up steps.
class SellerApplication {
  const SellerApplication({
    this.businessName = '',
    this.ownerName = '',
    this.businessType,
    this.uploaded = const {},
    this.bottles = const [],
    this.status = SellerVerificationStatus.detailsReceived,
  });

  final String businessName;
  final String ownerName;
  final SellerBusinessType? businessType;
  final Set<KycDocument> uploaded;
  final List<DraftBottle> bottles;
  final SellerVerificationStatus status;

  bool get detailsComplete =>
      businessName.trim().isNotEmpty &&
      ownerName.trim().isNotEmpty &&
      businessType != null;

  bool get documentsComplete =>
      KycDocument.values.where((d) => d.isRequired).every(uploaded.contains);

  bool get catalogComplete =>
      bottles.isNotEmpty && bottles.every((b) => b.isPriced);

  SellerApplication copyWith({
    String? businessName,
    String? ownerName,
    SellerBusinessType? businessType,
    Set<KycDocument>? uploaded,
    List<DraftBottle>? bottles,
    SellerVerificationStatus? status,
  }) => SellerApplication(
    businessName: businessName ?? this.businessName,
    ownerName: ownerName ?? this.ownerName,
    businessType: businessType ?? this.businessType,
    uploaded: uploaded ?? this.uploaded,
    bottles: bottles ?? this.bottles,
    status: status ?? this.status,
  );
}

class SellerApplicationNotifier extends Notifier<SellerApplication> {
  @override
  SellerApplication build() => const SellerApplication();

  void setDetails({
    String? businessName,
    String? ownerName,
    SellerBusinessType? businessType,
  }) => state = state.copyWith(
    businessName: businessName,
    ownerName: ownerName,
    businessType: businessType,
  );

  void toggleDocument(KycDocument document) {
    final uploaded = Set<KycDocument>.from(state.uploaded);
    uploaded.contains(document)
        ? uploaded.remove(document)
        : uploaded.add(document);
    state = state.copyWith(uploaded: uploaded);
  }

  void toggleSize(BottleSize size) {
    final bottles = [...state.bottles];
    final index = bottles.indexWhere((b) => b.size == size);

    if (index >= 0) {
      bottles.removeAt(index);
    } else {
      // Seed with the standard prices for that size so the seller can adjust
      // rather than type from scratch.
      bottles.add(
        DraftBottle(
          size: size,
          refillPrice: switch (size) {
            BottleSize.six => 45,
            BottleSize.ten => 70,
            BottleSize.twentyFive => 110,
          },
          newPrice: switch (size) {
            BottleSize.six => 120,
            BottleSize.ten => 190,
            BottleSize.twentyFive => 420,
          },
        ),
      );
      bottles.sort((a, b) => b.size.litres.compareTo(a.size.litres));
    }
    state = state.copyWith(bottles: bottles);
  }

  void setPrice(BottleSize size, {int? refillPrice, int? newPrice}) {
    state = state.copyWith(
      bottles: [
        for (final bottle in state.bottles)
          if (bottle.size == size)
            bottle.copyWith(refillPrice: refillPrice, newPrice: newPrice)
          else
            bottle,
      ],
    );
  }

  /// Moves the application into review — what the waiting room reflects.
  void submit() =>
      state = state.copyWith(status: SellerVerificationStatus.inReview);
}

final sellerApplicationProvider =
    NotifierProvider<SellerApplicationNotifier, SellerApplication>(
      SellerApplicationNotifier.new,
    );
