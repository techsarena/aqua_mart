import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../catalog/data/models/bottle_dto.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_status.dart';
import '../../data/datasources/seller_data_source.dart';
import '../../domain/entities/seller_dashboard.dart';

final sellerDataSourceProvider = Provider<SellerRemoteDataSource>((ref) {
  if (useMockData) return MockSellerDataSource();
  return SellerApiDataSource(ref.watch(apiClientProvider));
});

class SellerDashboardNotifier extends AsyncNotifier<SellerDashboard> {
  @override
  Future<SellerDashboard> build() =>
      ref.watch(sellerDataSourceProvider).fetchDashboard();

  /// "Taking orders" / "Closed for now" — hides the seller without deleting.
  Future<void> toggleOpen() async {
    final current = state.value;
    if (current == null) return;

    final next = !current.isOpen;
    // Optimistic: the switch should not lag behind the thumb.
    state = AsyncData(current.copyWith(isOpen: next));
    await ref.read(sellerDataSourceProvider).setOpen(isOpen: next);
  }
}

final sellerDashboardProvider =
    AsyncNotifierProvider<SellerDashboardNotifier, SellerDashboard>(
      SellerDashboardNotifier.new,
    );

/// The seller's live order queue.
class SellerQueueNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final dtos = await ref.watch(sellerDataSourceProvider).fetchQueue();
    return dtos.map((d) => d.toDomain()).toList();
  }

  /// Accept → Packed → Sent → Done, one tap at a time.
  Future<void> advance(String orderId) async {
    await ref.read(sellerDataSourceProvider).advanceOrder(orderId);
    ref.invalidateSelf();
    ref.invalidate(sellerDashboardProvider);
  }

  Future<void> decline(String orderId, String reason) async {
    await ref.read(sellerDataSourceProvider).declineOrder(orderId, reason);
    ref.invalidateSelf();
    ref.invalidate(sellerDashboardProvider);
  }

  Future<void> assignRider({
    required String orderId,
    required String riderId,
  }) async {
    await ref
        .read(sellerDataSourceProvider)
        .assignRider(orderId: orderId, riderId: riderId);
    ref.invalidateSelf();
  }
}

final sellerQueueProvider =
    AsyncNotifierProvider<SellerQueueNotifier, List<Order>>(
      SellerQueueNotifier.new,
    );

/// Queue grouped into the four buckets the seller's Orders tab shows.
final sellerQueueBucketsProvider = Provider<Map<String, List<Order>>>((ref) {
  final orders = ref.watch(sellerQueueProvider).value ?? const [];
  final buckets = <String, List<Order>>{
    'New': [],
    'Packing': [],
    'On route': [],
    'Done': [],
  };
  for (final order in orders) {
    buckets[order.status.sellerBucket]?.add(order);
  }
  return buckets;
});

/// Orders needing a decision right now — what Today leads with.
final pendingOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(sellerQueueProvider).value ?? const [];
  return orders.where((o) => o.status == OrderStatus.pending).toList();
});

class SellerInventoryNotifier extends AsyncNotifier<List<Bottle>> {
  @override
  Future<List<Bottle>> build() async {
    final dtos = await ref.watch(sellerDataSourceProvider).fetchInventory();
    return dtos.map((d) => d.toDomain()).toList();
  }

  Future<Result<void>> save(Bottle bottle) async {
    final result = await Result.guard(
      () => ref
          .read(sellerDataSourceProvider)
          .saveBottle(BottleDto.fromDomain(bottle)),
    );
    if (result.isSuccess) {
      ref.invalidateSelf();
      ref.invalidate(sellerDashboardProvider);
    }
    return result;
  }

  Future<Result<void>> delete(String bottleId) async {
    final result = await Result.guard(
      () => ref.read(sellerDataSourceProvider).deleteBottle(bottleId),
    );
    if (result.isSuccess) {
      ref.invalidateSelf();
      ref.invalidate(sellerDashboardProvider);
    }
    return result;
  }
}

final sellerInventoryProvider =
    AsyncNotifierProvider<SellerInventoryNotifier, List<Bottle>>(
      SellerInventoryNotifier.new,
    );

final bottleByIdProvider = Provider.family<Bottle?, String>((ref, id) {
  final bottles = ref.watch(sellerInventoryProvider).value ?? const [];
  return bottles.where((b) => b.id == id).firstOrNull;
});

final sellerRidersProvider = FutureProvider<List<Rider>>(
  (ref) => ref.watch(sellerDataSourceProvider).fetchRiders(),
);

final sellerPayoutsProvider = FutureProvider<List<Payout>>(
  (ref) => ref.watch(sellerDataSourceProvider).fetchPayouts(),
);

final disputeProvider = FutureProvider.family<Dispute, String>(
  (ref, id) => ref.watch(sellerDataSourceProvider).fetchDispute(id),
);
