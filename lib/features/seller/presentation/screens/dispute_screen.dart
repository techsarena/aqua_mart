import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/photo_placeholder.dart';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        titleSpacing: AppSpacing.gutter,
        title: Row(
          children: [
            if (context.canPop()) ...[
              const BackDiscButton(),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text('Complaint', style: AppTypography.heading(size: 25)),
            ),
          ],
        ),
      ),
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
            // One panel: the charge in caps, then who and which order, then
            // the order itself — read top to bottom before deciding.
            AppCard(
              color: AppColors.dangerBg,
              borderColor: AppColors.danger.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          dispute.reason.toUpperCase(),
                          style: AppTypography.body(
                            size: 12,
                            weight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${dispute.customerName} · order #${dispute.orderReference}',
                    style: AppTypography.heading(size: 17),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    dispute.orderSummary,
                    style: AppTypography.body(
                      size: 13.5,
                      color: AppColors.textMuted(0.6),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            // ── What she said ───────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            const FieldLabel('What she said'),
            AppCard(
              child: Text(
                '"${dispute.customerNote}"',
                style: AppTypography.body(size: 15, height: 1.5),
              ),
            ),

            // ── Her photo and her history, side by side ─────────────────
            if (dispute.hasPhoto || dispute.customerHistory != null) ...[
              const SizedBox(height: AppSpacing.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dispute.hasPhoto) ...[
                      const PhotoPlaceholder(
                        label: 'her photo',
                        width: 104,
                        height: 104,
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    if (dispute.customerHistory != null)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppColors.accent2_100,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Text(
                            dispute.customerHistory!,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.text,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ── How to settle ───────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            const FieldLabel('How do you want to settle it?'),
            SelectableOption(
              large: true,
              title: 'Send a free replacement',
              subtitle:
                  '1 × 25L on your next run · costs you '
                  '${Formatters.rupees(dispute.amount)}',
              selected: _resolution == DisputeResolution.replacement,
              onTap: () =>
                  setState(() => _resolution = DisputeResolution.replacement),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableOption(
              large: true,
              title: 'Refund ${Formatters.rupees(dispute.amount)}',
              subtitle: 'Deducted from your next payout',
              selected: _resolution == DisputeResolution.refund,
              onTap: () =>
                  setState(() => _resolution = DisputeResolution.refund),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableOption(
              large: true,
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
