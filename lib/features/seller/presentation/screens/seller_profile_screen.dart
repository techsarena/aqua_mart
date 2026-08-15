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
    final sync = ref.watch(sellerDashboardProvider).value?.sync;

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          // ── Identity ────────────────────────────────────────────────────
          AppCard(
            child: Row(
              children: [
                const SellerAvatar(size: 54),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chashma Pure Water',
                        style: AppTypography.heading(size: 19),
                      ),
                      const SizedBox(height: 5),
                      const AppTag(
                        'Verified seller',
                        tone: TagTone.accent2,
                        icon: Icons.verified_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Standing ────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                const Expanded(
                  child: StatTile(value: '4.8', label: 'rating · 1,240'),
                ),
                const Expanded(
                  child: StatTile(
                    value: '96%',
                    label: 'on time',
                    valueColor: AppColors.accent2_700,
                  ),
                ),
                Expanded(
                  child: StatTile(value: '${riders.length}', label: 'riders'),
                ),
              ],
            ),
          ),

          // ── Payout ──────────────────────────────────────────────────────
          if (nextPayout != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: () => context.pushNamed(AppRoutes.payoutStatement),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next payout',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.textMuted(0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.rupees(nextPayout.netPaid),
                    style: AppTypography.heading(size: 30),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Every Monday · ${nextPayout.bankLabel ?? 'your bank'} · '
                    'after 8% commission',
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              context.pushNamed(AppRoutes.payoutStatement),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                          ),
                          child: const Text('Statements'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                          ),
                          child: const Text('Change bank'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ── Riders ──────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text('Your riders', style: AppTypography.heading(size: 20)),
              const Spacer(),
              TextButton(
                onPressed: () => context.pushNamed(AppRoutes.riderPerformance),
                style: TextButton.styleFrom(minimumSize: Size.zero),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                for (final rider in riders)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        AppAvatar(name: rider.name, size: 38),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rider.name,
                                style: AppTypography.body(
                                  size: 14,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                rider.statusLine,
                                style: AppTypography.body(
                                  size: 12,
                                  color: AppColors.textMuted(0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppTag(
                          rider.status.label,
                          tone: switch (rider.status) {
                            RiderStatus.onRun => TagTone.accent2,
                            RiderStatus.idle => TagTone.neutral,
                            RiderStatus.offDuty => TagTone.neutral,
                          },
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Send an invite by phone number.'),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('Invite a rider'),
                  ),
                ),
              ],
            ),
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
