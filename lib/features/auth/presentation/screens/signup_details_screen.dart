import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Sign-up 4 of 4 — optional. Skipping lands you in the app just the same.
///
/// The last step, so this is where the account is actually created from the
/// draft the previous three steps filled in.
class SignUpDetailsScreen extends ConsumerStatefulWidget {
  const SignUpDetailsScreen({super.key});

  @override
  ConsumerState<SignUpDetailsScreen> createState() =>
      _SignUpDetailsScreenState();
}

class _SignUpDetailsScreenState extends ConsumerState<SignUpDetailsScreen> {
  Gender _gender = Gender.unspecified;
  DateTime _dob = DateTime(1994, 4, 14);

  /// Creates the account and signs in. Sellers register their business
  /// first, so they are routed there rather than to a customer home.
  Future<void> _finish({bool skipped = false}) async {
    if (!skipped) {
      ref
          .read(sessionProvider.notifier)
          .updateDraft((d) => d.copyWith(gender: _gender, dateOfBirth: _dob));
    }

    final draft = ref.read(sessionProvider).draft;
    final result = await ref.read(authRepositoryProvider).completeProfile(draft);
    if (!mounted) return;

    result.when(
      success: (user) {
        // Signing in first: the seller onboarding routes sit outside the
        // onboarding stack, so a signed-out seller would be redirected
        // straight back to the intro.
        ref.read(sessionProvider.notifier).signIn(user);
        if (draft.role == UserRole.seller) {
          context.goNamed(AppRoutes.sellerOnboarding);
        }
      },
      failure: (f) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1930),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    step: 4,
    totalSteps: 4,
    title: 'A little about you',
    subtitle:
        "Optional — it helps sellers plan deliveries. Skip if you'd rather not.",
    primaryLabel: 'Finish · start ordering',
    onPrimary: _finish,
    secondaryLabel: 'Skip for now',
    onSecondary: () => _finish(skipped: true),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Gender'),
        Row(
          children: [
            Expanded(
              child: ChoiceTag(
                label: 'Female',
                selected: _gender == Gender.female,
                onTap: () => setState(() => _gender = Gender.female),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ChoiceTag(
                label: 'Male',
                selected: _gender == Gender.male,
                onTap: () => setState(() => _gender = Gender.male),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Date of birth'),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 17,
                  color: AppColors.textMuted(0.5),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${_dob.day} ${_monthName(_dob.month)} ${_dob.year}',
                  style: AppTypography.body(size: 14.5),
                ),
                const Spacer(),
                Icon(
                  Icons.expand_more_rounded,
                  size: 19,
                  color: AppColors.textMuted(0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}
