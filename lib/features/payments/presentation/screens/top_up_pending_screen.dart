import 'dart:async';

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
import '../../domain/entities/wallet.dart';
import '../providers/wallet_providers.dart';

/// The handoff: the customer approves the request inside JazzCash while this
/// screen counts down and polls for the outcome.
class TopUpPendingScreen extends ConsumerStatefulWidget {
  const TopUpPendingScreen({super.key, required this.amount, this.topUpId});

  final int amount;
  final String? topUpId;

  @override
  ConsumerState<TopUpPendingScreen> createState() => _TopUpPendingScreenState();
}

class _TopUpPendingScreenState extends ConsumerState<TopUpPendingScreen> {
  static const _window = Duration(seconds: 60);

  int _secondsLeft = _window.inSeconds;
  Timer? _ticker;

  int get _bonus => widget.amount >= 1000 ? 60 : 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _finish(succeeded: false);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Stands in for the customer approving inside JazzCash.
  Future<void> _confirm() async {
    final id = widget.topUpId;
    if (id == null) return _finish(succeeded: true);

    final result = await ref.read(walletProvider.notifier).checkTopUp(id);
    if (!mounted) return;
    _finish(succeeded: result.valueOrNull?.status == TopUpStatus.succeeded);
  }

  void _finish({required bool succeeded}) {
    _ticker?.cancel();
    if (!mounted) return;
    context.pushReplacementNamed(
      AppRoutes.topUpResult,
      queryParameters: {
        'amount': '${widget.amount}',
        'status': succeeded ? 'ok' : 'failed',
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
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
                'JC',
                style: AppTypography.body(
                  size: 14,
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
                  Text(
                    'Confirm in JazzCash',
                    style: AppTypography.heading(size: 22),
                  ),
                  Text(
                    '${Formatters.rupees(widget.amount)} to Aqua Mart Wallet',
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.textMuted(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        Center(
          child: SizedBox.square(
            dimension: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 132,
                  child: CircularProgressIndicator(
                    value: _secondsLeft / _window.inSeconds,
                    strokeWidth: 7,
                    backgroundColor: AppColors.neutral200,
                    color: AppColors.accent,
                  ),
                ),
                Text('$_secondsLeft', style: AppTypography.heading(size: 40)),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        Text(
          'Open the JazzCash app and approve the request.',
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 15, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          "Don't close this screen — we'll update it for you.",
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 13, color: AppColors.textMuted(0.6)),
        ),

        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            children: [
              SummaryRow(
                label: 'Top-up',
                value: Formatters.rupees(widget.amount),
              ),
              if (_bonus > 0)
                SummaryRow(
                  label: 'Bonus',
                  value: '+ ${Formatters.rupees(_bonus)}',
                  valueColor: AppColors.accent2_700,
                ),
              const SummaryRow(label: 'Fee', value: 'Rs 0'),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: _confirm, child: const Text('Open JazzCash')),
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted(0.7),
          ),
          child: const Text('Cancel top-up'),
        ),
      ],
    ),
  );
}
