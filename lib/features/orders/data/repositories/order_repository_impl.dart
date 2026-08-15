import '../../../../core/utils/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_line.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_data_source.dart';
import '../models/order_dto.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl(this._remote);

  final OrderRemoteDataSource _remote;

  @override
  Future<Result<List<Order>>> orders({OrderStatus? status}) =>
      Result.guard(() async {
        final dtos = await _remote.fetchOrders(status: status?.name);
        return dtos.map((d) => d.toDomain()).toList();
      });

  @override
  Future<Result<Order>> orderById(String id) =>
      Result.guard(() async => (await _remote.fetchOrder(id)).toDomain());

  @override
  Future<Result<Order>> place({
    required String sellerId,
    required String addressId,
    required List<OrderLine> lines,
    required PaymentMethod paymentMethod,
    String? promoCode,
  }) => Result.guard(() async {
    final dto = await _remote.placeOrder(
      PlaceOrderRequest(
        sellerId: sellerId,
        addressId: addressId,
        lines: lines.map(OrderLineDto.fromDomain).toList(),
        paymentMethod: paymentMethod.name,
        promoCode: promoCode,
      ),
    );
    return dto.toDomain();
  });

  @override
  Future<Result<Order>> cancel(String id, String reason) => Result.guard(
    () async => (await _remote.cancelOrder(id, reason)).toDomain(),
  );

  @override
  Future<Result<void>> rate(
    String id, {
    required int stars,
    List<String> tags = const [],
    String? comment,
  }) => Result.guard(
    () => _remote.rateOrder(id, stars: stars, tags: tags, comment: comment),
  );

  @override
  Future<Result<void>> report(
    String id, {
    required String reason,
    String? note,
  }) => Result.guard(() => _remote.reportOrder(id, reason: reason, note: note));
}
