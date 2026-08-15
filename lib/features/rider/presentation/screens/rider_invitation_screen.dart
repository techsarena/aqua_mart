import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../domain/entities/rider_run.dart';
import '../providers/rider_providers.dart';

/// Riders don't sign themselves up — a seller invites them. This is the
/// invitation, with the terms stated before they commit.
class RiderInvitationScreen extends ConsumerStatefulWidget {
  const RiderInvitationScreen({super.key});

  @override
  ConsumerState<RiderInvitationScreen> createState() =>
      _RiderInvitationScreenState();
}

class _RiderInvitationScreenState extends ConsumerState<RiderInvitationScreen> {
  bool _responding = false;

  Future<void> _respond(
    RiderInvitation invitation, {
    required bool accept,
  }) async {
    setState(() => _responding = true);
    await ref
        .read(riderDataSourceProvider)
        .respondToInvitation(invitation.id, accept: accept);

    if (!mounted) return;
    setState(() => _responding = false);

    if (accept) {
      context.goNamed(AppRoutes.riderRun);
    } else {
      context.goNamed(AppRoutes.rolePicker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(riderInvitationProvider);

    return switch (async) {
      AsyncLoading() => Scaffold(
        appBar: AppBar(),
        body: const SkeletonList(itemCount: 2, itemHeight: 140),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(riderInvitationProvider),
        ),
      ),
      AsyncValue(value: final invitation) when invitation != null => Scaffold(
        appBar: AppBar(title: const Text('Invitation')),
        body: ListView(
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
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          '${invitation.sellerName} wants you as their rider',
                          style: AppTypography.heading(size: 21),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Sent by ${invitation.sentBy} to ${invitation.sentTo}. '
                    'Accepting lets them assign you deliveries.',
                    style: AppTypography.body(
                      size: 13.5,
                      color: AppColors.textMuted(0.65),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── What the job is ─────────────────────────────────────────
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  _TermRow(
                    icon: Icons.map_outlined,
                    title: invitation.areas,
                    subtitle: "Where you'd be delivering",
                  ),
                  _TermRow(
                    icon: Icons.schedule_rounded,
                    title: invitation.hours,
                    subtitle: 'Their business hours',
                  ),
                  const _TermRow(
                    icon: Icons.payments_outlined,
                    title: "You'll collect cash",
                    subtitle: 'Handed in at the end of each run',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            const AppNote(
              icon: Icons.info_outline_rounded,
              text:
                  'You can leave any time from your profile, and you can ride '
                  'for more than one seller.',
            ),
          ],
        ),
        bottomNavigationBar: StickyActionBar(
          label: _responding ? 'Just a moment…' : 'Accept & start riding',
          enabled: !_responding,
          onPressed: () => _respond(invitation, accept: true),
          secondaryLabel: 'Decline',
          onSecondary: () => _respond(invitation, accept: false),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyView(
            icon: Icons.mail_outline_rounded,
            title: 'No invitation yet',
            message:
                'Riders are invited by a seller. Ask them to send an invite to '
                'your number.',
            primaryLabel: 'Back',
            onPrimary: () => context.goNamed(AppRoutes.rolePicker),
          ),
        ),
      ),
    };
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 11,
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent100,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, size: 18, color: AppColors.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.body(size: 14, weight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.textMuted(0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
