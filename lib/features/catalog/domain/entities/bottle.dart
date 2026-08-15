import 'package:equatable/equatable.dart';

/// The sizes Aqua Mart trades in.
enum BottleSize {
  six(6, '6 L'),
  ten(10, '10 L'),
  twentyFive(25, '25 L');

  const BottleSize(this.litres, this.label);

  final int litres;
  final String label;

  static BottleSize fromLitres(int litres) => BottleSize.values.firstWhere(
    (s) => s.litres == litres,
    orElse: () => BottleSize.twentyFive,
  );
}

/// Refill = the customer hands over an empty bottle.
/// Buy new = the customer keeps the bottle and pays a deposit.
enum PurchaseKind {
  refill('Refill', 'you hand over an empty bottle'),
  buyNew('Buy new', 'you keep the bottle');

  const PurchaseKind(this.label, this.explainer);

  final String label;
  final String explainer;
}

/// A bottle a seller lists, with both prices side by side.
class Bottle extends Equatable {
  const Bottle({
    required this.id,
    required this.sellerId,
    required this.size,
    required this.name,
    required this.refillPrice,
    required this.newPrice,
    this.deposit = 300,
    this.description = '',
    this.filledStock = 0,
    this.emptiesInYard = 0,
    this.photoUrl,
    this.isVisible = true,
  });

  final String id;
  final String sellerId;
  final BottleSize size;
  final String name;
  final int refillPrice;
  final int newPrice;
  final int deposit;
  final String description;
  final int filledStock;
  final int emptiesInYard;
  final String? photoUrl;

  /// Sellers can hide a bottle without deleting it.
  final bool isVisible;

  bool get isLowStock => filledStock > 0 && filledStock <= 5;
  bool get isOutOfStock => filledStock <= 0;

  int priceFor(PurchaseKind kind) =>
      kind == PurchaseKind.refill ? refillPrice : newPrice;

  Bottle copyWith({
    int? refillPrice,
    int? newPrice,
    int? deposit,
    int? filledStock,
    bool? isVisible,
    String? name,
    BottleSize? size,
  }) => Bottle(
    id: id,
    sellerId: sellerId,
    size: size ?? this.size,
    name: name ?? this.name,
    refillPrice: refillPrice ?? this.refillPrice,
    newPrice: newPrice ?? this.newPrice,
    deposit: deposit ?? this.deposit,
    description: description,
    filledStock: filledStock ?? this.filledStock,
    emptiesInYard: emptiesInYard,
    photoUrl: photoUrl,
    isVisible: isVisible ?? this.isVisible,
  );

  @override
  List<Object?> get props => [
    id,
    sellerId,
    size,
    name,
    refillPrice,
    newPrice,
    filledStock,
    isVisible,
  ];
}
