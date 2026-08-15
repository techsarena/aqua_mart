import 'package:equatable/equatable.dart';

import '../../../catalog/domain/entities/bottle.dart';

/// One bottle size + purchase kind + quantity, as it appears on the order.
///
/// Refill and "buy new" of the same size are separate lines because they carry
/// different prices and only refills generate empties to return.
class OrderLine extends Equatable {
  const OrderLine({
    required this.bottleId,
    required this.size,
    required this.name,
    required this.kind,
    required this.unitPrice,
    required this.quantity,
  });

  final String bottleId;
  final BottleSize size;
  final String name;
  final PurchaseKind kind;
  final int unitPrice;
  final int quantity;

  int get lineTotal => unitPrice * quantity;

  /// Only refills mean the customer hands an empty back.
  int get emptiesReturned => kind == PurchaseKind.refill ? quantity : 0;

  /// `Refill · Rs 110 each`
  String get unitLabel => '${kind.label} · Rs $unitPrice each';

  /// `2 × 25L refill`
  String get summary =>
      '$quantity × ${size.litres}L ${kind == PurchaseKind.refill ? 'refill' : 'new'}';

  /// Composite key — a cart holds at most one line per (bottle, kind) pair.
  String get key => '$bottleId:${kind.name}';

  OrderLine copyWith({int? quantity}) => OrderLine(
    bottleId: bottleId,
    size: size,
    name: name,
    kind: kind,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [bottleId, kind, unitPrice, quantity];
}
