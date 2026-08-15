import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/order_data_source.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/repositories/order_repository.dart';
import 'cart_providers.dart';

final orderDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  if (useMockData) return MockOrderDataSource();
  return OrderApiDataSource(ref.watch(apiClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepositoryImpl(ref.watch(orderDataSourceProvider)),
);

/// Every order this customer has, newest first.
class OrderListNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final result = await ref.watch(orderRepositoryProvider).orders();
    return result.when(success: (orders) => orders, failure: (f) => throw f);
  }

  /// Places the cart as an order and clears it on success.
  Future<Result<Order>> placeFromCart() async {
    final cart = ref.read(cartProvider);
    final sellerId = cart.sellerId;
    final addressId = cart.address?.id;

    if (sellerId == null || addressId == null) {
      return const Result.failure(
        ValidationFailure('Choose a seller and a delivery address first.'),
      );
    }

    final result = await ref
        .read(orderRepositoryProvider)
        .place(
          sellerId: sellerId,
          addressId: addressId,
          lines: cart.orderedLines,
          paymentMethod: cart.paymentMethod,
          promoCode: cart.promoCode,
        );

    if (result.isSuccess) {
      ref.read(cartProvider.notifier).clear();
      ref.invalidateSelf();
    }
    return result;
  }

  Future<Result<Order>> cancel(String id, String reason) async {
    final result = await ref.read(orderRepositoryProvider).cancel(id, reason);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> rate(
    String id, {
    required int stars,
    List<String> tags = const [],
    String? comment,
  }) async {
    final result = await ref
        .read(orderRepositoryProvider)
        .rate(id, stars: stars, tags: tags, comment: comment);
    if (result.isSuccess) ref.invalidateSelf();
    return result;
  }

  Future<Result<void>> report(
    String id, {
    required String reason,
    String? note,
  }) => ref.read(orderRepositoryProvider).report(id, reason: reason, note: note);
}

final orderListProvider = AsyncNotifierProvider<OrderListNotifier, List<Order>>(
  OrderListNotifier.new,
);

/// The order currently in flight — what the Track tab shows.
final activeOrderProvider = Provider<Order?>((ref) {
  final orders = ref.watch(orderListProvider).value ?? const [];
  return orders.where((o) => o.status.isActive).firstOrNull;
});

/// The most recent delivered order, used to seed "Your usual".
final usualOrderProvider = Provider<Order?>((ref) {
  final orders = ref.watch(orderListProvider).value ?? const [];
  return orders
      .where((o) => o.status == OrderStatus.delivered)
      .firstOrNull;
});

/// Past orders, for the history list.
final pastOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(orderListProvider).value ?? const [];
  return orders.where((o) => o.status.isTerminal).toList();
});

final orderByIdProvider = FutureProvider.family<Order, String>((
  ref,
  id,
) async {
  final result = await ref.watch(orderRepositoryProvider).orderById(id);
  return result.when(success: (o) => o, failure: (f) => throw f);
});
