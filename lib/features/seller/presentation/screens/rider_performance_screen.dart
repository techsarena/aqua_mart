import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';

/// How each rider is doing this week, and what the seller should do about it.
class RiderPerformanceScreen extends ConsumerWidget {
  const RiderPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerRidersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riders this week')),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 140),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(sellerRidersProvider),
        ),
        AsyncValue(value: final riders) when riders != null => _Body(
          riders: riders,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.riders});

  final List<Rider> riders;

  @override
  Widget build(BuildContext context) {
    final working = riders.where((r) => r.delivered > 0).toList()
      ..sort((a, b) => b.delivered.compareTo(a.delivered));

    final top = working.firstOrNull;
    final second = working.length > 1 ? working[1] : null;

    // Flags an imbalance worth acting on rather than leaving it in the numbers.
    final isLopsided =
        top != null && second != null && top.delivered > second.delivered * 1.6;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        for (final rider in riders) ...[
          _RiderCard(rider: rider, isTop: rider.id == top?.id),
          const SizedBox(height: AppSpacing.md),
        ],

        if (isLopsided) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: AppColors.accent100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${top.name.split(' ').first} is carrying the week',
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w800,
                    color: AppColors.accent800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "He's done nearly twice ${second.name.split(' ').first}'s "
                  'stops. Consider a bonus or a third rider.',
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.accent800,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Send an invite by phone number.'),
                    ),
                  ),
                  child: const Text('Invite a rider'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.isTop});

  final Rider rider;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final hasIssues = rider.lateDeliveries > 0 || rider.complaints > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: rider.name, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.name,
                      style: AppTypography.body(
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      rider.status == RiderStatus.offDuty
                          ? 'Off duty · 0 deliveries'
                          : rider.statusLine,
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.textMuted(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (isTop) const AppTag('Top rider', tone: TagTone.accent2),
            ],
          ),

          if (rider.delivered > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${rider.delivered}',
                    label: 'delivered',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '${rider.onTimePercent}%',
                    label: 'on time',
                    valueColor: rider.onTimePercent >= 90
                        ? AppColors.accent2_700
                        : AppColors.warning,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: rider.rating.toStringAsFixed(1),
                    label: 'rating',
                  ),
                ),
              ],
            ),
          ],

          if (hasIssues) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${[if (rider.lateDeliveries > 0) '${rider.lateDeliveries} late deliveries', if (rider.complaints > 0) '${rider.complaints} complaint'].join(' and ')} this week',
                      style: AppTypography.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
