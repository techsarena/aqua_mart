import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/rider_applicant.dart';
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';

/// How each rider is doing this week, and what the seller should do about it.
class RiderPerformanceScreen extends ConsumerWidget {
  const RiderPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerRidersProvider);

    return Scaffold(
      appBar: AppBar(
        // The round disc every other screen backs out with, rather than the
        // bare Material chevron the AppBar would supply.
        leading: const Padding(
          padding: EdgeInsets.only(left: AppSpacing.md),
          child: Center(child: BackDiscButton()),
        ),
        leadingWidth: BackDiscButton.diameter + AppSpacing.md * 2,
        title: const Text('Riders this week'),
        actions: [
          // The invite card below only appears when the workload is lopsided,
          // so without this the invite flow would be unreachable most weeks.
          TextButton(
            onPressed: () => context.pushNamed(AppRoutes.inviteRider),
            child: const Text('Invite'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 140),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(sellerRidersProvider),
        ),
        AsyncValue(value: final riders) when riders != null => _Body(
          riders: riders,
          applicants: ref.watch(riderApplicantsProvider).value ?? const [],
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.riders, required this.applicants});

  final List<Rider> riders;
  final List<RiderApplicant> applicants;

  @override
  Widget build(BuildContext context) {
    final working = riders.where((r) => r.delivered > 0).toList()
      ..sort((a, b) => b.delivered.compareTo(a.delivered));

    final top = working.firstOrNull;
    final second = working.length > 1 ? working[1] : null;

    // Flags an imbalance worth acting on rather than leaving it in the numbers.
    final isLopsided =
        top != null && second != null && top.delivered > second.delivered * 1.6;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        // First: a rider cannot start work until this is answered, and the
        // join notification lands the seller on this screen to answer it.
        if (applicants.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            applicants.length == 1
                ? '1 rider wants to join'
                : '${applicants.length} riders want to join',
            style: AppTypography.heading(size: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final applicant in applicants) ...[
            _ApplicantCard(applicant: applicant),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
        ],

        if (riders.isEmpty && applicants.isEmpty)
          EmptyView(
            icon: Icons.two_wheeler_outlined,
            title: 'No riders yet',
            message: 'Share your rider code and they will show up here once '
                'they join.',
            primaryLabel: 'Invite a rider',
            onPrimary: () => context.pushNamed(AppRoutes.inviteRider),
          ),

        for (final rider in riders) ...[
          _RiderCard(rider: rider, isTop: rider.id == top?.id),
          const SizedBox(height: AppSpacing.md),
        ],

        if (isLopsided) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: AppColors.accent100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${top.name.split(' ').first} is carrying the week',
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w800,
                    color: AppColors.accent800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "He's done nearly twice ${second.name.split(' ').first}'s "
                  'stops. Consider a bonus or a third rider.',
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.accent800,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      context.pushNamed(AppRoutes.inviteRider),
                  child: const Text('Invite a rider'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.isTop});

  final Rider rider;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final hasIssues = rider.lateDeliveries > 0 || rider.complaints > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: rider.name, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.name,
                      style: AppTypography.body(
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      rider.status == RiderStatus.offDuty
                          ? 'Off duty · 0 deliveries'
                          : rider.statusLine,
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.textMuted(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (isTop) const AppTag('Top rider', tone: TagTone.accent2),
            ],
          ),

          if (rider.delivered > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: '${rider.delivered}',
                    label: 'delivered',
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: '${rider.onTimePercent}%',
                    label: 'on time',
                    valueColor: rider.onTimePercent >= 90
                        ? AppColors.accent2_700
                        : AppColors.warning,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    value: rider.rating.toStringAsFixed(1),
                    label: 'rating',
                  ),
                ),
              ],
            ),
          ],

          if (hasIssues) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${[if (rider.lateDeliveries > 0) '${rider.lateDeliveries} late deliveries', if (rider.complaints > 0) '${rider.complaints} complaint'].join(' and ')} this week',
                      style: AppTypography.body(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rider waiting to be let onto the team, with the two answers.
///
/// Shows identity rather than performance — the seller is deciding whether
/// they know this person, not how they have been doing.
class _ApplicantCard extends ConsumerStatefulWidget {
  const _ApplicantCard({required this.applicant});

  final RiderApplicant applicant;

  @override
  ConsumerState<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends ConsumerState<_ApplicantCard> {
  bool _busy = false;

  Future<void> _decide({required bool approve}) async {
    final applicant = widget.applicant;

    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reject ${applicant.name}?'),
          content: const Text(
            'They will be told you did not accept, and will need a new code '
            'to apply again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep waiting'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    final result = await ref
        .read(riderApplicantsProvider.notifier)
        .decide(applicant.id, approve: approve);
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${applicant.name} is on your team.'
                : '${applicant.name} was not accepted.',
          ),
        ),
      ),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applicant = widget.applicant;

    return AppCard(
      borderColor: AppColors.accent200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: applicant.name, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Formatters.phone(applicant.phone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.textMuted(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const AppTag('Waiting', tone: TagTone.neutral),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.two_wheeler_outlined,
                  size: 17,
                  color: AppColors.neutral600,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    applicant.vehicleLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.neutral700,
                    ),
                  ),
                ),
                if (applicant.cnicLast4 != null)
                  Text(
                    'CNIC ••••${applicant.cnicLast4}',
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.textMuted(0.5),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(approve: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.dangerBg),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _decide(approve: true),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
