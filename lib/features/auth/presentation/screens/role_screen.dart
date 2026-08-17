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

    // Sellers register their business and riders register themselves, instead
    // of finishing the personal steps — so both accounts are created here
    // rather than at step 4. Their onboarding routes sit outside the
    // onboarding stack, and a signed-out user would be redirected straight
    // back to the intro.
    if (role == UserRole.seller || role == UserRole.rider) {
      await _startRegistration(
        role == UserRole.seller
            ? AppRoutes.sellerOnboarding
            : AppRoutes.riderIdentity,
      );
      return;
    }

    context.pushNamed(AppRoutes.signUpName);
  }

  /// Creates the account from the draft, then hands off to [nextRoute].
  Future<void> _startRegistration(String nextRoute) async {
    setState(() => _busy = true);

    final draft = ref.read(sessionProvider).draft;
    final result = await ref
        .read(authRepositoryProvider)
        .completeProfile(draft);
    if (!mounted) return;

    result.when(
      success: (user) {
        ref.read(sessionProvider.notifier).signIn(user);
        context.goNamed(nextRoute);
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
    // Riders have three more steps than customers do, so the track only
    // lengthens once "I deliver" is the choice on screen.
    totalSteps: _selected == UserRole.rider ? 5 : 4,
    title: 'Who are you?',
    subtitle: 'You can switch later in settings.',
    footer: _selected == UserRole.rider
        ? const AppNote.warning(
            text:
                'Riders need three more things: your CNIC, your vehicle, and '
                'the invite code from the seller you deliver for.',
            icon: Icons.info_outline_rounded,
          )
        : const AppNote.positive(
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
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.8,
          ),
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
            // The tick confirms the tap on the way out, since the card
            // navigates rather than waiting for a Continue button.
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.check_rounded,
                size: 24,
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
