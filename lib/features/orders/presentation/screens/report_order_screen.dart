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
import '../providers/order_providers.dart';

/// "What went wrong?" — the complaint path.
///
/// The refund promise is stated up front so the customer knows what reporting
/// actually gets them.
class ReportOrderScreen extends ConsumerStatefulWidget {
  const ReportOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ReportOrderScreen> createState() => _ReportOrderScreenState();
}

class _ReportOrderScreenState extends ConsumerState<ReportOrderScreen> {
  static const _reasons = [
    'Seal was broken or missing',
    'Got fewer bottles than ordered',
    'Water smelled or tasted off',
    'Charged more than the app said',
    'Rider behaviour',
  ];

  String? _reason;
  final _noteController = TextEditingController();
  bool _hasPhoto = false;
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await ref
        .read(orderListProvider.notifier)
        .report(
          widget.orderId,
          reason: _reason!,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reported. We'll reply within a day.")),
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
          Text('What went wrong?', style: AppTypography.heading(size: 27)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order != null
                ? 'Order #${order.reference} · '
                      "we'll look into it and reply within a day."
                : "We'll look into it and reply within a day.",
            style: AppTypography.body(
              size: 13.5,
              color: AppColors.textMuted(0.6),
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
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
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Tell us what happened — optional',
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          InkWell(
            onTap: () => setState(() => _hasPhoto = !_hasPhoto),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hasPhoto ? AppColors.accent100 : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _hasPhoto ? AppColors.accent : AppColors.divider,
                  style: _hasPhoto ? BorderStyle.solid : BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasPhoto
                        ? Icons.check_circle_rounded
                        : Icons.add_a_photo_outlined,
                    size: 24,
                    color: _hasPhoto
                        ? AppColors.accent
                        : AppColors.textMuted(0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _hasPhoto ? 'Photo attached' : 'Add a photo',
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: _hasPhoto
                          ? AppColors.accent
                          : AppColors.textMuted(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppNote(
            icon: Icons.account_balance_wallet_outlined,
            text: '',
            richText: TextSpan(
              children: [
                const TextSpan(
                  text: 'If we agree it was the seller\'s fault, ',
                ),
                TextSpan(
                  text: order != null
                      ? Formatters.rupees(order.total)
                      : 'your money',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' goes back to your wallet.'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _submitting ? 'Sending…' : 'Report this order',
        enabled: _reason != null && !_submitting,
        tone: AppColors.danger,
        onPressed: _submit,
      ),
    );
  }
}
