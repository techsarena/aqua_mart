import '../../../addresses/data/models/address_dto.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_line.dart';
import '../../domain/entities/order_status.dart';

class OrderLineDto {
  const OrderLineDto({
    required this.bottleId,
    required this.litres,
    required this.name,
    required this.kind,
    required this.unitPrice,
    required this.quantity,
  });

  final String bottleId;
  final int litres;
  final String name;
  final String kind;
  final int unitPrice;
  final int quantity;

  factory OrderLineDto.fromJson(Map<String, dynamic> json) => OrderLineDto(
    bottleId: '${json['bottle_id']}',
    litres: (json['litres'] as num?)?.toInt() ?? 25,
    name: json['name'] as String? ?? '',
    kind: json['kind'] as String? ?? 'refill',
    unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'bottle_id': bottleId,
    'litres': litres,
    'name': name,
    'kind': kind,
    'unit_price': unitPrice,
    'quantity': quantity,
  };

  OrderLine toDomain() => OrderLine(
    bottleId: bottleId,
    size: BottleSize.fromLitres(litres),
    name: name,
    kind:
        PurchaseKind.values.where((k) => k.name == kind).firstOrNull ??
        PurchaseKind.refill,
    unitPrice: unitPrice,
    quantity: quantity,
  );

  static OrderLineDto fromDomain(OrderLine line) => OrderLineDto(
    bottleId: line.bottleId,
    litres: line.size.litres,
    name: line.name,
    kind: line.kind.name,
    unitPrice: line.unitPrice,
    quantity: line.quantity,
  );
}

class OrderDto {
  const OrderDto({
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
    this.riderId,
    this.riderName,
    this.riderRating,
    this.stopsBefore,
    this.rating,
    this.cancellationReason,
    this.rejectionReason,
  });

  final String id;
  final String reference;
  final String sellerId;
  final String sellerName;
  final List<OrderLineDto> lines;
  final AddressDto address;
  final String paymentMethod;
  final String status;
  final String placedAt;
  final String customerName;
  final int deliveryFee;
  final int etaMinutes;
  final String? riderId;
  final String? riderName;
  final double? riderRating;
  final int? stopsBefore;
  final int? rating;
  final String? cancellationReason;
  final String? rejectionReason;

  factory OrderDto.fromJson(Map<String, dynamic> json) => OrderDto(
    id: '${json['id']}',
    reference: json['reference'] as String? ?? '',
    sellerId: '${json['seller_id']}',
    sellerName: json['seller_name'] as String? ?? '',
    lines:
        (json['lines'] as List?)
            ?.map((e) => OrderLineDto.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    address: AddressDto.fromJson(
      json['address'] as Map<String, dynamic>? ?? const {},
    ),
    paymentMethod: json['payment_method'] as String? ?? 'cash',
    status: json['status'] as String? ?? 'pending',
    placedAt: json['placed_at'] as String? ?? DateTime.now().toIso8601String(),
    customerName: json['customer_name'] as String? ?? '',
    deliveryFee: (json['delivery_fee'] as num?)?.toInt() ?? 0,
    etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 25,
    riderId: json['rider_id'] as String?,
    riderName: json['rider_name'] as String?,
    riderRating: (json['rider_rating'] as num?)?.toDouble(),
    stopsBefore: (json['stops_before'] as num?)?.toInt(),
    rating: (json['rating'] as num?)?.toInt(),
    cancellationReason: json['cancellation_reason'] as String?,
    rejectionReason: json['rejection_reason'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'seller_id': sellerId,
    'seller_name': sellerName,
    'lines': lines.map((l) => l.toJson()).toList(),
    'address': address.toJson(),
    'payment_method': paymentMethod,
    'status': status,
    'placed_at': placedAt,
    'customer_name': customerName,
    'delivery_fee': deliveryFee,
    'eta_minutes': etaMinutes,
    'rider_id': riderId,
    'rider_name': riderName,
    'rating': rating,
  };

  Order toDomain() {
    final domainStatus =
        OrderStatus.values.where((s) => s.name == status).firstOrNull ??
        OrderStatus.pending;

    return Order(
      id: id,
      reference: reference,
      sellerId: sellerId,
      sellerName: sellerName,
      lines: lines.map((l) => l.toDomain()).toList(),
      address: address.toDomain(),
      paymentMethod:
          PaymentMethod.values.where((p) => p.name == paymentMethod).firstOrNull ??
          PaymentMethod.cash,
      status: domainStatus,
      placedAt: DateTime.tryParse(placedAt) ?? DateTime.now(),
      customerName: customerName,
      deliveryFee: deliveryFee,
      etaMinutes: etaMinutes,
      rider: riderId == null
          ? null
          : RiderSummary(
              id: riderId!,
              name: riderName ?? '',
              sellerName: sellerName,
              rating: riderRating ?? 0,
              stopsBefore: stopsBefore ?? 0,
            ),
      rating: rating,
      cancellationReason: cancellationReason,
      rejectionReason: rejectionReason,
    );
  }

  static OrderDto fromDomain(Order order) => OrderDto(
    id: order.id,
    reference: order.reference,
    sellerId: order.sellerId,
    sellerName: order.sellerName,
    lines: order.lines.map(OrderLineDto.fromDomain).toList(),
    address: AddressDto.fromDomain(order.address),
    paymentMethod: order.paymentMethod.name,
    status: order.status.name,
    placedAt: order.placedAt.toIso8601String(),
    customerName: order.customerName,
    deliveryFee: order.deliveryFee,
    etaMinutes: order.etaMinutes,
    riderId: order.rider?.id,
    riderName: order.rider?.name,
    riderRating: order.rider?.rating,
    stopsBefore: order.rider?.stopsBefore,
    rating: order.rating,
    cancellationReason: order.cancellationReason,
    rejectionReason: order.rejectionReason,
  );
}
