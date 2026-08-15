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
    this.bottomBar,
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

  /// Pinned to the bottom of the screen, below the scrolling body — the OTP
  /// keypad, which must stay put while the boxes above it fill in.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          // The header: a round back chevron, the progress track, and the
          // "n of m" counter, all on one line.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                if (showBack && context.canPopRoute)
                  const _BackButton()
                else
                  const SizedBox(width: 40),
                if (step != null && totalSteps != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _StepTrack(step: step!, total: totalSteps!),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '$step of $totalSteps',
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
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
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
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
          if (bottomBar != null) bottomBar!,
        ],
      ),
    ),
  );
}

extension on BuildContext {
  /// Whether this route can be popped.
  ///
  /// `ModalRoute.of` is read from the screen's own context, so it reflects
  /// the route the scaffold is actually sitting on — `Navigator.canPop`
  /// looks at the navigator, which answers for the wrong stack when the
  /// screen is the first route of a pushed branch.
  bool get canPopRoute => ModalRoute.of(this)?.impliesAppBarDismissal ?? false;
}

/// The round white back chevron. Flips automatically in RTL, since the icon
/// is direction-aware and the row it sits in mirrors with the layout.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: () => Navigator.maybePop(context),
      customBorder: const CircleBorder(),
      child: const SizedBox.square(
        dimension: 40,
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 17),
      ),
    ),
  );
}

/// The progress track — one segment per step, filled up to the current one.
class _StepTrack extends StatelessWidget {
  const _StepTrack({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 1; i <= total; i++) ...[
        if (i > 1) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? AppColors.accent : AppColors.neutral300,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ],
    ],
  );
}
