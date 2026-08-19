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
import '../../../../shared/widgets/settings_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/rider_providers.dart';

/// The rider's "Me" tab: who they are, who they ride for, and the way out.
///
/// Deliberately thin next to the customer's and seller's: a rider's money
/// lives on Earnings and their work on My run, so the only thing that had no
/// home before this screen was signing out.
class RiderProfileScreen extends ConsumerWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionProvider);

    // Both are already loaded for the other tabs, so reading them here costs
    // nothing — and a rider who has neither still gets a usable page.
    final earnings = ref.watch(riderEarningsProvider).value;
    final sellerName = ref.watch(riderRunProvider).value?.sellerName;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                AppAvatar(
                  name: user?.fullName ?? 'You',
                  size: 78,
                  background: AppColors.accent2_200,
                  foreground: AppColors.accent2Deep,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'You',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading(size: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.phone(user?.phone ?? ''),
                        style: AppTypography.body(
                          size: 16,
                          color: AppColors.textMuted(0.6),
                        ),
                      ),
                      if (sellerName != null && sellerName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Rides for $sellerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: AppColors.accent2Deep,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (earnings != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _StandingPanel(
                rating: earnings.rating,
                ratingCount: earnings.ratingCount,
                deliveries: earnings.deliveries,
                isTopRider: earnings.isTopRider,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            SettingsGroup(
              prominent: true,
              children: [
                SettingsTile(
                  prominent: true,
                  showChevron: false,
                  icon: Icons.trending_up_rounded,
                  title: 'Earnings',
                  onTap: () => context.goNamed(AppRoutes.riderEarnings),
                ),
                SettingsTile(
                  prominent: true,
                  showChevron: false,
                  icon: Icons.payments_outlined,
                  title: 'Cash handover',
                  onTap: () => context.goNamed(AppRoutes.riderCashHandover),
                ),
                SettingsTile(
                  prominent: true,
                  showChevron: false,
                  icon: Icons.language_rounded,
                  title: 'Language',
                  trailingText: (session.language ?? AppLanguage.english).label,
                  onTap: () => _pickLanguage(context, ref),
                ),
                SettingsTile(
                  prominent: true,
                  showChevron: false,
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: () => context.pushNamed(AppRoutes.notifications),
                ),
                SettingsTile(
                  prominent: true,
                  showChevron: false,
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => _signOut(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.dangerBg),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirmed first: a rider signing out mid-run loses the stop list they
  /// are working from, and the button sits one tap from the tab bar.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need your phone number and a code to sign back in.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) context.goNamed(AppRoutes.rolePicker);
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('Language', style: AppTypography.heading(size: 20)),
            const SizedBox(height: AppSpacing.md),
            for (final language in AppLanguage.values)
              ListTile(
                title: Text(language.label),
                subtitle: Text(language.subtitle),
                onTap: () => Navigator.pop(context, language),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (picked != null) {
      await ref.read(sessionProvider.notifier).setLanguage(picked);
    }
  }
}

/// How the rider is doing — the one tinted surface on the page.
///
/// Rating rather than money: the money is a whole tab away, and this is the
/// number a rider is judged on.
class _StandingPanel extends StatelessWidget {
  const _StandingPanel({
    required this.rating,
    required this.ratingCount,
    required this.deliveries,
    required this.isTopRider,
  });

  final double rating;
  final int ratingCount;
  final int deliveries;
  final bool isTopRider;

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
        Row(
          children: [
            Expanded(
              child: Text(
                'THIS WEEK',
                style: AppTypography.body(
                  size: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.onTint.withValues(alpha: 0.75),
                ),
              ),
            ),
            if (isTopRider)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Top rider',
                  style: AppTypography.body(
                    size: 12,
                    weight: FontWeight.w800,
                    color: AppColors.surface,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: rating.toStringAsFixed(1),
                label: ratingCount == 1 ? '1 rating' : '$ratingCount ratings',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: AppColors.surface.withValues(alpha: 0.25),
            ),
            Expanded(
              child: _Stat(value: '$deliveries', label: 'delivered'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: AppTypography.heading(size: 32, color: AppColors.surface),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: AppTypography.body(
          size: 13,
          color: AppColors.onTint.withValues(alpha: 0.8),
        ),
      ),
    ],
  );
}
