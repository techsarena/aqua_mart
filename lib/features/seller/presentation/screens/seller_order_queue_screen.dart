import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../notifications/presentation/widgets/alerts_bell_button.dart';
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
          title: Text('Orders', style: AppTypography.heading(size: 30)),
          toolbarHeight: 68,
          actions: const [
            AlertsBellButton(routeName: AppRoutes.sellerAlerts),
            SizedBox(width: AppSpacing.gutter),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _BucketTabs(
              labels: [
                for (final name in names) '$name · ${buckets[name]!.length}',
              ],
            ),
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

/// The bucket switcher: filled pills on a scroll track, not an underlined
/// [TabBar]. Drives the ambient [TabController], so tapping a pill and swiping
/// the pages stay in step.
class _BucketTabs extends StatefulWidget {
  const _BucketTabs({required this.labels});

  final List<String> labels;

  @override
  State<_BucketTabs> createState() => _BucketTabsState();
}

class _BucketTabsState extends State<_BucketTabs> {
  final _scroll = ScrollController();
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller == _controller) return;
    _controller?.removeListener(_onTabChanged);
    _controller = controller..addListener(_onTabChanged);
  }

  // `animation` also fires mid-swipe, but index is what the pills paint from,
  // so repainting on the settled index is enough.
  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _controller?.removeListener(_onTabChanged);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _controller?.index ?? 0;

    return SizedBox(
      height: 60,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
        itemCount: widget.labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final isSelected = i == selected;
          return Center(
            child: Material(
              color: isSelected ? AppColors.accent : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                onTap: () => _controller?.animateTo(i),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    widget.labels[i],
                    style: AppTypography.body(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textMuted(0.75),
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          );
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
