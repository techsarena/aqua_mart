import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A two-way view switch — "List / Map" on the rider's run.
///
/// The selected half is a raised pill inside a tinted track, so the control
/// reads as one object with a thumb rather than as two buttons.
class SegmentedSwitch extends StatelessWidget {
  const SegmentedSwitch({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    this.onDark = false,
  }) : assert(
         labels.length == icons.length,
         'every segment needs a label and an icon',
       );

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Sits on the map rather than on the page ground: the track goes solid
  /// white and the thumb goes dark, so it stays legible over the terrain.
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: onDark ? AppColors.surface : AppColors.neutral200,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: onDark
          ? [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: _Segment(
              label: labels[i],
              icon: icons[i],
              selected: i == selectedIndex,
              onDark: onDark,
              onTap: () => onSelected(i),
            ),
          ),
      ],
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool onDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = onDark ? AppColors.text : AppColors.surface;
    final selectedFg = onDark ? AppColors.surface : AppColors.text;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: selected && !onDark
                ? [
                    BoxShadow(
                      color: AppColors.text.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? selectedFg : AppColors.textMuted(0.6),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: selected ? selectedFg : AppColors.textMuted(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
