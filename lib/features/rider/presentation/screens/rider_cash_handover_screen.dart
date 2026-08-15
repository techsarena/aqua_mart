import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../domain/entities/rider_run.dart';
import '../providers/rider_providers.dart';

/// Handing the day's cash back to the seller.
///
/// The rider confirms the amount; the seller has to accept it too, which the
/// screen says plainly so the handover is not one-sided.
class RiderCashHandoverScreen extends ConsumerWidget {
  const RiderCashHandoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderRunProvider);

    return switch (async) {
      AsyncLoading() => Scaffold(
        appBar: AppBar(title: const Text('Hand in the cash')),
        body: const SkeletonList(itemCount: 3, itemHeight: 120),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Hand in the cash')),
        body: ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(riderRunProvider),
        ),
      ),
      AsyncValue(value: final run) when run != null => _HandoverView(run: run),
      _ => const SizedBox.shrink(),
    };
  }
}

class _HandoverView extends ConsumerWidget {
  const _HandoverView({required this.run});

  final RiderRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = run.cashCollected;
    final failed = run.failed;

    return Scaffold(
      appBar: AppBar(title: const Text('Hand in the cash')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            run.finishedAt != null
                ? '${run.label} · finished ${Formatters.time(run.finishedAt!)}'
                : '${run.label} · in progress',
            style: AppTypography.body(
              size: 13,
              color: AppColors.textMuted(0.6),
            ),
          ),

          // ── The amount ──────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cash you're holding",
                  style: AppTypography.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.textMuted(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.rupees(cash),
                  style: AppTypography.heading(size: 40),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(),
                ),

                SummaryRow(
                  label: '${run.cashOrderCount} cash orders',
                  value: Formatters.rupees(cash),
                ),
                SummaryRow(
                  label: '${run.prepaidCount} wallet / JazzCash',
                  value: 'already paid',
                ),
                if (run.khataCount > 0)
                  SummaryRow(
                    label: '${run.khataCount} khata',
                    value: 'on account',
                  ),
              ],
            ),
          ),

          // ── What else goes back ─────────────────────────────────────────
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Also going back to the plant',
                  style: AppTypography.body(
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${run.emptiesCollected}',
                        label: 'empties collected',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${failed.length}',
                        label: 'undelivered bottles',
                        valueColor: failed.isEmpty
                            ? null
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Anything that went wrong ────────────────────────────────────
          if (failed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final stop in failed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  color: AppColors.warningBg,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 19,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stop not completed',
                              style: AppTypography.body(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                            Text(
                              '${stop.customerName} · ${stop.address} · '
                              '${Formatters.rupees(stop.amountToCollect)}',
                              style: AppTypography.body(
                                size: 12,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // ── How the run went ────────────────────────────────────────────
          if (run.delivered.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppNote.positive(
              icon: Icons.check_circle_outline_rounded,
              text:
                  '${run.delivered.length} delivered'
                  '${run.delivered.first.completedAt != null ? ' · first ${Formatters.time(run.delivered.first.completedAt!)}' : ''}'
                  '${run.delivered.last.completedAt != null ? ' · last ${Formatters.time(run.delivered.last.completedAt!)}' : ''}',
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          const AppNote(
            icon: Icons.receipt_long_outlined,
            text:
                'Your seller gets a receipt the moment you confirm. They have '
                'to accept it too.',
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: 'I handed over ${Formatters.rupees(cash)}',
        enabled: cash > 0,
        onPressed: () async {
          final result = await ref
              .read(riderRunProvider.notifier)
              .handOverCash(cash);
          if (!context.mounted) return;

          result.when(
            success: (_) => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipt sent — waiting for the seller.'),
              ),
            ),
            failure: (f) => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(f.message))),
          );
        },
        secondaryLabel: 'The amount is different',
        onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tell your seller what you actually collected.'),
          ),
        ),
      ),
    );
  }
}
