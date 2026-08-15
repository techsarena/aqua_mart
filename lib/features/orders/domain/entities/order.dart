import 'package:equatable/equatable.dart';

import '../../../../core/utils/formatters.dart';
import '../../../addresses/domain/entities/address.dart';
import 'order_line.dart';
import 'order_status.dart';

/// One step on the customer's tracking timeline.
class OrderEvent extends Equatable {
  const OrderEvent({
    required this.status,
    required this.title,
    required this.subtitle,
    this.at,
    this.isComplete = false,
  });

  final OrderStatus status;
  final String title;
  final String subtitle;
  final DateTime? at;
  final bool isComplete;

  @override
  List<Object?> get props => [status, title, at, isComplete];
}

/// The rider carrying an order, as the customer sees them.
class RiderSummary extends Equatable {
  const RiderSummary({
    required this.id,
    required this.name,
    required this.sellerName,
    this.rating = 0,
    this.avatarUrl,
    this.stopsBefore = 0,
  });

  final String id;
  final String name;
  final String sellerName;
  final double rating;
  final String? avatarUrl;
  final int stopsBefore;

  @override
  List<Object?> get props => [id, name, rating, stopsBefore];
}

/// The central aggregate. The customer, seller and rider apps all render this
/// same entity — each surfaces a different slice of it.
class Order extends Equatable {
  const Order({
    required this.id,
    required this.reference,
    required this.sellerId,
    required this.sellerName,
    required this.lines,
    required this.address,
    required this.paymentMethod,
    required this.status,
    required this.placedAt,
    this.customerName = '',
    this.deliveryFee = 0,
    this.etaMinutes = 25,
    this.rider,
    this.timeline = const [],
    this.rating,
    this.cancellationReason,
    this.rejectionReason,
  });

  final String id;

  /// Human-facing order number — `SO-2418`.
  final String reference;
  final String sellerId;
  final String sellerName;
  final List<OrderLine> lines;
  final Address address;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final DateTime placedAt;

  /// Populated in the seller and rider apps.
  final String customerName;
  final int deliveryFee;
  final int etaMinutes;
  final RiderSummary? rider;
  final List<OrderEvent> timeline;
  final int? rating;
  final String? cancellationReason;
  final String? rejectionReason;

  int get subtotal => lines.fold(0, (sum, l) => sum + l.lineTotal);

  int get total => subtotal + deliveryFee;

  /// How many empties the customer hands back at the door.
  int get emptiesReturned => lines.fold(0, (sum, l) => sum + l.emptiesReturned);

  int get bottleCount => lines.fold(0, (sum, l) => sum + l.quantity);

  /// `2 × 25L refill` — or `2 × 25L refill + 1 × 6L new` for mixed orders.
  String get itemsSummary => lines.map((l) => l.summary).join(' + ');

  bool get isCancellable =>
      status == OrderStatus.pending ||
      status == OrderStatus.accepted ||
      status == OrderStatus.packed ||
      status == OrderStatus.onTheWay;

  /// The four stages the customer follows on the tracking screen.
  ///
  /// Derived from [status] rather than read from [timeline], because the
  /// backend sends a status, not prose — only the stage the order has reached
  /// is real data. A stored [timeline] still wins when one is present, which
  /// is what carries the exact timestamps on an order that has them.
  List<OrderEvent> get trackingSteps {
    if (timeline.isNotEmpty) return timeline;

    // Unhappy paths never reach the delivery stages, so the rail stops at the
    // point the order actually died rather than showing steps that won't come.
    if (status == OrderStatus.cancelledByCustomer ||
        status == OrderStatus.rejectedBySeller) {
      return [
        OrderEvent(
          status: OrderStatus.pending,
          title: 'Order placed',
          subtitle: 'sent to the seller',
          at: placedAt,
          isComplete: true,
        ),
        OrderEvent(
          status: status,
          title: status == OrderStatus.cancelledByCustomer
              ? 'You cancelled this order'
              : 'Seller could not take this order',
          subtitle:
              cancellationReason ?? rejectionReason ?? 'No charge was made.',
          isComplete: true,
        ),
      ];
    }

    /// A stage counts as reached once the order is at or past it.
    bool reached(OrderStatus stage) =>
        status.index >= stage.index && !status.isTerminalUnhappy;

    final cashLine = paymentMethod.isCollectedByRider
        ? 'Pay ${Formatters.rupees(total)} cash'
        : '${paymentMethod.label} · already paid';
    final emptiesLine = emptiesReturned > 0
        ? ' · keep $emptiesReturned empties ready'
        : '';

    return [
      OrderEvent(
        status: OrderStatus.accepted,
        title: 'Order confirmed',
        subtitle: 'seller accepted',
        at: reached(OrderStatus.accepted) ? placedAt : null,
        isComplete: reached(OrderStatus.accepted),
      ),
      OrderEvent(
        status: OrderStatus.packed,
        title: 'Bottles loaded',
        subtitle: 'sealed and checked',
        isComplete: reached(OrderStatus.packed),
      ),
      OrderEvent(
        status: OrderStatus.onTheWay,
        title: 'On the way',
        subtitle: switch (rider?.stopsBefore) {
          null || 0 => 'heading to you now',
          final stops => '$stops stops before you',
        },
        isComplete: reached(OrderStatus.onTheWay),
      ),
      OrderEvent(
        status: OrderStatus.delivered,
        title: 'Delivered',
        subtitle: '$cashLine$emptiesLine',
        isComplete: reached(OrderStatus.delivered),
      ),
    ];
  }

  Order copyWith({
    OrderStatus? status,
    RiderSummary? rider,
    List<OrderEvent>? timeline,
    int? etaMinutes,
    int? rating,
    String? cancellationReason,
    String? rejectionReason,
  }) => Order(
    id: id,
    reference: reference,
    sellerId: sellerId,
    sellerName: sellerName,
    lines: lines,
    address: address,
    paymentMethod: paymentMethod,
    status: status ?? this.status,
    placedAt: placedAt,
    customerName: customerName,
    deliveryFee: deliveryFee,
    etaMinutes: etaMinutes ?? this.etaMinutes,
    rider: rider ?? this.rider,
    timeline: timeline ?? this.timeline,
    rating: rating ?? this.rating,
    cancellationReason: cancellationReason ?? this.cancellationReason,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );

  @override
  List<Object?> get props => [id, reference, status, lines, paymentMethod];
}
