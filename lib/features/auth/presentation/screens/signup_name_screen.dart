import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Sign-up 3 of 4 — the name the rider will see at the door.
class SignUpNameScreen extends ConsumerStatefulWidget {
  const SignUpNameScreen({super.key});

  @override
  ConsumerState<SignUpNameScreen> createState() => _SignUpNameScreenState();
}

class _SignUpNameScreenState extends ConsumerState<SignUpNameScreen> {
  late final _controller = TextEditingController(
    text: ref.read(sessionProvider).draft.fullName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    ref
        .read(sessionProvider.notifier)
        .updateDraft((d) => d.copyWith(fullName: _controller.text.trim()));
    context.pushNamed(AppRoutes.signUpDetails);
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    step: 3,
    totalSteps: 4,
    title: 'What should we call you?',
    subtitle: 'Your rider will see this name at the door.',
    primaryLabel: 'Continue',
    primaryEnabled: _controller.text.trim().isNotEmpty,
    onPrimary: _continue,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('FULL NAME'),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_controller.text.trim().isNotEmpty) _continue();
          },
          decoration: const InputDecoration(hintText: 'Ayesha Khan'),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 15,
              color: AppColors.textMuted(0.45),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Just a first name is fine — you can change it later.',
                style: AppTypography.body(
                  size: 12.5,
                  color: AppColors.textMuted(0.55),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
