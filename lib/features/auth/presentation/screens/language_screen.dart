import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/aqua_logo.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../providers/auth_providers.dart';

/// Step one of two taps into the app: choose your language.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  AppLanguage _selected = AppLanguage.english;

  Future<void> _continue() async {
    await ref.read(sessionProvider.notifier).setLanguage(_selected);
    if (mounted) context.goNamed(AppRoutes.rolePicker);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          const AquaLogoMark(size: 72),
          const SizedBox(height: AppSpacing.lg),
          const AquaWordmark(fontSize: 30),
          const SizedBox(height: 6),
          Text(
            'ایکوا مارٹ',
            style: AppTypography.body(
              size: 17,
              color: AppColors.textMuted(0.55),
              height: 2.1,
            ).copyWith(fontFamily: AppTypography.urduFamily),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Choose your language', style: AppTypography.heading(size: 24)),
          const SizedBox(height: 4),
          Text(
            'اپنی زبان چنیں',
            style: AppTypography.body(
              size: 15,
              color: AppColors.textMuted(0.6),
              height: 2.1,
            ).copyWith(fontFamily: AppTypography.urduFamily),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              itemCount: AppLanguage.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final language = AppLanguage.values[i];
                return SelectableOption(
                  title: language.label,
                  subtitle: language.subtitle,
                  selected: _selected == language,
                  onTap: () => setState(() => _selected = language),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: FilledButton(
              onPressed: _continue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    ),
  );
}
