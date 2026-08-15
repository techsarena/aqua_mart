import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A settings row: icon, title, optional status text, chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Right-aligned status — "2 to return", "Approved", "Last synced 4 min ago".
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Tints the icon — used for verification and warning rows.
  final Color? tone;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tone ?? AppColors.textMuted(0.65)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      size: 14.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.textMuted(0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (trailingText != null)
              Text(
                trailingText!,
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: tone ?? AppColors.textMuted(0.5),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.neutral400,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Wraps settings rows in one card with hairline dividers between them.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null) ...[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            title!.toUpperCase(),
            style: AppTypography.body(
              size: 10.5,
              weight: FontWeight.w800,
              letterSpacing: 0.9,
              color: AppColors.textMuted(0.45),
            ),
          ),
        ),
      ],
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}
