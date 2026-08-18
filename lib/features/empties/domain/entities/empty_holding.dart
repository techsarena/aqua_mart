import 'package:equatable/equatable.dart';

/// Empty bottles of one size the customer is holding from one seller.
class EmptyHolding extends Equatable {
  const EmptyHolding({
    required this.id,
    required this.litres,
    required this.count,
    required this.sellerId,
    required this.sellerName,
    required this.deposit,
  });

  final String id;
  final int litres;
  final int count;
  final String sellerId;
  final String sellerName;

  /// The TOTAL deposit held for this holding, not the per-bottle figure.
  final int deposit;

  @override
  List<Object?> get props => [id, litres, count, sellerId, sellerName, deposit];
}

/// What the customer holds, and what it is worth back.
class EmptiesSummary extends Equatable {
  const EmptiesSummary({
    this.holdings = const [],
    this.totalDeposit = 0,
    this.refillPricePerBottle = 0,
  });

  final List<EmptyHolding> holdings;
  final int totalDeposit;

  /// The headline price of swapping one empty for a full bottle.
  final int refillPricePerBottle;

  int get bottleCount => holdings.fold(0, (sum, h) => sum + h.count);

  @override
  List<Object?> get props => [holdings, totalDeposit, refillPricePerBottle];
}

/// What the customer wants done with the empties they hand back.
enum EmptiesHandling {
  /// Trade them for full bottles at the refill price.
  swap,

  /// Give them back and take the deposit.
  refund,
}
