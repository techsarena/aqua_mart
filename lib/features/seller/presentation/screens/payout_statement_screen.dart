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
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';

/// The weekly statement, itemised so every deduction is accounted for.
class PayoutStatementScreen extends ConsumerWidget {
  const PayoutStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerPayoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 2, itemHeight: 200),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(sellerPayoutsProvider),
        ),
        AsyncValue(value: final payouts)
            when payouts != null && payouts.isNotEmpty =>
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            children: [
              _StatementCard(payout: payouts.first),
              if (payouts.length > 1) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Earlier weeks', style: AppTypography.heading(size: 20)),
                const SizedBox(height: AppSpacing.md),
                for (final payout in payouts.skip(1)) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payout.weekLabel,
                                style: AppTypography.body(
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${payout.ordersDelivered} orders',
                                style: AppTypography.body(
                                  size: 12.5,
                                  color: AppColors.textMuted(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.rupees(payout.netPaid),
                          style: AppTypography.body(
                            size: 15,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          ),
        _ => const Center(
          child: EmptyView(
            icon: Icons.payments_outlined,
            title: 'No payouts yet',
            message: 'Your first weekly payout lands next Monday.',
          ),
        ),
      },
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Payout · ${payout.weekLabel}',
                style: AppTypography.heading(size: 20),
              ),
            ),
            if (payout.isPaid)
              AppTag(
                payout.paidAt != null
                    ? 'Paid · ${Formatters.shortDate(payout.paidAt!)}'
                    : 'Paid',
                tone: TagTone.accent2,
                icon: Icons.check_rounded,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          Formatters.rupees(payout.netPaid),
          style: AppTypography.heading(size: 36),
        ),
        if (payout.bankLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            '${payout.bankLabel}'
            '${payout.reference != null ? ' · ref ${payout.reference}' : ''}',
            style: AppTypography.body(
              size: 12.5,
              color: AppColors.textMuted(0.55),
            ),
          ),
        ],

        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Divider(),
        ),

        // The itemised trail from gross sales to what actually transferred.
        SummaryRow(
          label: '${payout.ordersDelivered} orders delivered',
          value: Formatters.rupees(payout.grossSales),
        ),
        SummaryRow(
          label: 'Bottle deposits taken',
          value: Formatters.rupees(payout.depositsTaken),
        ),
        SummaryRow(
          label: 'Deposits refunded',
          value: '− ${Formatters.rupees(payout.depositsRefunded)}',
        ),
        SummaryRow(
          label: 'Aqua Mart commission · 8%',
          value: '− ${Formatters.rupees(payout.commission)}',
        ),
        if (payout.complaintRefunds > 0)
          SummaryRow(
            label: 'Complaint refund',
            value: '− ${Formatters.rupees(payout.complaintRefunds)}',
          ),
        SummaryRow(
          label: 'Cash collected by riders',
          value: '− ${Formatters.rupees(payout.cashCollectedByRiders)}',
        ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Divider(),
        ),
        SummaryRow(
          label: 'Paid to you',
          value: Formatters.rupees(payout.netPaid),
          isTotal: true,
        ),

        const SizedBox(height: AppSpacing.md),
        const AppNote(
          icon: Icons.info_outline_rounded,
          text:
              "Cash your riders collected is already yours — that's why it's "
              'deducted here.',
        ),
      ],
    ),
  );
}
