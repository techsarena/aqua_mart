import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The bar pinned to the bottom of the browse → cart → pay flow.
///
/// Shows the running bottle count and total on the left and the single next
/// action on the right: "View order" → "Choose payment" → "Place order".
class StickyCartBar extends StatelessWidget {
  const StickyCartBar({
    super.key,
    required this.count,
    required this.total,
    required this.label,
    required this.onPressed,
  });

  final int count;
  final String total;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _BarShell(
    // The whole bar is the button — count, action and total read as one
    // target, so there is no dead white space beside it to aim at.
    child: Material(
      // Greyed when there is nothing to go to yet, so the bar never looks
      // live while ignoring taps.
      color: onPressed == null ? AppColors.neutral300 : AppColors.accent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              // A lighter disc, so the count sits on the blue without
              // punching a white hole in it.
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: AppTypography.body(
                    size: 15,
                    weight: FontWeight.w800,
                    color: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading(
                    size: 18,
                    color: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                total,
                style: AppTypography.heading(
                  size: 18,
                  color: AppColors.surface,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A single full-width button pinned to the bottom, with an optional secondary
/// text action underneath.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
    this.enabled = true,
    this.tone,
    this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool enabled;
  final Color? tone;

  /// Optional content shown above the button — a total, a note, a countdown.
  final Widget? child;

  @override
  Widget build(BuildContext context) => _BarShell(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (child != null) ...[child!, const SizedBox(height: AppSpacing.md)],
        FilledButton(
          onPressed: enabled ? onPressed : null,
          style: tone != null
              ? FilledButton.styleFrom(backgroundColor: tone)
              : null,
          child: Text(label),
        ),
        if (secondaryLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ),
      ],
    ),
  );
}

class _BarShell extends StatelessWidget {
  const _BarShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.md,
      AppSpacing.gutter,
      MediaQuery.paddingOf(context).bottom + AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      boxShadow: [
        BoxShadow(
          color: AppColors.text.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: child,
  );
}
