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
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent100,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: AppTypography.body(
              size: 14,
              weight: FontWeight.w800,
              color: AppColors.accent700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          total,
          style: AppTypography.heading(size: 19),
        ),
        const Spacer(),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ],
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
