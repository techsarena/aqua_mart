import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/catalog/domain/entities/bottle.dart';

/// A bottle drawn as a bottle — body, neck cap, and the size inside it.
///
/// The shelf shows it large with a neck; compact rows (cart lines, order
/// summaries) show a smaller neckless body, which reads as the same object
/// without spending the height.
class BottleGlyph extends StatelessWidget {
  const BottleGlyph({super.key, required this.size, this.compact = false});

  final BottleSize size;

  /// Drops the neck and shrinks the body for use in a list row.
  final bool compact;

  /// The 25L cooler bottle is drawn taller than the handheld sizes.
  double get _bodyHeight {
    final full = switch (size) {
      BottleSize.twentyFive => 92.0,
      BottleSize.ten => 82.0,
      BottleSize.six => 72.0,
    };
    return compact ? full * 0.62 : full;
  }

  double get _width {
    final full = switch (size) {
      BottleSize.twentyFive => 68.0,
      BottleSize.ten => 60.0,
      BottleSize.six => 52.0,
    };
    return compact ? full * 0.72 : full;
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: _width,
      height: _bodyHeight,
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: AppColors.accent2_200,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        size.label,
        style: AppTypography.body(
          size: compact ? 10.5 : 12.5,
          weight: FontWeight.w800,
          color: AppColors.accent2Deep,
        ),
      ),
    );

    if (compact) return body;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The neck, sitting proud of the body.
        Container(
          width: _width * 0.3,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.accent2Deep,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(5),
              bottom: Radius.zero,
            ),
          ),
        ),
        body,
      ],
    );
  }
}
