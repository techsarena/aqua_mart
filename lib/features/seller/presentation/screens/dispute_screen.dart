import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';

/// A customer complaint, and the three ways the seller can settle it.
///
/// The screen gives the seller what they need to judge fairly: what she said,
/// her history with them, and the cost of each option.
class DisputeScreen extends ConsumerStatefulWidget {
  const DisputeScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  DisputeResolution? _resolution;
  bool _submitting = false;

  Future<void> _settle() async {
    setState(() => _submitting = true);
    await ref
        .read(sellerDataSourceProvider)
        .resolveDispute(widget.disputeId, _resolution!);

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (_resolution!) {
          DisputeResolution.replacement =>
            'Replacement added to your next run.',
          DisputeResolution.refund => 'Refund will come off your next payout.',
          DisputeResolution.escalate => 'Sent to Aqua Mart for review.',
        }),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(disputeProvider(widget.disputeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Complaint')),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 120),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(disputeProvider(widget.disputeId)),
        ),
        AsyncValue(value: final dispute) when dispute != null => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            // ── What happened ───────────────────────────────────────────
            AppCard(
              color: AppColors.dangerBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.report_gmailerrorred_rounded,
                        size: 22,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          dispute.reason,
                          style: AppTypography.body(
                            size: 15,
                            weight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${dispute.customerName} · order #${dispute.orderReference}',
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dispute.orderSummary,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.textMuted(0.65),
                      height: 1.5,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Divider(),
                  ),
                  Text(
                    'What she said',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${dispute.customerNote}"',
                    style: AppTypography.body(
                      size: 14,
                      height: 1.55,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                  if (dispute.hasPhoto) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      height: 96,
                      width: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_outlined,
                            size: 22,
                            color: AppColors.textMuted(0.45),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Her photo',
                            style: AppTypography.body(
                              size: 11,
                              color: AppColors.textMuted(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Who she is ──────────────────────────────────────────────
            if (dispute.customerHistory != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppNote(
                icon: Icons.history_rounded,
                text: dispute.customerHistory!,
              ),
            ],

            // ── How to settle ───────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            Text(
              'How do you want to settle it?',
              style: AppTypography.body(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableOption(
              title: 'Send a free replacement',
              subtitle:
                  '1 × 25L on your next run · costs you '
                  '${Formatters.rupees(dispute.amount)}',
              selected: _resolution == DisputeResolution.replacement,
              onTap: () =>
                  setState(() => _resolution = DisputeResolution.replacement),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableOption(
              title: 'Refund ${Formatters.rupees(dispute.amount)}',
              subtitle: 'Deducted from your next payout',
              selected: _resolution == DisputeResolution.refund,
              onTap: () =>
                  setState(() => _resolution = DisputeResolution.refund),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableOption(
              title: 'I disagree — send it to Aqua Mart',
              subtitle: 'We review both sides within a day',
              selected: _resolution == DisputeResolution.escalate,
              tone: AppColors.neutral600,
              onTap: () =>
                  setState(() => _resolution = DisputeResolution.escalate),
            ),

            const SizedBox(height: AppSpacing.lg),
            AppNote.warning(
              text:
                  "Settle within ${dispute.timeLeft.inHours} hrs and it won't "
                  'affect your rating. Unanswered complaints do.',
            ),
          ],
        ),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: StickyActionBar(
        label: switch (_resolution) {
          DisputeResolution.replacement => 'Send replacement & apologise',
          DisputeResolution.refund => 'Refund the customer',
          DisputeResolution.escalate => 'Send to Aqua Mart',
          null => 'Choose how to settle',
        },
        enabled: _resolution != null && !_submitting,
        onPressed: _settle,
        secondaryLabel: 'Call the customer',
        onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connecting through the app…')),
        ),
      ),
    );
  }
}
