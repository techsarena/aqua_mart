import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../catalog/data/models/bottle_dto.dart';
import '../../../orders/data/models/order_dto.dart';
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
  Future<void> deleteBottle(String bottleId);
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
    final data =
        await _client.getObject(ApiEndpoints.sellerDashboard) ?? const {};
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
    final items = await _client.getList(ApiEndpoints.sellerOrders);
    return items.map(OrderDto.fromJson).toList();
  }

  @override
  Future<OrderDto> advanceOrder(String orderId) async {
    final json = await _client.postObject(ApiEndpoints.advanceOrder(orderId));
    return OrderDto.fromJson(json ?? const {});
  }

  @override
  Future<OrderDto> declineOrder(String orderId, String reason) async {
    final json = await _client.postObject(
      ApiEndpoints.declineOrder(orderId),
      body: {'reason': reason},
    );
    return OrderDto.fromJson(json ?? const {});
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
    final items = await _client.getList(ApiEndpoints.sellerInventory);
    return items.map(BottleDto.fromJson).toList();
  }

  @override
  Future<BottleDto> saveBottle(BottleDto bottle) async {
    final json = await _client.putObject(
      ApiEndpoints.sellerBottle(bottle.id),
      body: bottle.toJson(),
    );
    return BottleDto.fromJson(json ?? const {});
  }

  @override
  Future<void> deleteBottle(String bottleId) =>
      _client.delete<void>(ApiEndpoints.sellerBottle(bottleId));

  @override
  Future<List<Rider>> fetchRiders() async {
    final items = await _client.getList(ApiEndpoints.sellerRiders);
    return items.map(_riderFrom).toList();
  }

  @override
  Future<List<Payout>> fetchPayouts() async {
    final items = await _client.getList(ApiEndpoints.payouts);
    return items.map(_payoutFrom).toList();
  }

  @override
  Future<Dispute> fetchDispute(String id) async {
    final data =
        await _client.getObject(ApiEndpoints.sellerDispute(id)) ?? const {};
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
