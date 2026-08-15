import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared chrome for every stepped sign-up screen: a back chevron, an
/// "n of m" counter, a title, a supporting line, then the form.
///
/// Back chevrons flip automatically with the layout direction in RTL.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.step,
    this.totalSteps,
    this.primaryLabel,
    this.onPrimary,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
    this.footer,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final int? step;
  final int? totalSteps;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Rendered directly above the primary button — a reassurance note, usually.
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: showBack && Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: step != null && totalSteps != null
          ? Text(
              '$step of $totalSteps',
              style: AppTypography.body(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.textMuted(0.55),
              ),
            )
          : null,
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: [
                Text(title, style: AppTypography.heading(size: 27)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.textMuted(0.6),
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                child,
              ],
            ),
          ),
          if (primaryLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (footer != null) ...[
                    footer!,
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  FilledButton(
                    onPressed: primaryEnabled ? onPrimary : null,
                    child: Text(primaryLabel!),
                  ),
                  if (secondaryLabel != null)
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
