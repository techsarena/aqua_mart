import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';

/// What the customer is holding, and the two ways to give it back: swap for
/// full bottles at the refill price, or return them and get the deposit.
class EmptyBottlesScreen extends ConsumerStatefulWidget {
  const EmptyBottlesScreen({super.key});

  @override
  ConsumerState<EmptyBottlesScreen> createState() => _EmptyBottlesScreenState();
}

/// How the customer wants their empties handled.
enum _Handling { swap, refund }

class _EmptyBottlesScreenState extends ConsumerState<EmptyBottlesScreen> {
  /// The empties on hand, as the design lists them.
  static const _holdings = [
    (id: 'e-25', litres: 25, count: 2, seller: 'Chashma', deposit: 600),
    (id: 'e-10', litres: 10, count: 1, seller: 'Ravi Aqua', deposit: 300),
  ];

  static const _refillPricePerBottle = 110;

  final _selected = <String>{'e-25'};
  _Handling _handling = _Handling.swap;

  int get _totalDeposit => _holdings.fold(0, (sum, h) => sum + h.deposit);

  int get _selectedDeposit => _holdings
      .where((h) => _selected.contains(h.id))
      .fold(0, (sum, h) => sum + h.deposit);

  int get _selectedCount => _holdings
      .where((h) => _selected.contains(h.id))
      .fold(0, (sum, h) => sum + h.count);

  int get _swapCost => _selectedCount * _refillPricePerBottle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My empty bottles')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        // ── What you'd get back ─────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deposit you can get back',
                style: AppTypography.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.textMuted(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Formatters.rupees(_totalDeposit),
                style: AppTypography.heading(size: 34),
              ),
              const SizedBox(height: 4),
              Text(
                '${_holdings.fold(0, (s, h) => s + h.count)} bottles held · '
                'Rs 300 each',
                style: AppTypography.body(
                  size: 12.5,
                  color: AppColors.textMuted(0.55),
                ),
              ),
            ],
          ),
        ),

        // ── Which ones ──────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Pick what to send back',
          style: AppTypography.body(size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final holding in _holdings) ...[
          SelectableOption(
            title: '${holding.count} × ${holding.litres}L empty',
            subtitle:
                '${holding.seller} · ${Formatters.rupees(holding.deposit)} deposit',
            selected: _selected.contains(holding.id),
            onTap: () => setState(() {
              _selected.contains(holding.id)
                  ? _selected.remove(holding.id)
                  : _selected.add(holding.id);
            }),
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent100,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '${holding.litres} L',
                style: AppTypography.body(
                  size: 11.5,
                  weight: FontWeight.w800,
                  color: AppColors.accent700,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Swap or refund ──────────────────────────────────────────────
        const SizedBox(height: AppSpacing.lg),
        Text(
          'How should we handle it?',
          style: AppTypography.body(size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),
        SelectableOption(
          title: 'Swap for full bottles',
          subtitle:
              'Pay only the refill price — ${Formatters.rupees(_swapCost)}',
          icon: Icons.swap_horiz_rounded,
          selected: _handling == _Handling.swap,
          onTap: () => setState(() => _handling = _Handling.swap),
        ),
        const SizedBox(height: AppSpacing.sm),
        SelectableOption(
          title: 'Just return them',
          subtitle:
              '${Formatters.rupees(_selectedDeposit)} back to your wallet '
              'in 2 days',
          icon: Icons.account_balance_wallet_outlined,
          selected: _handling == _Handling.refund,
          onTap: () => setState(() => _handling = _Handling.refund),
        ),
      ],
    ),
    bottomNavigationBar: StickyActionBar(
      label: 'Book a pickup · tomorrow 9–11 AM',
      enabled: _selected.isNotEmpty,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _handling == _Handling.swap
                  ? 'Pickup booked — the rider will bring full bottles.'
                  : 'Pickup booked — your deposit lands in 2 days.',
            ),
          ),
        );
        context.pop();
      },
    ),
  );
}
