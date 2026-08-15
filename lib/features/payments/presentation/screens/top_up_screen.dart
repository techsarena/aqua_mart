import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../domain/entities/wallet.dart';
import '../providers/wallet_providers.dart';

/// Pick an amount and a rail. The Rs 1,000 tier carries the bonus, so it is
/// called out rather than left for the customer to discover.
class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  static const _presets = [500, 1000, 2000];
  static const _bonusThreshold = 1000;
  static const _bonusAmount = 60;

  int _amount = 1000;
  TopUpProvider _provider = TopUpProvider.jazzCash;
  final _customController = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final result = await ref
        .read(walletProvider.notifier)
        .startTopUp(amount: _amount, provider: _provider);

    if (!mounted) return;
    setState(() => _starting = false);

    result.when(
      success: (topUp) => context.pushReplacementNamed(
        AppRoutes.topUpPending,
        queryParameters: {'amount': '$_amount', 'id': topUp.id},
      ),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(walletProvider).value?.balance ?? 0;
    final earnsBonus = _amount >= _bonusThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Top up')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Balance ${Formatters.rupees(balance)}',
            style: AppTypography.body(
              size: 13.5,
              color: AppColors.textMuted(0.6),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final preset in _presets) ...[
                Expanded(
                  child: _AmountChip(
                    label: Formatters.rupees(preset).replaceAll('Rs ', ''),
                    selected: _amount == preset,
                    onTap: () => setState(() {
                      _amount = preset;
                      _customController.clear();
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: _AmountChip(
                  label: 'Other',
                  selected: !_presets.contains(_amount),
                  onTap: () => _askCustomAmount(context),
                ),
              ),
            ],
          ),

          if (earnsBonus) ...[
            const SizedBox(height: AppSpacing.lg),
            AppNote.positive(
              icon: Icons.card_giftcard_rounded,
              text: '',
              richText: TextSpan(
                children: [
                  TextSpan(
                    text: 'Top up ${Formatters.rupees(_amount)} and get ',
                  ),
                  TextSpan(
                    text: 'Rs $_bonusAmount free',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' — enough for half a refill.'),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Pay with',
            style: AppTypography.body(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final provider in TopUpProvider.values) ...[
            SelectableOption(
              title: provider.label,
              subtitle: provider == TopUpProvider.jazzCash
                  ? '0300 441 2987'
                  : 'Not linked yet',
              enabled: provider == TopUpProvider.jazzCash,
              selected: _provider == provider,
              onTap: () => setState(() => _provider = provider),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent100,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  provider.initials,
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w800,
                    color: AppColors.accent700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _starting ? 'Starting…' : 'Top up ${Formatters.rupees(_amount)}',
        enabled: !_starting && _amount > 0,
        onPressed: _start,
      ),
    );
  }

  Future<void> _askCustomAmount(BuildContext context) async {
    final entered = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How much?'),
        content: TextField(
          controller: _customController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'Rs '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(_customController.text.trim()),
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (entered != null && entered > 0) setState(() => _amount = entered);
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body(
            size: 14.5,
            weight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    ),
  );
}
