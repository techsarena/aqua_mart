import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A titled block with an optional trailing action — "Sellers near you · Map view".
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.xl,
      AppSpacing.gutter,
      AppSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.heading(size: 20)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.textMuted(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
      child,
    ],
  );
}

/// The small all-caps label above a group of fields.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
    child: Row(
      children: [
        Text(
          // Upper-cased here rather than at the call sites, which pass a mix
          // of cases — the design sets every field label in tracked caps.
          text.toUpperCase(),
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w700,
            color: AppColors.textMuted(0.7),
            letterSpacing: 0.8,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    ),
  );
}

/// A `label ─── value` row, used in every receipt and summary panel.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
    this.sublabel,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;
  final String? sublabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: isTotal
                    ? AppTypography.body(size: 15, weight: FontWeight.w700)
                    : AppTypography.body(
                        size: 13.5,
                        color: AppColors.textMuted(0.7),
                      ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: AppTypography.body(
                    size: 11.5,
                    color: AppColors.textMuted(0.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          value,
          style: isTotal
              ? AppTypography.heading(size: 18, color: valueColor)
              : AppTypography.body(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: valueColor,
                ),
        ),
      ],
    ),
  );
}
