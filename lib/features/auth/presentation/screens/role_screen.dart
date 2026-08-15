import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Sign-up 2 of 4 — who are you? Switchable later in settings.
///
/// Picking a role is the whole step, so the tap itself advances: there is no
/// Continue button to confirm a choice the card already shows.
///
/// Riders divert to their invitation from here and sellers divert to business
/// registration; only customers carry on to the name step, where their profile
/// is created at the end of step 4.
class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  UserRole? _selected;

  /// Guards against a second tap while the seller's account is being created.
  bool _busy = false;

  Future<void> _select(UserRole role) async {
    if (_busy) return;

    // Paint the selection before navigating, so the card is visibly chosen
    // on the way out and still chosen if the user comes back.
    setState(() => _selected = role);

    await ref.read(sessionProvider.notifier).setRole(role);
    if (!mounted) return;

    // Riders are invited by a seller, so they land on the invitation rather
    // than in an app of their own.
    if (role == UserRole.rider) {
      context.goNamed(AppRoutes.riderInvitation);
      return;
    }

    // Sellers register their business instead of finishing the personal
    // steps, so their account is created here rather than at step 4 — the
    // seller onboarding routes sit outside the onboarding stack, and a
    // signed-out seller would be redirected straight back to the intro.
    if (role == UserRole.seller) {
      await _startSellerRegistration();
      return;
    }

    context.pushNamed(AppRoutes.signUpName);
  }

  Future<void> _startSellerRegistration() async {
    setState(() => _busy = true);

    final draft = ref.read(sessionProvider).draft;
    final result = await ref
        .read(authRepositoryProvider)
        .completeProfile(draft);
    if (!mounted) return;

    result.when(
      success: (user) {
        ref.read(sessionProvider.notifier).signIn(user);
        context.goNamed(AppRoutes.sellerOnboarding);
      },
      failure: (f) {
        setState(() {
          _busy = false;
          _selected = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    step: 2,
    totalSteps: 4,
    title: 'Who are you?',
    subtitle: 'You can switch later in settings.',
    footer: const AppNote.positive(
      text: 'Sellers are verified before going live. Takes about a day.',
      icon: Icons.verified_rounded,
    ),
    child: Column(
      children: [
        for (final role in UserRole.values) ...[
          _RoleCard(
            role: role,
            selected: _selected == role,
            onTap: () => _select(role),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}

/// One role choice: a filled icon badge, the role, and what it means.
///
/// Wider and quieter than [SelectableOption] — with no Continue button to
/// confirm against, the card carries no radio, and the selected state is a
/// tint rather than a border.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  /// The badge fill — cerulean for customers, teal for sellers, and a muted
  /// slate for riders, who arrive by invitation rather than by choosing.
  Color get _badgeColor => switch (role) {
    UserRole.customer => AppColors.accent,
    UserRole.seller => AppColors.accent2,
    UserRole.rider => AppColors.neutral400,
  };

  IconData get _icon => switch (role) {
    UserRole.customer => Icons.water_drop_rounded,
    UserRole.seller => Icons.inventory_2_rounded,
    UserRole.rider => Icons.access_time_rounded,
  };

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.onTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _badgeColor,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 30, color: AppColors.surface),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.title, style: AppTypography.heading(size: 21)),
                  const SizedBox(height: 6),
                  Text(
                    role.subtitle,
                    style: AppTypography.body(
                      size: 14.5,
                      color: AppColors.textMuted(0.6),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
