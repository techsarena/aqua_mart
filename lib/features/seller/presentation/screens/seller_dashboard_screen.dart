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
import '../../../notifications/presentation/widgets/alerts_bell_button.dart';
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';
import '../widgets/order_queue_card.dart';

/// The seller's Today: are you open, what needs you now, how the day is going.
class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerDashboardProvider);
    final pending = ref.watch(pendingOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.longDate(DateTime.now()),
              style: AppTypography.body(
                size: 11.5,
                weight: FontWeight.w600,
                color: AppColors.textMuted(0.55),
              ),
            ),
            // The seller's own store name. Blank until the dashboard lands,
            // so the bar keeps its height instead of showing a placeholder
            // name that is not theirs.
            Text(
              async.value?.businessName ?? '',
              style: AppTypography.heading(size: 19),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: const [
          AlertsBellButton(routeName: AppRoutes.sellerAlerts),
          SizedBox(width: AppSpacing.gutter),
        ],
      ),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 4, itemHeight: 96),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(sellerDashboardProvider),
        ),
        AsyncValue(value: final dashboard) when dashboard != null =>
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sellerDashboardProvider);
              ref.invalidate(sellerQueueProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                // ── ERP sync, made visible ──────────────────────────────
                if (!dashboard.sync.isOnline || dashboard.sync.hasBacklog) ...[
                  _OfflineBanner(sync: dashboard.sync),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Open / closed ───────────────────────────────────────
                _OpenToggle(
                  isOpen: dashboard.isOpen,
                  onToggle: () =>
                      ref.read(sellerDashboardProvider.notifier).toggleOpen(),
                ),

                // ── The day's numbers ───────────────────────────────────
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '${dashboard.ordersToday}',
                          label: 'orders today',
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          value: '${dashboard.delivered}',
                          label: 'delivered',
                          valueColor: AppColors.accent2_700,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          prefix: 'Rs',
                          value: Formatters.rupeesCompact(dashboard.earned),
                          label: 'earned',
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Needs you now ───────────────────────────────────────
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Text(
                        'Needs you now',
                        style: AppTypography.heading(size: 20),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            context.goNamed(AppRoutes.sellerOrderQueue),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                        ),
                        child: Text('See all ${pending.length}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final order in pending.take(2)) ...[
                    OrderQueueCard(
                      order: order,
                      showDecline: true,
                      onAdvance: () => ref
                          .read(sellerQueueProvider.notifier)
                          .advance(order.id),
                      onDecline: () => _confirmDecline(context, ref, order.id),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],

                // ── Stock warning ───────────────────────────────────────
                if (dashboard.lowStockLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    color: AppColors.warningBg,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            dashboard.lowStockLabel!,
                            style: AppTypography.body(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.goNamed(AppRoutes.sellerInventory),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Fix'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Future<void> _confirmDecline(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    const reasons = [
      'Out of stock',
      'Too far to deliver',
      'Closing for the day',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('Why decline?', style: AppTypography.heading(size: 20)),
            const SizedBox(height: AppSpacing.sm),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (reason != null) {
      await ref.read(sellerQueueProvider.notifier).decline(orderId, reason);
    }
  }
}

/// "3 orders waiting to sync — they'll upload when signal returns"
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.sync});

  final ErpSyncState sync;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.warningBg,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.warning),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            sync.pendingUploads > 0
                ? "${sync.pendingUploads} orders waiting to sync — they'll "
                      'upload when signal returns'
                : 'Working offline — changes upload when signal returns',
            style: AppTypography.body(
              size: 12.5,
              weight: FontWeight.w600,
              color: AppColors.warning,
              height: 1.4,
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: AppColors.warning,
            minimumSize: Size.zero,
          ),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _OpenToggle extends StatelessWidget {
  const _OpenToggle({required this.isOpen, required this.onToggle});

  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => AppCard(
    color: isOpen ? AppColors.accent2_100 : AppColors.neutral200,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOpen ? 'Taking orders' : 'Closed for now',
                style: AppTypography.heading(
                  size: 19,
                  color: isOpen ? AppColors.accent2_700 : AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOpen
                    ? 'Customers can order from you'
                    : 'You are hidden from the app',
                style: AppTypography.body(
                  size: 12.5,
                  color: isOpen
                      ? AppColors.accent2_700
                      : AppColors.textMuted(0.6),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: isOpen, onChanged: (_) => onToggle()),
      ],
    ),
  );
}
