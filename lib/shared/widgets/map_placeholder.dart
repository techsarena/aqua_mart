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
    this.route,
  });

  /// Null lets the map fill whatever its parent gives it — used by the
  /// full-bleed picker, where the map is the screen.
  final double? height;

  /// A dashed rider-to-destination line, in the same fractional `Alignment`
  /// space as [pins]. Drawn under the markers.
  final (MapPin, MapPin)? route;

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
          if (route != null)
            CustomPaint(painter: _RoutePainter(route!.$1, route!.$2)),
          for (final pin in pins)
            Align(
              alignment: Alignment(pin.x, pin.y),
              child: _PinBubble(pin: pin),
            ),
          if (showCentrePin) const Center(child: _CentrePin()),
          if (caption != null)
            Positioned(
              left: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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

/// The draggable "you are here" marker: a solid disc in a white collar, on a
/// short stalk that points at the exact spot it marks.
class _CentrePin extends StatelessWidget {
  const _CentrePin();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const SizedBox.square(
          dimension: 26,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      Container(width: 4, height: 18, color: AppColors.accent),
    ],
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
    this.isDestination = false,
  });

  /// The trip's end point — a solid teal dot in a white collar, no icon.
  final bool isDestination;

  final double x;
  final double y;
  final String? label;
  final bool isPrimary;
  final IconData? icon;

  @override
  bool operator ==(Object other) =>
      other is MapPin &&
      other.x == x &&
      other.y == y &&
      other.label == label &&
      other.isPrimary == isPrimary &&
      other.icon == icon &&
      other.isDestination == isDestination;

  @override
  int get hashCode => Object.hash(x, y, label, isPrimary, icon, isDestination);
}

class _PinBubble extends StatelessWidget {
  const _PinBubble({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final bg = pin.isPrimary ? AppColors.accent : Colors.white;
    final fg = pin.isPrimary ? Colors.white : AppColors.text;

    if (pin.isDestination) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const SizedBox.square(
          dimension: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent2,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

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
        style: AppTypography.body(
          size: 11.5,
          weight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// The dashed rider→destination route.
///
/// Drawn as an L — down from the rider, then across to the door — because a
/// straight diagonal reads as a flight path rather than a trip through streets.
class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.from, this.to);

  final MapPin from;
  final MapPin to;

  /// `Alignment` space (-1..1) → pixels.
  Offset _resolve(MapPin pin, Size size) =>
      Offset((pin.x + 1) / 2 * size.width, (pin.y + 1) / 2 * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final start = _resolve(from, size);
    final end = _resolve(to, size);
    final corner = Offset(start.dx, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(end.dx, end.dy);

    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 11).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
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
