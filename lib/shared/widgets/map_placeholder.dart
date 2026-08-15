import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Stands in for the Google Maps SDK view.
///
/// Every screen that shows a map renders this, so dropping in
/// `google_maps_flutter` later means replacing this one widget.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({
    super.key,
    this.height = 200,
    this.caption,
    this.showCentrePin = false,
    this.pins = const [],
    this.radius = AppRadius.lg,
    this.overlay,
  });

  final double height;

  /// Developer-facing hint carried over from the design, e.g.
  /// "drag pin to set exact spot".
  final String? caption;
  final bool showCentrePin;

  /// Extra markers drawn at fractional offsets within the map area.
  final List<MapPin> pins;
  final double radius;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _MapPainter()),
          for (final pin in pins)
            Align(
              alignment: Alignment(pin.x, pin.y),
              child: _PinBubble(pin: pin),
            ),
          if (showCentrePin)
            const Center(
              child: Icon(
                Icons.location_on,
                size: 40,
                color: AppColors.accent,
                shadows: [
                  Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
            ),
          if (caption != null)
            Positioned(
              left: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  caption!,
                  style: AppTypography.body(
                    size: 10.5,
                    color: AppColors.textMuted(0.65),
                  ),
                ),
              ),
            ),
          if (overlay != null) overlay!,
        ],
      ),
    ),
  );
}

/// A marker on the placeholder map. [x] and [y] are `Alignment` coordinates.
class MapPin {
  const MapPin({
    required this.x,
    required this.y,
    this.label,
    this.isPrimary = false,
    this.icon,
  });

  final double x;
  final double y;
  final String? label;
  final bool isPrimary;
  final IconData? icon;
}

class _PinBubble extends StatelessWidget {
  const _PinBubble({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final bg = pin.isPrimary ? AppColors.accent : Colors.white;
    final fg = pin.isPrimary ? Colors.white : AppColors.text;

    if (pin.label == null) {
      return Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(pin.icon ?? Icons.water_drop_rounded, size: 15, color: fg),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        pin.label!,
        style: AppTypography.body(size: 11.5, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Draws a stylised street grid so the placeholder reads as a map rather than
/// an empty box.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9EFE8),
    );

    final water = Paint()..color = const Color(0xFFCFE3EE);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.72, 0)
        ..quadraticBezierTo(
          size.width * 0.86,
          size.height * 0.45,
          size.width * 0.74,
          size.height,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      water,
    );

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final lane = Paint()
      ..color = const Color(0xFFDCE5DB)
      ..strokeWidth = 3;

    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.78, y), road);
    }
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lane);
    }

    final block = Paint()..color = const Color(0xFFDFE8DE);
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * (0.06 + i * 0.15),
            size.height * (i.isEven ? 0.12 : 0.58),
            size.width * 0.09,
            size.height * 0.18,
          ),
          const Radius.circular(3),
        ),
        block,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
