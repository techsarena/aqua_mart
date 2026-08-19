import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/settings_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';

/// The seller's "Me": their standing, their money, their riders, their setup.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final riders = ref.watch(sellerRidersProvider).value ?? const <Rider>[];
    final nextPayout = ref.watch(sellerPayoutsProvider).value?.firstOrNull;
    final dashboard = ref.watch(sellerDashboardProvider).value;
    final sync = dashboard?.sync;
    // The store's name, from the same place the header reads it. Falls back
    // to the person's name so the avatar still has initials to draw while the
    // dashboard is in flight.
    final storeName = (dashboard?.businessName.isNotEmpty ?? false)
        ? dashboard!.businessName
        : (session.user?.fullName ?? '');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          MediaQuery.paddingOf(context).top + AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          // ── Identity ────────────────────────────────────────────────────
          // The header itself, not a card on the page — there is no app bar
          // above it.
          Row(
            children: [
              AppAvatar(
                name: storeName,
                size: 70,
                background: AppColors.accent2_200,
                foreground: AppColors.accent2Deep,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: AppTypography.heading(size: 25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Shown only for an approved store — the badge claims
                    // Aqua Mart checked this seller's papers.
                    if (dashboard?.isVerified ?? false)
                      const AppTag(
                        'Verified seller',
                        tone: TagTone.accent2,
                        icon: Icons.check_rounded,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── Payout ──────────────────────────────────────────────────────
          if (nextPayout != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _PayoutPanel(
              amount: Formatters.rupees(nextPayout.netPaid),
              detail:
                  'Every Monday · ${nextPayout.bankLabel ?? 'your bank'} · '
                  'after 8% commission',
              onStatements: () => context.pushNamed(AppRoutes.payoutStatement),
            ),
          ],

          // ── Standing ────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: _StatCard(value: '4.8', label: 'rating · 1,240'),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: _StatCard(value: '96%', label: 'on time'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatCard(value: '${riders.length}', label: 'riders'),
                ),
              ],
            ),
          ),

          // ── Riders ──────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('Your riders'),
          for (final rider in riders) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              onTap: () => context.pushNamed(AppRoutes.riderPerformance),
              child: Row(
                children: [
                  AppAvatar(name: rider.name, size: 42),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading(size: 15.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rider.statusLine,
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
                  const SizedBox(width: AppSpacing.sm),
                  AppTag(
                    rider.status.label,
                    tone: switch (rider.status) {
                      RiderStatus.onRun => TagTone.accent2,
                      RiderStatus.idle ||
                      RiderStatus.offDuty => TagTone.neutral,
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _InviteRiderButton(
            onTap: () => context.pushNamed(AppRoutes.inviteRider),
          ),

          // ── Setup ───────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xl),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.schedule_rounded,
                title: 'Business hours',
                trailingText: '7 AM – 9 PM',
                onTap: () => context.pushNamed(AppRoutes.businessHours),
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                title: 'Licence & documents',
                trailingText: 'Approved',
                tone: AppColors.accent2_700,
                onTap: () {},
              ),
              SettingsTile(
                icon: Icons.sync_rounded,
                title: 'Books & stock sync',
                trailingText: sync?.lastSyncedAt != null
                    ? 'Last synced ${Formatters.relative(sync!.lastSyncedAt!)}'
                    : 'Not connected',
                onTap: () {},
              ),
              SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                trailingText: (session.language ?? AppLanguage.english).label,
                onTap: () {},
              ),
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & support',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).signOut();
              if (context.mounted) context.goNamed(AppRoutes.rolePicker);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.dangerBg),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

/// The money panel — the one dark surface on the page, so the payout is the
/// first thing the eye lands on.
class _PayoutPanel extends StatelessWidget {
  const _PayoutPanel({
    required this.amount,
    required this.detail,
    required this.onStatements,
  });

  final String amount;
  final String detail;
  final VoidCallback onStatements;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEXT PAYOUT',
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          amount,
          style: AppTypography.heading(size: 36, color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          detail,
          style: AppTypography.body(
            size: 13.5,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onStatements,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.text,
                ),
                child: const Text('Statements', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
                ),
                child: const Text(
                  'Change bank',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// One of the three standing figures, each on its own card.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.heading(size: 26)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.body(
            size: 12.5,
            color: AppColors.textMuted(0.55),
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

/// Dashed outline — an empty slot waiting to be filled, not a solid action.
class _InviteRiderButton extends StatelessWidget {
  const _InviteRiderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          height: 47,
          child: Center(
            child: Text(
              '+ Invite a rider',
              style: AppTypography.body(size: 15, weight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.lg),
        ),
      );
    final paint = Paint()
      ..color = AppColors.neutral400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 6;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
