import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/rider_run.dart';
import '../providers/rider_providers.dart';

/// What the rider earned, itemised, plus which days actually pay.
class RiderEarningsScreen extends ConsumerWidget {
  const RiderEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderEarningsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AppAvatar(name: user?.fullName ?? 'Rider', size: 34),
            const SizedBox(width: AppSpacing.sm),
            Text(
              user?.fullName ?? 'Your earnings',
              style: AppTypography.heading(size: 19),
            ),
          ],
        ),
      ),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 140),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(riderEarningsProvider),
        ),
        AsyncValue(value: final earnings) when earnings != null => _Body(
          earnings: earnings,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.earnings});

  final RiderEarnings earnings;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      0,
      AppSpacing.gutter,
      AppSpacing.xxl,
    ),
    children: [
      // ── The headline number ─────────────────────────────────────────────
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earned this week',
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.textMuted(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              Formatters.rupees(earnings.gross),
              style: AppTypography.heading(size: 38),
            ),
            const SizedBox(height: 4),
            Text(
              '${earnings.deliveries} deliveries · '
              '${Formatters.rupees(earnings.perDelivery)} each',
              style: AppTypography.body(
                size: 12.5,
                color: AppColors.textMuted(0.55),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Divider(),
            ),

            SummaryRow(
              label: '${earnings.deliveries} deliveries',
              value: Formatters.rupees(earnings.gross),
            ),
            SummaryRow(
              label: 'On-time bonus',
              value: '+ ${Formatters.rupees(earnings.onTimeBonus)}',
              valueColor: AppColors.accent2_700,
            ),
            if (earnings.fuelAdvance > 0)
              SummaryRow(
                label: 'Fuel advance taken',
                value: '− ${Formatters.rupees(earnings.fuelAdvance)}',
              ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(),
            ),
            SummaryRow(
              label: 'Due to you Monday',
              value: Formatters.rupees(earnings.netDue),
              isTotal: true,
            ),
          ],
        ),
      ),

      // ── Which days pay ──────────────────────────────────────────────────
      if (earnings.perDayDeliveries.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.xl),
        Text('Your days', style: AppTypography.heading(size: 20)),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              SizedBox(
                height: 128,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < earnings.perDayDeliveries.length; i++)
                      Expanded(
                        child: _DayBar(
                          label: _dayNames[i],
                          count: earnings.perDayDeliveries[i],
                          maxCount: earnings.perDayDeliveries.reduce(
                            (a, b) => a > b ? a : b,
                          ),
                          isBest: i == earnings.bestDayIndex,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${_dayNames[earnings.bestDayIndex]} mornings are your best — '
                '${earnings.perDayDeliveries[earnings.bestDayIndex]} stops.',
                style: AppTypography.body(
                  size: 12.5,
                  color: AppColors.textMuted(0.6),
                ),
              ),
            ],
          ),
        ),
      ],

      // ── Standing ────────────────────────────────────────────────────────
      const SizedBox(height: AppSpacing.md),
      AppCard(
        color: AppColors.accent2_100,
        child: Row(
          children: [
            const Icon(Icons.star_rounded, size: 26, color: Color(0xFFE8A33D)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${earnings.rating} from ${earnings.ratingCount} customers',
                    style: AppTypography.body(
                      size: 14.5,
                      weight: FontWeight.w800,
                      color: AppColors.accent2_700,
                    ),
                  ),
                  if (earnings.isTopRider)
                    Text(
                      'Top rider at Chashma this week',
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.accent2_700,
                      ),
                    ),
                ],
              ),
            ),
            if (earnings.isTopRider) const AppTag('Top', tone: TagTone.accent2),
          ],
        ),
      ),
    ],
  );
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.isBest,
  });

  final String label;
  final int count;
  final int maxCount;
  final bool isBest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: AppTypography.body(
            size: 11,
            weight: FontWeight.w700,
            color: isBest ? AppColors.accent : AppColors.textMuted(0.5),
          ),
        ),
        const SizedBox(height: 4),
        // Bars are scaled against the best day so the shape is readable.
        Container(
          height: maxCount == 0 ? 4 : (count / maxCount) * 78 + 4,
          decoration: BoxDecoration(
            color: isBest ? AppColors.accent : AppColors.accent200,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.body(
            size: 10.5,
            weight: isBest ? FontWeight.w700 : FontWeight.w500,
            color: isBest ? AppColors.accent : AppColors.textMuted(0.5),
          ),
        ),
      ],
    ),
  );
}
