import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../addresses/domain/entities/address.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../../domain/entities/order_line.dart';
import '../../domain/entities/order_status.dart';

/// The in-progress order: which seller, which bottles, where and how to pay.
///
/// Lives above the browse → cart → pay screens, all three of which read and
/// mutate it.
class CartState {
  const CartState({
    this.sellerId,
    this.sellerName = '',
    this.lines = const {},
    this.address,
    this.paymentMethod = PaymentMethod.cash,
    this.promoCode,
    this.deliveryFee = 0,
  });

  final String? sellerId;
  final String sellerName;

  /// Keyed by `bottleId:kind` so refill and buy-new of one size stay separate.
  final Map<String, OrderLine> lines;
  final Address? address;
  final PaymentMethod paymentMethod;
  final String? promoCode;
  final int deliveryFee;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get bottleCount => lines.values.fold(0, (sum, l) => sum + l.quantity);

  int get subtotal => lines.values.fold(0, (sum, l) => sum + l.lineTotal);

  int get total => subtotal + deliveryFee;

  /// Refills mean empties go back with the rider.
  int get emptiesReturned =>
      lines.values.fold(0, (sum, l) => sum + l.emptiesReturned);

  List<OrderLine> get orderedLines => lines.values.toList();

  /// Quantity of a given bottle regardless of purchase kind — drives the
  /// stepper on the seller's bottle list.
  int quantityOf(String bottleId) => lines.values
      .where((l) => l.bottleId == bottleId)
      .fold(0, (sum, l) => sum + l.quantity);

  int quantityOfKind(String bottleId, PurchaseKind kind) =>
      lines['$bottleId:${kind.name}']?.quantity ?? 0;

  CartState copyWith({
    String? sellerId,
    String? sellerName,
    Map<String, OrderLine>? lines,
    Address? address,
    PaymentMethod? paymentMethod,
    String? promoCode,
    int? deliveryFee,
  }) => CartState(
    sellerId: sellerId ?? this.sellerId,
    sellerName: sellerName ?? this.sellerName,
    lines: lines ?? this.lines,
    address: address ?? this.address,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    promoCode: promoCode ?? this.promoCode,
    deliveryFee: deliveryFee ?? this.deliveryFee,
  );
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Adds or removes [delta] of one bottle in one purchase kind.
  ///
  /// A cart holds one seller at a time: adding from a different seller starts
  /// a fresh cart, matching how the design moves the customer store to store.
  void adjust({
    required Bottle bottle,
    required PurchaseKind kind,
    required String sellerName,
    int delta = 1,
  }) {
    final startingFresh =
        state.sellerId != null && state.sellerId != bottle.sellerId;
    final lines = startingFresh
        ? <String, OrderLine>{}
        : Map<String, OrderLine>.from(state.lines);

    final key = '${bottle.id}:${kind.name}';
    final existing = lines[key];
    final quantity = (existing?.quantity ?? 0) + delta;

    if (quantity <= 0) {
      lines.remove(key);
    } else {
      lines[key] = OrderLine(
        bottleId: bottle.id,
        size: bottle.size,
        name: bottle.name,
        kind: kind,
        unitPrice: bottle.priceFor(kind),
        quantity: quantity,
      );
    }

    state = state.copyWith(
      sellerId: bottle.sellerId,
      sellerName: sellerName,
      lines: lines,
    );
  }

  /// Increment/decrement an existing line straight from the cart screen.
  void adjustLine(OrderLine line, int delta) {
    final lines = Map<String, OrderLine>.from(state.lines);
    final quantity = line.quantity + delta;
    if (quantity <= 0) {
      lines.remove(line.key);
    } else {
      lines[line.key] = line.copyWith(quantity: quantity);
    }
    state = state.copyWith(lines: lines);
  }

  /// Loads a past order back into the cart — the "Reorder" and "Your usual"
  /// actions.
  void loadLines({
    required String sellerId,
    required String sellerName,
    required List<OrderLine> lines,
  }) => state = state.copyWith(
    sellerId: sellerId,
    sellerName: sellerName,
    lines: {for (final line in lines) line.key: line},
  );

  void setAddress(Address address) => state = state.copyWith(address: address);

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  void applyPromo(String code) => state = state.copyWith(promoCode: code);

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
