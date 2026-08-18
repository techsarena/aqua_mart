import '../../../../core/error/failure.dart';
import '../../../../core/mock/mock_fixtures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../models/order_dto.dart';

/// A request to place an order, as the API expects it.
class PlaceOrderRequest {
  PlaceOrderRequest({
    required this.sellerId,
    required this.addressId,
    required this.lines,
    required this.paymentMethod,
    this.promoCode,
    String? idempotencyKey,
  }) : idempotencyKey = idempotencyKey ?? _newKey();

  final String sellerId;
  final String addressId;
  final List<OrderLineDto> lines;
  final String paymentMethod;
  final String? promoCode;

  /// Identifies this attempt so a replay is not a second order (10.4).
  /// Generated once per request object, so a retry of the *same* request
  /// reuses it while a genuinely new order gets a new one.
  final String idempotencyKey;

  static String _newKey() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}';

  Map<String, dynamic> toJson() => {
    'seller_id': sellerId,
    'address_id': addressId,
    'lines': lines.map((l) => l.toJson()).toList(),
    'payment_method': paymentMethod,
    if (promoCode != null) 'promo_code': promoCode,
  };
}

abstract interface class OrderRemoteDataSource {
  Future<List<OrderDto>> fetchOrders({String? status});
  Future<OrderDto> fetchOrder(String id);
  Future<OrderDto> placeOrder(PlaceOrderRequest request);
  Future<OrderDto> cancelOrder(String id, String reason);
  Future<void> rateOrder(
    String id, {
    required int stars,
    List<String> tags,
    String? comment,
  });
  Future<void> reportOrder(String id, {required String reason, String? note});
}

class OrderApiDataSource implements OrderRemoteDataSource {
  const OrderApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<OrderDto>> fetchOrders({String? status}) async {
    final items = await _client.getList(
      ApiEndpoints.orders,
      query: {if (status != null) 'status': status},
    );
    return items.map(OrderDto.fromJson).toList();
  }

  @override
  Future<OrderDto> fetchOrder(String id) async {
    final json = await _client.getObject(ApiEndpoints.order(id));
    return OrderDto.fromJson(json ?? const {});
  }

  @override
  Future<OrderDto> placeOrder(PlaceOrderRequest request) async {
    // A retried POST must not create a second order. The key is per attempt,
    // so a replay after a dropped response returns the ORIGINAL order rather
    // than charging the customer twice (API_SPEC 10.4).
    final json = await _client.postObject(
      ApiEndpoints.orders,
      body: request.toJson(),
      headers: {'Idempotency-Key': request.idempotencyKey},
    );
    return OrderDto.fromJson(json ?? const {});
  }

  @override
  Future<OrderDto> cancelOrder(String id, String reason) async {
    final json = await _client.postObject(
      ApiEndpoints.cancelOrder(id),
      body: {'reason': reason},
    );
    return OrderDto.fromJson(json ?? const {});
  }

  @override
  Future<void> rateOrder(
    String id, {
    required int stars,
    List<String> tags = const [],
    String? comment,
  }) => _client.post<void>(
    ApiEndpoints.rateOrder(id),
    body: {
      'stars': stars,
      'tags': tags,
      if (comment != null) 'comment': comment,
    },
  );

  @override
  Future<void> reportOrder(String id, {required String reason, String? note}) =>
      _client.post<void>(
        ApiEndpoints.reportOrder(id),
        body: {'reason': reason, if (note != null) 'note': note},
      );
}

/// Keeps orders in memory for the session so the whole flow — place, track,
/// rate, cancel — behaves like a real backend.
class MockOrderDataSource implements OrderRemoteDataSource {
  MockOrderDataSource()
    : _orders = [
        OrderDto.fromDomain(MockFixtures.activeOrder),
        ...MockFixtures.pastOrders.map(OrderDto.fromDomain),
      ];

  final List<OrderDto> _orders;
  int _nextReference = 2420;

  static const _latency = Duration(milliseconds: 400);

  @override
  Future<List<OrderDto>> fetchOrders({String? status}) async {
    await Future<void>.delayed(_latency);
    if (status == null) return List<OrderDto>.unmodifiable(_orders);
    return _orders.where((o) => o.status == status).toList();
  }

  @override
  Future<OrderDto> fetchOrder(String id) async {
    await Future<void>.delayed(_latency);
    final order = _orders.where((o) => o.id == id).firstOrNull;
    if (order == null) {
      throw const ServerFailure('That order no longer exists.');
    }
    return order;
  }

  @override
  Future<OrderDto> placeOrder(PlaceOrderRequest request) async {
    await Future<void>.delayed(_latency);

    final reference = 'SO-${_nextReference++}';
    final seller = MockFixtures.sellers
        .where((s) => s.id == request.sellerId)
        .firstOrNull;
    final address = MockFixtures.addresses
        .where((a) => a.id == request.addressId)
        .firstOrNull;

    final order = OrderDto.fromDomain(
      Order(
        id: 'o-$reference',
        reference: reference,
        sellerId: request.sellerId,
        sellerName: seller?.name ?? 'Chashma Pure Water',
        customerName: MockFixtures.customer.fullName,
        lines: request.lines.map((l) => l.toDomain()).toList(),
        address: address ?? MockFixtures.homeAddress,
        paymentMethod:
            PaymentMethod.values
                .where((p) => p.name == request.paymentMethod)
                .firstOrNull ??
            PaymentMethod.cash,
        status: OrderStatus.pending,
        placedAt: DateTime.now(),
        etaMinutes: seller?.etaMinutes ?? 25,
      ),
    );

    _orders.insert(0, order);
    return order;
  }

  @override
  Future<OrderDto> cancelOrder(String id, String reason) async {
    await Future<void>.delayed(_latency);
    final index = _orders.indexWhere((o) => o.id == id);
    if (index < 0) throw const ServerFailure('That order no longer exists.');

    final cancelled = OrderDto.fromDomain(
      _orders[index].toDomain().copyWith(
        status: OrderStatus.cancelledByCustomer,
        cancellationReason: reason,
      ),
    );
    _orders[index] = cancelled;
    return cancelled;
  }

  @override
  Future<void> rateOrder(
    String id, {
    required int stars,
    List<String> tags = const [],
    String? comment,
  }) async {
    await Future<void>.delayed(_latency);
    final index = _orders.indexWhere((o) => o.id == id);
    if (index >= 0) {
      _orders[index] = OrderDto.fromDomain(
        _orders[index].toDomain().copyWith(rating: stars),
      );
    }
  }

  @override
  Future<void> reportOrder(
    String id, {
    required String reason,
    String? note,
  }) async {
    await Future<void>.delayed(_latency);
  }
}
