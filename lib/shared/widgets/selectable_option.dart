import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The bordered choice row used for payment methods, roles, settlement options
/// and cancellation reasons. Selected state tints the fill and the border.
class SelectableOption extends StatelessWidget {
  const SelectableOption({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.showRadio = true,
    this.tone,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final bool showRadio;

  /// Overrides the accent used when selected — the danger tone on destructive
  /// choices, for instance.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.accent;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.onTint : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? accent : AppColors.divider,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ] else if (icon != null) ...[
                  Icon(
                    icon,
                    size: 21,
                    color: selected ? accent : AppColors.textMuted(0.6),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body(
                          size: 14.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
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
                if (trailing != null)
                  trailing!
                else if (showRadio)
                  _Radio(selected: selected, accent: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? accent : Colors.transparent,
      border: Border.all(
        color: selected ? accent : AppColors.neutral400,
        width: 1.6,
      ),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
        : null,
  );
}

/// Multi-select chip — "On time", "Seal was intact", "Clean bottles".
class ChoiceTag extends StatelessWidget {
  const ChoiceTag({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.accent;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? accent : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? accent : AppColors.divider),
          ),
          child: Text(
            label,
            style: AppTypography.body(
              size: 13,
              weight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal segmented filter — "Cheapest · Fastest · Top rated · Open now".
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: padding,
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (context, i) => ChoiceTag(
        label: labels[i],
        selected: i == selectedIndex,
        onTap: () => onSelected(i),
      ),
    ),
  );
}
