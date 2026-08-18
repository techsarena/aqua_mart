import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
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
