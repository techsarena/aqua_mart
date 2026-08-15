import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The white rounded panel every screen is built from.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: shape,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.text.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A tinted information strip — used for hints, warnings and reassurances.
class AppNote extends StatelessWidget {
  const AppNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.background,
    this.foreground,
    this.richText,
  });

  /// Warning tone — "Settle within 24 hrs and it won't affect your rating."
  const AppNote.warning({
    super.key,
    required this.text,
    this.icon = Icons.schedule_rounded,
    this.richText,
  }) : background = AppColors.warningBg,
       foreground = AppColors.warning;

  /// Positive tone — "You haven't been charged."
  const AppNote.positive({
    super.key,
    required this.text,
    this.icon = Icons.check_circle_outline_rounded,
    this.richText,
  }) : background = AppColors.accent2_100,
       foreground = AppColors.accent2_700;

  final String text;
  final IconData icon;
  final Color? background;
  final Color? foreground;

  /// Optional rich replacement for [text] when part of it must be emphasised.
  final InlineSpan? richText;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppColors.accent700;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.accent100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: richText != null
                ? Text.rich(
                    richText!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      height: 1.4,
                    ),
                  )
                : Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      height: 1.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
