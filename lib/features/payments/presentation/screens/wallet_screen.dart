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
import '../../../../shared/widgets/state_views.dart';
import '../providers/wallet_providers.dart';

/// Balance, what is still owed to you, and where the money went.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 96),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(walletProvider),
        ),
        AsyncValue(value: final wallet) when wallet != null => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.textMuted(0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.rupees(wallet.balance),
                    style: AppTypography.heading(size: 38),
                  ),
                  if (wallet.pendingDeposits > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${Formatters.rupees(wallet.pendingDeposits)} more once '
                      'your empties are collected',
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.accent2_700,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => context.pushNamed(AppRoutes.topUp),
                    child: const Text('Top up'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Text(
                'RECENT',
                style: AppTypography.body(
                  size: 10.5,
                  weight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: AppColors.textMuted(0.45),
                ),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (final tx in wallet.transactions)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tx.isCredit
                                  ? AppColors.accent2_100
                                  : AppColors.neutral200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              tx.isCredit
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 16,
                              color: tx.isCredit
                                  ? AppColors.accent2_700
                                  : AppColors.textMuted(0.6),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.label,
                                  style: AppTypography.body(
                                    size: 13.5,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  Formatters.shortDate(tx.at),
                                  style: AppTypography.body(
                                    size: 11.5,
                                    color: AppColors.textMuted(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${tx.isCredit ? '+' : '−'} '
                            '${Formatters.rupees(tx.amount)}',
                            style: AppTypography.body(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: tx.isCredit
                                  ? AppColors.accent2_700
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
