import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../catalog/domain/entities/seller.dart';
import '../providers/seller_onboarding_providers.dart';

/// The waiting room, and a gate: while the store is `inReview` this is the
/// ONLY screen a seller can reach.
///
/// The seller app assumes an approved store — its endpoints answer 403 until
/// then — so letting someone in early produces a shell full of errors they
/// cannot act on. The status is re-read from the server on every visit rather
/// than trusted from local state, and the seller is released into the app
/// only when it comes back `approved`.
class SellerVerificationScreen extends ConsumerStatefulWidget {
  const SellerVerificationScreen({super.key});

  @override
  ConsumerState<SellerVerificationScreen> createState() =>
      _SellerVerificationScreenState();
}

class _SellerVerificationScreenState
    extends ConsumerState<SellerVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    final application = ref.watch(sellerApplicationProvider);
    final verification = ref.watch(sellerVerificationProvider);

    // Approval is what ends the wait. Releasing the registration checkpoint
    // is what lets the router route anywhere else, so it happens here and
    // nowhere else.
    ref.listen(sellerVerificationProvider, (_, next) {
      final status = next.value?.status;
      if (status == SellerVerificationStatus.approved) _release();
    });

    final serverStatus = verification.value?.status;
    final isRejected = serverStatus == SellerVerificationStatus.rejected;

    final steps = <({String title, String subtitle, bool done, bool active})>[
      (
        title: 'Business details received',
        subtitle: application.businessName.isEmpty
            ? 'Your business'
            : '${application.businessName} · '
                  '${application.businessType?.label ?? ''}',
        done: true,
        active: false,
      ),
      (
        title: 'Documents uploaded',
        subtitle: application.uploaded
            .map((d) => d.label.split(' — ').first)
            .join(', '),
        done: true,
        active: false,
      ),
      (
        title: 'Verification in progress',
        subtitle: 'Our team is reviewing · started just now',
        done: false,
        active: true,
      ),
      (
        title: 'Live in the app',
        subtitle: 'Customers in your area can order',
        done: false,
        active: false,
      ),
    ];

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
            decoration: BoxDecoration(
              color: isRejected ? AppColors.dangerBg : AppColors.accent100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRejected
                  ? Icons.error_outline_rounded
                  : Icons.hourglass_top_rounded,
              size: 32,
              color: isRejected ? AppColors.danger : AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isRejected
                ? 'We could not approve your store'
                : "We're checking your papers",
            style: AppTypography.heading(size: 27),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // A rejected seller is owed the reason, not an endless wait.
            isRejected
                ? (verification.value?.rejectionReason?.trim().isNotEmpty ??
                          false
                      ? verification.value!.rejectionReason!
                      : 'Please call support and we will talk it through.')
                : "Usually done within a day. We'll send a notification the "
                      "moment you're live — no need to wait here.",
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.65),
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _ProgressStep(
                    title: steps[i].title,
                    subtitle: steps[i].subtitle,
                    done: steps[i].done,
                    active: steps[i].active,
                    isLast: i == steps.length - 1,
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          // The old note invited the seller to set up their area now. That
          // is not possible before approval — every seller endpoint 403s —
          // so it promised something the app could not deliver.
          AppNote(
            icon: isRejected
                ? Icons.support_agent_outlined
                : Icons.notifications_active_outlined,
            text: '',
            richText: TextSpan(
              children: isRejected
                  ? const [
                      TextSpan(
                        text: 'Next step: ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text:
                            'call support on 0800-AQUAMART and we will help '
                            'you fix it and re-apply.',
                      ),
                    ]
                  : const [
                      TextSpan(
                        text: 'Nothing to do here: ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text:
                            'we will notify you the moment your store is '
                            'approved, and your area and stock come next.',
                      ),
                    ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // No "set up my area" here: the seller endpoints require an
              // approved store, so that button led straight into a wall of
              // 403s. Checking the status again is the only useful action
              // while the review is open.
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: verification.isLoading
                      ? null
                      : () => ref.invalidate(sellerVerificationProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    verification.isLoading ? 'Checking…' : 'Check again',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling 0800-AQUAMART…')),
                ),
                child: Text(
                  'Call support · 0800-AQUAMART',
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.textMuted(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ends the wait: clears the registration checkpoint so the router stops
  /// pinning this seller here, then sends them into their store.
  Future<void> _release() async {
    await ref.read(sessionProvider.notifier).completeRegistration();
    if (mounted) context.goNamed(AppRoutes.sellerDashboard);
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.accent2
                    : active
                    ? AppColors.accent100
                    : AppColors.neutral200,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: AppColors.accent, width: 2)
                    : null,
              ),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: done ? AppColors.accent2_200 : AppColors.neutral200,
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: done || active
                        ? AppColors.text
                        : AppColors.textMuted(0.45),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
