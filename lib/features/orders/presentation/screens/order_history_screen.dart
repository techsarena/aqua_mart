import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/cart_providers.dart';
import '../providers/order_providers.dart';

/// "Your orders — tap any past order to send it again."
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap any past order to send it again.',
                style: AppTypography.body(
                  size: 15,
                  color: AppColors.textMuted(0.55),
                ),
              ),
            ),
          ),
        ),
      ),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 4, itemHeight: 92),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(orderListProvider),
        ),
        AsyncValue(value: final orders) =>
          (orders?.isEmpty ?? true)
              ? Center(
                  child: EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message: 'Your first order will show up here.',
                    primaryLabel: 'Order water',
                    onPrimary: () => context.goNamed(AppRoutes.customerHome),
                  ),
                )
              : OrderHistoryBody(
                  orders: orders!,
                  onRefresh: () async => ref.invalidate(orderListProvider),
                ),
      },
    );
  }
}

/// The loaded list — the active order on top, then the history, then the nudge.
///
/// Split out from the async plumbing above so the layout can be rendered on
/// its own with fixture data.
class OrderHistoryBody extends StatelessWidget {
  const OrderHistoryBody({
    super.key,
    required this.orders,
    required this.onRefresh,
  });

  final List<Order> orders;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        for (final order in orders) ...[
          if (order.status.isActive)
            _ActiveOrderCard(order: order)
          else
            _PastOrderTile(order: order),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        const _ReorderNudge(),
      ],
    ),
  );
}

/// The order in flight, called out above the history: a tinted, outlined panel
/// with the status as a small-caps label and the ETA on the same line.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.accent100,
    borderColor: AppColors.accent300,
    onTap: () => context.pushNamed(
      AppRoutes.orderTracking,
      pathParameters: {'orderId': order.id},
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                order.status.customerLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 12,
                  weight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.accent700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${order.etaMinutes} min',
              style: AppTypography.body(
                size: 13.5,
                weight: FontWeight.w800,
                color: AppColors.accent700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${order.itemsSummary} · ${Formatters.rupees(order.total)}',
          style: AppTypography.body(size: 16.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          '${order.sellerName} · ${order.paymentMethod.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body(
            size: 13.5,
            color: AppColors.textMuted(0.6),
          ),
        ),
      ],
    ),
  );
}

/// A settled order — title and meta on the left, "Reorder" pill on the right.
class _PastOrderTile extends ConsumerWidget {
  const _PastOrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDelivered = order.status == OrderStatus.delivered;

    return AppCard(
      onTap: () => context.pushNamed(
        AppRoutes.orderTracking,
        pathParameters: {'orderId': order.id},
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.itemsSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.shortDate(order.placedAt)} · '
                  '${Formatters.rupees(order.total)} · '
                  '${_shortSellerName(order.sellerName)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13.5,
                    color: AppColors.textMuted(0.6),
                  ),
                ),
                // A rejected or cancelled order still reorders, but say so.
                if (!isDelivered) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTag(order.status.customerLabel, tone: TagTone.danger),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton(
            onPressed: () {
              ref
                  .read(cartProvider.notifier)
                  .loadLines(
                    sellerId: order.sellerId,
                    sellerName: order.sellerName,
                    lines: order.lines,
                  );
              context.pushNamed(AppRoutes.cart);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }
}

/// `Chashma Pure Water` → `Chashma`. The meta row is tight, and the design
/// drops the generic trade words rather than truncating mid-name.
String _shortSellerName(String name) {
  const generic = {'pure', 'water', 'supply', 'supplies', 'company', 'co'};
  final kept = name
      .split(RegExp(r'\s+'))
      .takeWhile((word) => !generic.contains(word.toLowerCase()))
      .join(' ');
  return kept.isEmpty ? name : kept;
}

/// "You order every 7 days — want us to remind you next Tuesday morning?"
class _ReorderNudge extends StatelessWidget {
  const _ReorderNudge();

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.accent2_100,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You order every 7 days',
          style: AppTypography.heading(size: 21, color: AppColors.text),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Want us to remind you next Tuesday morning?',
          style: AppTypography.body(
            size: 14.5,
            color: AppColors.textMuted(0.7),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("We'll remind you on Tuesday.")),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent2,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            ),
            child: const Text('Yes, remind me'),
          ),
        ),
      ],
    ),
  );
}
