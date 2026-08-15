import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Step two: who are you? Switchable later in settings.
class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  UserRole? _selected;

  Future<void> _continue() async {
    final role = _selected;
    if (role == null) return;

    await ref.read(sessionProvider.notifier).setRole(role);
    if (!mounted) return;

    // Riders are invited by a seller, so they land on the invitation rather
    // than a self-serve sign-up.
    if (role == UserRole.rider) {
      context.goNamed(AppRoutes.riderInvitation);
    } else {
      context.goNamed(AppRoutes.signUpName);
    }
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    title: 'Who are you?',
    subtitle: 'You can switch later in settings.',
    primaryLabel: 'Continue',
    primaryEnabled: _selected != null,
    onPrimary: _continue,
    footer: _selected == UserRole.seller
        ? const AppNote(
            text: 'Sellers are verified before going live. Takes about a day.',
            icon: Icons.verified_user_outlined,
          )
        : null,
    child: Column(
      children: [
        for (final role in UserRole.values) ...[
          SelectableOption(
            title: role.title,
            subtitle: role.subtitle,
            icon: switch (role) {
              UserRole.customer => Icons.water_drop_outlined,
              UserRole.seller => Icons.storefront_outlined,
              UserRole.rider => Icons.two_wheeler_outlined,
            },
            selected: _selected == role,
            onTap: () => setState(() => _selected = role),
            tone: role == UserRole.rider ? AppColors.accent2 : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}
