import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/rider_providers.dart';

/// The end of rider sign-up — the seller has the application and is reviewing
/// it.
///
/// There is no step counter here: the five steps are done, and this is the
/// wait. The only action is calling the seller, since nothing the rider does
/// in the app moves the approval along.
class RiderPendingApprovalScreen extends ConsumerWidget {
  const RiderPendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(riderApplicationProvider);
    final seller = application.seller;
    final sellerName = seller?.sellerName ?? 'The seller';
    final phone = ref.watch(sessionProvider.select((s) => s.draft.phone));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xxl,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 46,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              '$sellerName is reviewing you',
              textAlign: TextAlign.center,
              style: AppTypography.heading(size: 27),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Most sellers approve within a few hours. We will text you'
              '${phone.isEmpty ? '' : ' on ${Formatters.phone(phone)}'}.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 14,
                color: AppColors.textMuted(0.6),
                height: 1.5,
              ),
            ),

            // ── Where the application stands ────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                children: [
                  const _CheckRow(text: 'Number confirmed', done: true),
                  _CheckRow(text: application.documentsLine, done: true),
                  const _CheckRow(
                    text: 'Seller approval — pending',
                    done: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            const AppNote(
              icon: Icons.info_outline_rounded,
              text:
                  'Once approved, runs appear on your Today screen and you '
                  'can start accepting deliveries.',
            ),
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        label: 'Call ${seller?.sellerName ?? 'the seller'}',
        // Placeholder until dialling is wired up: opens the rider's run so
        // the app past approval is reachable. `goNamed`, not push — the run
        // is a shell tab, and pushing it mounts a second copy of the shell.
        onPressed: () async {
          await ref.read(sessionProvider.notifier).completeRegistration();
          if (context.mounted) context.goNamed(AppRoutes.riderRun);
        },
        secondaryLabel: 'Change seller code',
        onSecondary: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// One line of the application's standing — done is a filled teal tick,
/// pending is an open ring.
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (done)
          const Icon(Icons.check_rounded, size: 21, color: AppColors.accent2)
        else
          Container(
            width: 19,
            height: 19,
            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.warning, width: 2),
            ),
          ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body(
              size: 14,
              weight: done ? FontWeight.w600 : FontWeight.w400,
              color: done ? AppColors.text : AppColors.textMuted(0.7),
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
