import '../../../../core/utils/result.dart';
import '../entities/order.dart';
import '../entities/order_line.dart';
import '../entities/order_status.dart';

abstract interface class OrderRepository {
  Future<Result<List<Order>>> orders({OrderStatus? status});

  Future<Result<Order>> orderById(String id);

  Future<Result<Order>> place({
    required String sellerId,
    required String addressId,
    required List<OrderLine> lines,
    required PaymentMethod paymentMethod,
    String? promoCode,
  });

  Future<Result<Order>> cancel(String id, String reason);

  Future<Result<void>> rate(
    String id, {
    required int stars,
    List<String> tags,
    String? comment,
  });

  Future<Result<void>> report(
    String id, {
    required String reason,
    String? note,
  });
}
