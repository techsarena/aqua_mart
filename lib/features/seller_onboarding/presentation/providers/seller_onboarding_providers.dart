import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../../../catalog/domain/entities/seller.dart';
import '../../data/datasources/seller_onboarding_data_source.dart';

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
    this.sellsOtherSizes = false,
    this.status = SellerVerificationStatus.detailsReceived,
  });

  final String businessName;
  final String ownerName;
  final SellerBusinessType? businessType;
  final Set<KycDocument> uploaded;
  final List<DraftBottle> bottles;

  /// "Something else" — a size we do not trade in yet. Flagged for the
  /// verification team to follow up rather than priced here.
  final bool sellsOtherSizes;
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
    bool? sellsOtherSizes,
    SellerVerificationStatus? status,
  }) => SellerApplication(
    businessName: businessName ?? this.businessName,
    ownerName: ownerName ?? this.ownerName,
    businessType: businessType ?? this.businessType,
    uploaded: uploaded ?? this.uploaded,
    bottles: bottles ?? this.bottles,
    sellsOtherSizes: sellsOtherSizes ?? this.sellsOtherSizes,
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

  void toggleOtherSizes() =>
      state = state.copyWith(sellsOtherSizes: !state.sellsOtherSizes);

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

  /// Registers the store, so the account becomes a seller (step 1).
  ///
  /// Must land before `/seller/onboarding` is reachable — that path sits
  /// outside the onboarding stack and needs a seller profile to exist.
  Future<Result<void>> register() => Result.guard(() async {
    final businessType = state.businessType;
    if (businessType == null) return;

    final status = await ref
        .read(sellerOnboardingDataSourceProvider)
        .register(
          businessName: state.businessName,
          ownerName: state.ownerName,
          businessType: businessType,
        );
    state = state.copyWith(status: status);
  });

  /// Submits the catalogue and moves the application into review.
  ///
  /// The status comes back from the server rather than being assumed, so a
  /// rejected resubmission does not show a waiting room that is not true.
  Future<Result<void>> submit() => Result.guard(() async {
    final status = await ref
        .read(sellerOnboardingDataSourceProvider)
        .submitForReview(
          bottles: [
            for (final bottle in state.bottles)
              BottleDraftPayload(
                litres: bottle.size.litres,
                refillPrice: bottle.refillPrice,
                newPrice: bottle.newPrice,
              ),
          ],
          sellsOtherSizes: state.sellsOtherSizes,
        );
    state = state.copyWith(status: status);
  });
}

final sellerOnboardingDataSourceProvider =
    Provider<SellerOnboardingRemoteDataSource>((ref) {
      return SellerOnboardingApiDataSource(ref.watch(apiClientProvider));
    });

/// The waiting room's live status (6.1).
///
/// Polled rather than pushed: approval is a human decision that takes hours,
/// so a socket that must stay open for it would cost more than it saves.
final sellerVerificationProvider = FutureProvider.autoDispose<VerificationState>(
  (ref) => ref.watch(sellerOnboardingDataSourceProvider).fetchStatus(),
);

final sellerApplicationProvider =
    NotifierProvider<SellerApplicationNotifier, SellerApplication>(
      SellerApplicationNotifier.new,
    );
