import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The hatched stand-in shown where a photo will go but none has been
/// uploaded — a bottle listing without a picture, a complaint without evidence.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    this.radius = AppRadius.lg,
  });

  /// Set in lower case in the design — `bottle photo`, `her photo`.
  final String label;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: CustomPaint(
      painter: _HatchPainter(),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        color: AppColors.accent200.withValues(alpha: 0.45),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            size: 13,
            color: AppColors.textMuted(0.5),
            height: 1.35,
          ),
        ),
      ),
    ),
  );
}

/// Diagonal hatching, drawn behind the placeholder's label.
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent300.withValues(alpha: 0.5)
      ..strokeWidth = 5;

    // Start a full height to the left so every stripe crosses the whole box.
    for (var x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}
