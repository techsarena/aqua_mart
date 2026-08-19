import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../domain/entities/rider_invite.dart';
import '../providers/seller_providers.dart';

/// "Invites" — the confirmation after sending one, over the list of every
/// invite still waiting on a reply.
///
/// [justSentId] marks the invite this screen was opened for, so the banner can
/// name that number. Reached without one (from the riders list), the screen is
/// simply the waiting list.
class RiderInvitesScreen extends ConsumerWidget {
  const RiderInvitesScreen({super.key, this.justSentId});

  final String? justSentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderInvitesProvider);

    return Scaffold(
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: switch (async) {
              AsyncLoading() => const SkeletonList(itemCount: 3),
              AsyncError(:final error) => ErrorView(
                failure: asFailure(error),
                onRetry: () => ref.invalidate(riderInvitesProvider),
              ),
              AsyncValue(value: final invites) when invites != null => _Body(
                invites: invites,
                justSentId: justSentId,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
          StickyActionBar(
            label: 'Invite another rider',
            onPressed: () => context.pushNamed(AppRoutes.inviteRider),
            secondaryLabel: 'Back to riders',
            // `go`, not pop: this screen replaces the form it came from, so
            // there may be no riders list behind it to pop back to.
            onSecondary: () => context.goNamed(AppRoutes.riderPerformance),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      MediaQuery.paddingOf(context).top + AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.lg,
    ),
    child: Row(
      children: [
        BackDiscButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(AppRoutes.riderPerformance),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            'Invites',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading(size: 28),
          ),
        ),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.invites, required this.justSentId});

  final List<RiderInvite> invites;
  final String? justSentId;

  @override
  Widget build(BuildContext context) {
    final justSent = invites.where((i) => i.id == justSentId).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      children: [
        if (justSent != null) ...[
          _SentBanner(invite: justSent),
          const SizedBox(height: AppSpacing.xl),
        ],

        if (invites.isEmpty)
          EmptyView(
            icon: Icons.mark_email_read_outlined,
            title: 'No invites waiting',
            message: 'Invites you send show up here until the rider accepts.',
          )
        else ...[
          const _SectionLabel('WAITING ON'),
          const SizedBox(height: AppSpacing.md),
          for (final invite in invites) ...[
            _InviteRow(invite: invite),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

/// The green panel confirming the invite that was just sent.
class _SentBanner extends ConsumerWidget {
  const _SentBanner({required this.invite});

  final RiderInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(riderCodeProvider).value;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.accent2_100,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 27,
              color: AppColors.surface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Invite sent to ${invite.phoneLabel}',
            style: AppTypography.heading(size: 27, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "They'll show up in your riders list the moment they accept."
            '${code == null ? '' : ' Code $code works for anyone you share '
                'it with.'}',
            style: AppTypography.body(
              size: 15,
              color: AppColors.accent2Deep,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTypography.body(
      size: 12,
      weight: FontWeight.w700,
      color: AppColors.textMuted(0.5),
      letterSpacing: 0.9,
    ),
  );
}

/// One waiting invite: the number, how long it has been out, and the one
/// action that still makes sense for it.
class _InviteRow extends ConsumerStatefulWidget {
  const _InviteRow({required this.invite});

  final RiderInvite invite;

  @override
  ConsumerState<_InviteRow> createState() => _InviteRowState();
}

class _InviteRowState extends ConsumerState<_InviteRow> {
  bool _busy = false;

  Future<void> _run(Future<Result<void>> Function() action, String done) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(done))),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final notifier = ref.read(riderInvitesProvider.notifier);

    // A fresh invite is offered a resend; an aged one is more likely to want
    // withdrawing, which is the design's split between the two rows.
    final isFresh = DateTime.now().difference(invite.sentAt).inHours < 24;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.neutral200,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 22,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.phoneLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 16, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  invite.subtitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.textMuted(0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (_busy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isFresh)
            _RowAction(
              label: 'Resend',
              tone: AppColors.accent,
              onPressed: () => _run(
                () => notifier.resend(invite.id),
                'Invite sent again to ${invite.phoneLabel}.',
              ),
            )
          else
            _RowAction(
              label: 'Cancel',
              tone: AppColors.textMuted(0.55),
              onPressed: () => _run(
                () => notifier.cancel(invite.id),
                'Invite to ${invite.phoneLabel} withdrawn.',
              ),
            ),
        ],
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final Color tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: AppTypography.body(
        size: 15,
        weight: FontWeight.w800,
        color: tone,
      ),
    ),
  );
}
