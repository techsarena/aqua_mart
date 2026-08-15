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
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap any past order to send it again.',
                style: AppTypography.body(
                  size: 12.5,
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
        AsyncValue(value: final orders) => (orders?.isEmpty ?? true)
            ? Center(
                child: EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message: 'Your first order will show up here.',
                  primaryLabel: 'Order water',
                  onPrimary: () => context.goNamed(AppRoutes.customerHome),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(orderListProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.xxl,
                  ),
                  children: [
                    for (final order in orders!) ...[
                      _OrderTile(order: order),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    const _ReorderNudge(),
                  ],
                ),
              ),
      },
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = order.status.isActive;

    return AppCard(
      onTap: () => context.pushNamed(
        AppRoutes.orderTracking,
        pathParameters: {'orderId': order.id},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isActive)
                AppTag(
                  order.status == OrderStatus.onTheWay
                      ? 'On the way'
                      : order.status.customerLabel,
                  tone: TagTone.accent,
                  icon: Icons.local_shipping_rounded,
                )
              else
                AppTag(
                  order.status == OrderStatus.delivered
                      ? Formatters.shortDate(order.placedAt)
                      : order.status.customerLabel,
                  tone: order.status == OrderStatus.delivered
                      ? TagTone.neutral
                      : TagTone.danger,
                ),
              const Spacer(),
              if (isActive)
                Text(
                  '${order.etaMinutes} min',
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            order.itemsSummary,
            style: AppTypography.body(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${order.sellerName} · ${Formatters.rupees(order.total)} · '
            '${order.paymentMethod.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 12.5,
              color: AppColors.textMuted(0.6),
            ),
          ),
          if (!isActive) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
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
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: const Text('Reorder'),
                  ),
                ),
                if (order.status == OrderStatus.delivered &&
                    order.rating == null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.pushNamed(
                        AppRoutes.rateOrder,
                        pathParameters: {'orderId': order.id},
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                      child: const Text('Rate'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "You order every 7 days — want us to remind you next Tuesday morning?"
class _ReorderNudge extends StatelessWidget {
  const _ReorderNudge();

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.accent2_100,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.event_repeat_rounded,
              size: 19,
              color: AppColors.accent2_700,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'You order every 7 days',
              style: AppTypography.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.accent2_700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Want us to remind you next Tuesday morning?',
          style: AppTypography.body(
            size: 13,
            color: AppColors.accent2_700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("We'll remind you on Tuesday.")),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent2,
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('Yes, remind me'),
        ),
      ],
    ),
  );
}
