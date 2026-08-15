import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../orders/presentation/providers/cart_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../providers/wallet_providers.dart';

/// Both endings of the top-up. Success offers to spend the money right away;
/// failure explains what happened and keeps the customer moving.
class TopUpResultScreen extends ConsumerWidget {
  const TopUpResultScreen({
    super.key,
    required this.amount,
    required this.succeeded,
  });

  final int amount;
  final bool succeeded;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      succeeded ? _success(context, ref) : _failure(context);

  Widget _success(BuildContext context, WidgetRef ref) {
    final bonus = amount >= 1000 ? 60 : 0;
    final balance = ref.watch(walletProvider).value?.balance ?? amount + bonus;
    final usual = ref.watch(usualOrderProvider);

    // Roughly how many refills the new balance covers.
    final refillsCovered = balance ~/ 110;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent2_100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppColors.accent2_700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${Formatters.rupees(amount + bonus)} added',
            style: AppTypography.heading(size: 28),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            bonus > 0
                ? '${Formatters.rupees(amount)} top-up plus your '
                      '${Formatters.rupees(bonus)} bonus.'
                : 'Your wallet has been topped up.',
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.65),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                SummaryRow(
                  label: 'New balance',
                  value: Formatters.rupees(balance),
                  isTotal: true,
                ),
                const SummaryRow(
                  label: 'JazzCash ref',
                  value: 'JC-84120397',
                ),
                SummaryRow(
                  label: 'Time',
                  value: 'Today, ${Formatters.time(DateTime.now())}',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppNote.positive(
            icon: Icons.water_drop_outlined,
            text: 'Enough for $refillsCovered refills.',
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: usual != null
            ? 'Order ${usual.itemsSummary}'
            : 'Order water now',
        onPressed: () {
          if (usual != null) {
            ref
                .read(cartProvider.notifier)
                .loadLines(
                  sellerId: usual.sellerId,
                  sellerName: usual.sellerName,
                  lines: usual.lines,
                );
            context.goNamed(AppRoutes.cart);
          } else {
            context.goNamed(AppRoutes.customerHome);
          }
        },
        secondaryLabel: 'Back to wallet',
        onSecondary: () => context.goNamed(AppRoutes.wallet),
      ),
    );
  }

  Widget _failure(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.dangerBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 34,
            color: AppColors.danger,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          "Top-up didn't go through",
          style: AppTypography.heading(size: 28),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'JazzCash said the request timed out.',
          style: AppTypography.body(
            size: 14,
            color: AppColors.textMuted(0.65),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppNote.positive(
          text: '',
          richText: const TextSpan(
            children: [
              TextSpan(
                text: 'Nothing was deducted',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' — your balance is unchanged.'),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        Text(
          'Common reasons',
          style: AppTypography.body(size: 14, weight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final reason in const [
          "The request wasn't approved in time",
          'Not enough balance in JazzCash',
          'Weak signal while confirming',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '· ',
                  style: AppTypography.body(
                    size: 13.5,
                    color: AppColors.textMuted(0.5),
                  ),
                ),
                Expanded(
                  child: Text(
                    reason,
                    style: AppTypography.body(
                      size: 13.5,
                      color: AppColors.textMuted(0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.lg),
        const AppNote(
          icon: Icons.payments_outlined,
          text:
              'In a hurry? Order now and pay the rider in cash instead.',
        ),
      ],
    ),
    bottomNavigationBar: StickyActionBar(
      label: 'Try again',
      onPressed: () => context.pushReplacementNamed(AppRoutes.topUp),
      secondaryLabel: 'Use a different method',
      onSecondary: () => context.goNamed(AppRoutes.customerHome),
    ),
  );
}
