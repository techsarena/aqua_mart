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
import '../../../../shared/widgets/settings_tile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../addresses/presentation/providers/address_providers.dart';

/// The customer's "Me" tab: identity, money, and the settings rows.
class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionProvider);
    final addressCount = ref.watch(addressBookProvider).value?.length ?? 0;

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
            // ── Who you are ───────────────────────────────────────────────
            // Sits bare on the ground rather than in a card — the name is the
            // page title here, so nothing should frame it.
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
                    ],
                  ),
                ),
              ],
            ),

            // ── Wallet ────────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            _WalletCard(
              balance: user?.walletBalance ?? 0,
              onTopUp: () => context.pushNamed(AppRoutes.topUp),
              onHistory: () => context.pushNamed(AppRoutes.wallet),
            ),

            // ── Khata ─────────────────────────────────────────────────────
            if (user?.hasKhata ?? false) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                onTap: () => context.pushNamed(AppRoutes.wallet),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Monthly khata',
                            style: AppTypography.heading(size: 20),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          Formatters.rupees(user!.khataDue),
                          style: AppTypography.heading(size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Due '
                      '${user.khataDueDate != null ? Formatters.shortDate(user.khataDueDate!) : 'this month'}'
                      '${user.khataSellerName != null ? ' · ${user.khataSellerName}' : ''}',
                      style: AppTypography.body(
                        size: 15,
                        color: AppColors.textMuted(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Settings ──────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.lg),
            SettingsGroup(
              prominent: true,
              children: [
                SettingsTile(
                  prominent: true,
                  showChevron: false,
                  icon: Icons.location_on_outlined,
                  title: 'Saved addresses',
                  trailingText: '$addressCount',
                  onTap: () => context.pushNamed(AppRoutes.addressBook),
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
                  icon: Icons.water_drop_outlined,
                  title: 'My empty bottles',
                  trailingText: '2 to return',
                  onTap: () => context.pushNamed(AppRoutes.emptyBottles),
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
      ),
    );
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

/// The wallet panel — the only dark surface on the page, so the balance and
/// its two actions read before anything else.
class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.balance,
    required this.onTopUp,
    required this.onHistory,
  });

  final int balance;
  final VoidCallback onTopUp;
  final VoidCallback onHistory;

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
          'WALLET BALANCE',
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          Formatters.rupees(balance),
          style: AppTypography.heading(size: 40, color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onTopUp,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.accent700,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Top up'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              // Outlined on the dark panel: the secondary of the two.
              child: OutlinedButton(
                onPressed: onHistory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('History'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
