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
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          // ── Who you are ─────────────────────────────────────────────────
          AppCard(
            child: Row(
              children: [
                AppAvatar(name: user?.fullName ?? 'You', size: 54),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'You',
                        style: AppTypography.heading(size: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.phone(user?.phone ?? ''),
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.textMuted(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Wallet ──────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet balance',
                  style: AppTypography.body(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.textMuted(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.rupees(user?.walletBalance ?? 0),
                  style: AppTypography.heading(size: 30),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.pushNamed(AppRoutes.topUp),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Top up'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.pushNamed(AppRoutes.wallet),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('History'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Khata ───────────────────────────────────────────────────────
          if (user?.hasKhata ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              color: AppColors.warningBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 22,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly khata · ${Formatters.rupees(user!.khataDue)}',
                          style: AppTypography.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                        Text(
                          'Due ${user.khataDueDate != null ? Formatters.shortDate(user.khataDueDate!) : 'this month'}'
                          ' · ${user.khataSellerName ?? ''}',
                          style: AppTypography.body(
                            size: 12.5,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Settings ────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Saved addresses',
                trailingText: '$addressCount',
                onTap: () => context.pushNamed(AppRoutes.addressBook),
              ),
              SettingsTile(
                icon: Icons.water_drop_outlined,
                title: 'My empty bottles',
                trailingText: '2 to return',
                onTap: () => context.pushNamed(AppRoutes.emptyBottles),
              ),
              SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                trailingText:
                    (session.language ?? AppLanguage.english).label,
                onTap: () => _pickLanguage(context, ref),
              ),
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () => context.pushNamed(AppRoutes.notifications),
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
