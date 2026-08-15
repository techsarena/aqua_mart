import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../providers/order_providers.dart';

/// Cancelling a loaded order. The screen is honest about the cost to the
/// seller rather than making it frictionless.
class CancelOrderScreen extends ConsumerStatefulWidget {
  const CancelOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<CancelOrderScreen> createState() => _CancelOrderScreenState();
}

class _CancelOrderScreenState extends ConsumerState<CancelOrderScreen> {
  static const _reasons = [
    'Taking too long',
    "Nobody's home now",
    'Ordered by mistake',
    'Found it cheaper elsewhere',
  ];

  String? _reason;
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    final result = await ref
        .read(orderListProvider.notifier)
        .cancel(widget.orderId, _reason!);

    if (!mounted) return;
    setState(() => _cancelling = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled. No charge this time.'),
          ),
        );
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId)).value;
    final rider = order?.rider;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          // The rider is already moving — say so before asking anything.
          if (rider != null)
            AppCard(
              color: AppColors.warningBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.two_wheeler_rounded,
                    size: 22,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rider.name} is already on the way',
                          style: AppTypography.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          '${rider.stopsBefore} stops before you · '
                          '~${order!.etaMinutes} min',
                          style: AppTypography.body(
                            size: 12.5,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          Text('Cancel this order?', style: AppTypography.heading(size: 27)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            rider != null
                ? "The bottles are already loaded on ${rider.name}'s bike. "
                      'Cancelling now costs the seller a trip.'
                : 'The seller has already started preparing your order.',
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.65),
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Why are you cancelling?',
            style: AppTypography.body(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final reason in _reasons) ...[
            SelectableOption(
              title: reason,
              selected: _reason == reason,
              tone: AppColors.danger,
              onTap: () => setState(() => _reason = reason),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          const SizedBox(height: AppSpacing.md),
          const AppNote.warning(
            text:
                'No charge this time. Cancelling three loaded orders in a '
                'month pauses your account.',
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _cancelling ? 'Cancelling…' : 'Yes, cancel it',
        enabled: _reason != null && !_cancelling,
        tone: AppColors.danger,
        onPressed: _cancel,
        secondaryLabel: "Keep it — I'll wait",
        onSecondary: () => context.pop(),
      ),
    );
  }
}
