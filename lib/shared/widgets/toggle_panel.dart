import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A single opt-in on its own tinted panel — "Make this my default",
/// "Save for next time".
///
/// The switch is drawn rather than taken from Material, whose track is thinner
/// than the thumb; here the thumb sits inside a fully rounded track.
class TogglePanel extends StatelessWidget {
  const TogglePanel({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.switchTrailing = false,
    this.background,
    this.foreground,
    this.titleSize = 16.5,
  });

  final String title;

  /// The reassurance under the title, where the choice needs explaining.
  final String? subtitle;

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Puts the switch after the text instead of before it. An opt-in reads
  /// better with the control first; a status the user is checking reads
  /// better with the words first.
  final bool switchTrailing;

  /// Overrides the panel tint — used where "off" is a state worth colouring
  /// differently rather than just an unchecked box.
  final Color? background;
  final Color? foreground;

  /// The design sets a larger title where the panel is a status rather than
  /// a single opt-in.
  final double titleSize;

  static const _trackWidth = 50.0;
  static const _trackHeight = 29.0;
  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    // Round, and sized to sit inside the track rather than overflow it.
    const thumb = _trackHeight - _inset * 2;

    return Material(
      color: background ?? AppColors.accent2_100,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!switchTrailing) ...[
                _track(thumb),
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.heading(
                        size: titleSize,
                        color: foreground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: AppTypography.body(
                          size: 13.5,
                          color: foreground ?? AppColors.textMuted(0.7),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (switchTrailing) ...[
                const SizedBox(width: AppSpacing.lg),
                _track(thumb),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The drawn switch — Material's own track is thinner than its thumb.
  Widget _track(double thumb) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    width: _trackWidth,
    height: _trackHeight,
    padding: const EdgeInsets.all(_inset),
    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: value ? AppColors.accent2 : AppColors.neutral300,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Container(
      width: thumb,
      height: thumb,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    ),
  );
}
