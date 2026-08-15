import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../orders/domain/entities/order.dart';
import '../providers/seller_providers.dart';
import '../widgets/order_queue_card.dart';

/// The full queue, split into New · Packing · On route · Done.
class SellerOrderQueueScreen extends ConsumerWidget {
  const SellerOrderQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerQueueProvider);
    final buckets = ref.watch(sellerQueueBucketsProvider);
    final names = buckets.keys.toList();

    return DefaultTabController(
      length: names.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted(0.55),
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.divider,
            labelStyle: AppTypography.body(size: 13.5, weight: FontWeight.w700),
            tabs: [
              for (final name in names)
                Tab(text: '$name · ${buckets[name]!.length}'),
            ],
          ),
        ),
        body: switch (async) {
          AsyncLoading() => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: SkeletonList(itemCount: 4, itemHeight: 118),
          ),
          AsyncError(:final error) => ErrorView(
            failure: asFailure(error),
            onRetry: () => ref.invalidate(sellerQueueProvider),
          ),
          AsyncValue() => TabBarView(
            children: [
              for (final name in names)
                _Bucket(name: name, orders: buckets[name]!),
            ],
          ),
        },
      ),
    );
  }
}

class _Bucket extends ConsumerWidget {
  const _Bucket({required this.name, required this.orders});

  final String name;
  final List<Order> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(
        child: EmptyView(
          icon: Icons.inbox_rounded,
          title: 'Nothing in $name',
          message: name == 'New'
              ? 'New orders will land here the moment they come in.'
              : 'Orders move here as you work through them.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sellerQueueProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final order = orders[i];
          return OrderQueueCard(
            order: order,
            showDecline: name == 'New',
            onAdvance: () =>
                ref.read(sellerQueueProvider.notifier).advance(order.id),
            onDecline: () => ref
                .read(sellerQueueProvider.notifier)
                .decline(order.id, 'Out of stock'),
          );
        },
      ),
    );
  }
}
