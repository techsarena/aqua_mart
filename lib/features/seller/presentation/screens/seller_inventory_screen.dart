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
import '../../../catalog/domain/entities/bottle.dart';
import '../providers/seller_providers.dart';

/// The seller's bottles: what they charge and what is on the shelf.
class SellerInventoryScreen extends ConsumerWidget {
  const SellerInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerInventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bottles'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
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
                'Tap a bottle to change its price. Stock syncs with your ERP.',
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
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 128),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(sellerInventoryProvider),
        ),
        AsyncValue(value: final bottles) => (bottles?.isEmpty ?? true)
            ? const Center(
                child: EmptyView(
                  icon: Icons.water_drop_outlined,
                  title: 'No bottles listed',
                  message: 'Add the sizes you sell so customers can order.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                itemCount: bottles!.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _InventoryCard(
                  bottle: bottles[i],
                  onTap: () => context.pushNamed(
                    AppRoutes.sellerEditBottle,
                    pathParameters: {'bottleId': bottles[i].id},
                  ),
                  onHide: () => ref
                      .read(sellerInventoryProvider.notifier)
                      .save(bottles[i].copyWith(isVisible: false)),
                ),
              ),
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.bottle,
    required this.onTap,
    required this.onHide,
  });

  final Bottle bottle;
  final VoidCallback onTap;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                bottle.size.label,
                style: AppTypography.body(
                  size: 12.5,
                  weight: FontWeight.w800,
                  color: AppColors.accent700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bottle.name,
                          style: AppTypography.body(
                            size: 14.5,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!bottle.isVisible) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const AppTag('Hidden', tone: TagTone.neutral),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bottle.isLowStock
                        ? 'Only ${bottle.filledStock} left — customers still '
                              'see it'
                        : '${bottle.filledStock} filled'
                              '${bottle.emptiesInYard > 0 ? ' · ${bottle.emptiesInYard} empties in yard' : ''}',
                    style: AppTypography.body(
                      size: 12.5,
                      color: bottle.isLowStock
                          ? AppColors.warning
                          : AppColors.textMuted(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _PriceChip(
                label: 'Refill price',
                value: Formatters.rupees(bottle.refillPrice),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PriceChip(
                label: 'New bottle',
                value: Formatters.rupees(bottle.newPrice),
              ),
            ),
          ],
        ),

        // Low stock offers the two useful actions inline.
        if (bottle.isLowStock) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: const Text('Add stock'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onHide,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: const Text('Hide for now'),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body(
            size: 11,
            weight: FontWeight.w600,
            color: AppColors.textMuted(0.55),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: AppTypography.body(size: 15, weight: FontWeight.w800),
        ),
      ],
    ),
  );
}
