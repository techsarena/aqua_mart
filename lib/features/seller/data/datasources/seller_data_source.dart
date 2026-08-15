import '../../../../core/error/failure.dart';
import '../../../../core/mock/mock_fixtures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../addresses/domain/entities/address.dart';
import '../../../catalog/data/models/bottle_dto.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../../../orders/data/models/order_dto.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_line.dart';
import '../../../orders/domain/entities/order_status.dart';
import '../../domain/entities/seller_dashboard.dart';

abstract interface class SellerRemoteDataSource {
  Future<SellerDashboard> fetchDashboard();
  Future<void> setOpen({required bool isOpen});
  Future<List<OrderDto>> fetchQueue();
  Future<OrderDto> advanceOrder(String orderId);
  Future<OrderDto> declineOrder(String orderId, String reason);
  Future<void> assignRider({required String orderId, required String riderId});
  Future<List<BottleDto>> fetchInventory();
  Future<BottleDto> saveBottle(BottleDto bottle);
  Future<List<Rider>> fetchRiders();
  Future<List<Payout>> fetchPayouts();
  Future<Dispute> fetchDispute(String id);
  Future<void> resolveDispute(String id, DisputeResolution resolution);
}

class SellerApiDataSource implements SellerRemoteDataSource {
  const SellerApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<SellerDashboard> fetchDashboard() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sellerDashboard,
    );
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return SellerDashboard(
      ordersToday: (data['orders_today'] as num?)?.toInt() ?? 0,
      delivered: (data['delivered'] as num?)?.toInt() ?? 0,
      earned: (data['earned'] as num?)?.toInt() ?? 0,
      isOpen: data['is_open'] as bool? ?? true,
      pendingCount: (data['pending_count'] as num?)?.toInt() ?? 0,
      lowStockLabel: data['low_stock_label'] as String?,
      sync: ErpSyncState(
        isOnline: data['sync_online'] as bool? ?? true,
        pendingUploads: (data['sync_pending'] as num?)?.toInt() ?? 0,
        lastSyncedAt: DateTime.tryParse(
          data['last_synced_at'] as String? ?? '',
        ),
      ),
    );
  }

  @override
  Future<void> setOpen({required bool isOpen}) => _client.post<void>(
    ApiEndpoints.toggleStoreOpen,
    body: {'is_open': isOpen},
  );

  @override
  Future<List<OrderDto>> fetchQueue() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sellerOrders,
    );
    final items = (json['data'] ?? json['orders']) as List? ?? const [];
    return items
        .map((e) => OrderDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderDto> advanceOrder(String orderId) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.advanceOrder(orderId),
    );
    return OrderDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<OrderDto> declineOrder(String orderId, String reason) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.declineOrder(orderId),
      body: {'reason': reason},
    );
    return OrderDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<void> assignRider({
    required String orderId,
    required String riderId,
  }) => _client.post<void>(
    ApiEndpoints.assignRider(orderId),
    body: {'rider_id': riderId},
  );

  @override
  Future<List<BottleDto>> fetchInventory() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sellerInventory,
    );
    final items = (json['data'] ?? json['bottles']) as List? ?? const [];
    return items
        .map((e) => BottleDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BottleDto> saveBottle(BottleDto bottle) async {
    final json = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.sellerBottle(bottle.id),
      body: bottle.toJson(),
    );
    return BottleDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<List<Rider>> fetchRiders() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sellerRiders,
    );
    final items = (json['data'] ?? json['riders']) as List? ?? const [];
    return items.map((e) => _riderFrom(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Payout>> fetchPayouts() async {
    final json = await _client.get<Map<String, dynamic>>(ApiEndpoints.payouts);
    final items = (json['data'] ?? json['payouts']) as List? ?? const [];
    return items.map((e) => _payoutFrom(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Dispute> fetchDispute(String id) async {
    final json = await _client.get<Map<String, dynamic>>(
      '${ApiEndpoints.disputes}/$id',
    );
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return Dispute(
      id: '${data['id']}',
      orderReference: data['order_reference'] as String? ?? '',
      customerName: data['customer_name'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      customerNote: data['customer_note'] as String? ?? '',
      orderSummary: data['order_summary'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      raisedAt:
          DateTime.tryParse(data['raised_at'] as String? ?? '') ??
          DateTime.now(),
      customerHistory: data['customer_history'] as String?,
      hasPhoto: data['has_photo'] as bool? ?? false,
    );
  }

  @override
  Future<void> resolveDispute(String id, DisputeResolution resolution) =>
      _client.post<void>(
        ApiEndpoints.resolveDispute(id),
        body: {'resolution': resolution.name},
      );

  Rider _riderFrom(Map<String, dynamic> json) => Rider(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    status:
        RiderStatus.values.where((s) => s.name == json['status']).firstOrNull ??
        RiderStatus.idle,
    stopsLeft: (json['stops_left'] as num?)?.toInt() ?? 0,
    distanceFromCustomer: (json['distance_from_customer'] as num?)?.toDouble(),
    etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
    delivered: (json['delivered'] as num?)?.toInt() ?? 0,
    onTimePercent: (json['on_time_percent'] as num?)?.toInt() ?? 0,
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    lateDeliveries: (json['late_deliveries'] as num?)?.toInt() ?? 0,
    complaints: (json['complaints'] as num?)?.toInt() ?? 0,
  );

  Payout _payoutFrom(Map<String, dynamic> json) => Payout(
    id: '${json['id']}',
    weekLabel: json['week_label'] as String? ?? '',
    ordersDelivered: (json['orders_delivered'] as num?)?.toInt() ?? 0,
    grossSales: (json['gross_sales'] as num?)?.toInt() ?? 0,
    depositsTaken: (json['deposits_taken'] as num?)?.toInt() ?? 0,
    depositsRefunded: (json['deposits_refunded'] as num?)?.toInt() ?? 0,
    commission: (json['commission'] as num?)?.toInt() ?? 0,
    complaintRefunds: (json['complaint_refunds'] as num?)?.toInt() ?? 0,
    cashCollectedByRiders:
        (json['cash_collected_by_riders'] as num?)?.toInt() ?? 0,
    netPaid: (json['net_paid'] as num?)?.toInt() ?? 0,
    isPaid: json['is_paid'] as bool? ?? false,
    paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
    bankLabel: json['bank_label'] as String?,
    reference: json['reference'] as String?,
  );
}

/// The seller's day, seeded from the design and mutable for the session.
class MockSellerDataSource implements SellerRemoteDataSource {
  MockSellerDataSource()
    : _queue = _seedQueue(),
      _inventory = MockFixtures.chashmaBottles
          .map(BottleDto.fromDomain)
          .toList();

  final List<OrderDto> _queue;
  final List<BottleDto> _inventory;
  bool _isOpen = true;

  static const _latency = Duration(milliseconds: 380);

  @override
  Future<SellerDashboard> fetchDashboard() async {
    await Future<void>.delayed(_latency);
    final lowStock = _inventory
        .where((b) => b.filledStock > 0 && b.filledStock <= 5)
        .firstOrNull;

    return SellerDashboard(
      ordersToday: 14,
      delivered: 9,
      earned: 12400,
      isOpen: _isOpen,
      pendingCount: _queue
          .where((o) => o.status == OrderStatus.pending.name)
          .length,
      lowStockLabel: lowStock == null
          ? null
          : '${lowStock.litres}L bottles running low — '
                '${lowStock.filledStock} left in stock',
      sync: ErpSyncState(
        isOnline: true,
        lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
    );
  }

  @override
  Future<void> setOpen({required bool isOpen}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _isOpen = isOpen;
  }

  @override
  Future<List<OrderDto>> fetchQueue() async {
    await Future<void>.delayed(_latency);
    return List<OrderDto>.unmodifiable(_queue);
  }

  @override
  Future<OrderDto> advanceOrder(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _queue.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const ServerFailure('That order is no longer here.');

    final order = _queue[index].toDomain();
    final next = order.status.nextForSeller;
    if (next == null) return _queue[index];

    final advanced = OrderDto.fromDomain(order.copyWith(status: next));
    _queue[index] = advanced;
    return advanced;
  }

  @override
  Future<OrderDto> declineOrder(String orderId, String reason) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _queue.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const ServerFailure('That order is no longer here.');

    final declined = OrderDto.fromDomain(
      _queue[index].toDomain().copyWith(
        status: OrderStatus.rejectedBySeller,
        rejectionReason: reason,
      ),
    );
    _queue[index] = declined;
    return declined;
  }

  @override
  Future<void> assignRider({
    required String orderId,
    required String riderId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _queue.indexWhere((o) => o.id == orderId);
    if (index < 0) return;

    final rider = _riders.firstWhere((r) => r.id == riderId);
    _queue[index] = OrderDto.fromDomain(
      _queue[index].toDomain().copyWith(
        status: OrderStatus.onTheWay,
        rider: RiderSummary(
          id: rider.id,
          name: rider.name,
          sellerName: 'Chashma Pure Water',
          rating: rider.rating,
          stopsBefore: rider.stopsLeft,
        ),
      ),
    );
  }

  @override
  Future<List<BottleDto>> fetchInventory() async {
    await Future<void>.delayed(_latency);
    return List<BottleDto>.unmodifiable(_inventory);
  }

  @override
  Future<BottleDto> saveBottle(BottleDto bottle) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _inventory.indexWhere((b) => b.id == bottle.id);
    if (index >= 0) {
      _inventory[index] = bottle;
    } else {
      _inventory.add(bottle);
    }
    return bottle;
  }

  @override
  Future<List<Rider>> fetchRiders() async {
    await Future<void>.delayed(_latency);
    return _riders;
  }

  @override
  Future<List<Payout>> fetchPayouts() async {
    await Future<void>.delayed(_latency);
    return [
      Payout(
        id: 'py-1',
        weekLabel: 'week of 28 Jul',
        ordersDelivered: 96,
        grossSales: 44120,
        depositsTaken: 2400,
        depositsRefunded: 900,
        commission: 3530,
        complaintRefunds: 110,
        cashCollectedByRiders: 3580,
        netPaid: 38400,
        isPaid: true,
        paidAt: DateTime(2026, 8, 3),
        bankLabel: 'Meezan Bank ••4471',
        reference: 'PY-11284',
      ),
      const Payout(
        id: 'py-2',
        weekLabel: '21 – 27 Jul',
        ordersDelivered: 88,
        grossSales: 40200,
        depositsTaken: 2100,
        depositsRefunded: 600,
        commission: 3216,
        complaintRefunds: 0,
        cashCollectedByRiders: 3384,
        netPaid: 35100,
        isPaid: true,
      ),
      const Payout(
        id: 'py-3',
        weekLabel: '14 – 20 Jul',
        ordersDelivered: 81,
        grossSales: 37400,
        depositsTaken: 1800,
        depositsRefunded: 300,
        commission: 2992,
        complaintRefunds: 0,
        cashCollectedByRiders: 3268,
        netPaid: 32640,
        isPaid: true,
      ),
    ];
  }

  @override
  Future<Dispute> fetchDispute(String id) async {
    await Future<void>.delayed(_latency);
    return Dispute(
      id: id,
      orderReference: 'SO-2418',
      customerName: 'Ayesha K.',
      reason: 'Seal was broken or missing',
      customerNote:
          'Ek bottle ka seal khula hua tha. Rider ne kaha theek hai, lekin '
          'main use nahi kar sakti.',
      orderSummary:
          '2 × 25L refill · Rs 220 cash · delivered by Imran at 8:44 AM',
      amount: 110,
      raisedAt: DateTime.now().subtract(const Duration(hours: 1)),
      customerHistory:
          'Her first complaint in 14 orders. She\'s a weekly customer — '
          'Rs 11,400 with you this year.',
      hasPhoto: true,
    );
  }

  @override
  Future<void> resolveDispute(String id, DisputeResolution resolution) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  static final _riders = <Rider>[
    const Rider(
      id: 'r-1',
      name: 'Imran Ali',
      status: RiderStatus.onRun,
      stopsLeft: 6,
      distanceFromCustomer: 400,
      etaMinutes: 14,
      delivered: 58,
      onTimePercent: 98,
      rating: 4.9,
    ),
    const Rider(
      id: 'r-2',
      name: 'Rashid Sheikh',
      status: RiderStatus.idle,
      etaMinutes: 28,
      delivered: 31,
      onTimePercent: 82,
      rating: 4.3,
      lateDeliveries: 4,
      complaints: 1,
    ),
    const Rider(id: 'r-3', name: 'Nasir Khan', status: RiderStatus.offDuty),
  ];

  /// The queue the design shows on the seller's Today and Orders screens.
  static List<OrderDto> _seedQueue() {
    final now = DateTime.now();

    Order build({
      required String id,
      required String reference,
      required String customer,
      required String area,
      required List<({int litres, int qty, PurchaseKind kind, int price})>
      items,
      required PaymentMethod payment,
      required OrderStatus status,
      required int minutesAgo,
    }) => Order(
      id: id,
      reference: reference,
      sellerId: 's-1',
      sellerName: 'Chashma Pure Water',
      customerName: customer,
      lines: [
        for (final item in items)
          OrderLine(
            bottleId: 'b-${item.litres}',
            size: BottleSize.fromLitres(item.litres),
            name: '${item.litres}L Bottle',
            kind: item.kind,
            unitPrice: item.price,
            quantity: item.qty,
          ),
      ],
      address: Address(
        id: 'a-$id',
        label: AddressLabel.home,
        title: 'Home',
        area: area,
      ),
      paymentMethod: payment,
      status: status,
      placedAt: now.subtract(Duration(minutes: minutesAgo)),
    );

    return [
      build(
        id: 'so-a',
        reference: 'SO-2418',
        customer: 'Ayesha K.',
        area: 'Gulberg III',
        items: [(litres: 25, qty: 2, kind: PurchaseKind.refill, price: 110)],
        payment: PaymentMethod.cash,
        status: OrderStatus.pending,
        minutesAgo: 2,
      ),
      build(
        id: 'so-b',
        reference: 'SO-2419',
        customer: 'Bilal R.',
        area: 'Model Town',
        items: [(litres: 25, qty: 1, kind: PurchaseKind.buyNew, price: 420)],
        payment: PaymentMethod.jazzCash,
        status: OrderStatus.pending,
        minutesAgo: 6,
      ),
      build(
        id: 'so-c',
        reference: 'SO-2417',
        customer: 'Sana M.',
        area: 'Garden Town',
        items: [(litres: 10, qty: 3, kind: PurchaseKind.refill, price: 70)],
        payment: PaymentMethod.cash,
        status: OrderStatus.accepted,
        minutesAgo: 11,
      ),
      build(
        id: 'so-d',
        reference: 'SO-2416',
        customer: 'Ahmad Store',
        area: 'Gulberg II',
        items: [(litres: 25, qty: 6, kind: PurchaseKind.refill, price: 110)],
        payment: PaymentMethod.khata,
        status: OrderStatus.packed,
        minutesAgo: 18,
      ),
      build(
        id: 'so-e',
        reference: 'SO-2415',
        customer: 'Fatima N.',
        area: 'Gulberg III',
        items: [(litres: 25, qty: 2, kind: PurchaseKind.refill, price: 110)],
        payment: PaymentMethod.cash,
        status: OrderStatus.onTheWay,
        minutesAgo: 34,
      ),
    ].map(OrderDto.fromDomain).toList();
  }
}
