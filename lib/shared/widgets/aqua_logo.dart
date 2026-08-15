import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// The Fluid Cart mark — ribbon cart, wave floor, ripple wheels, droplet hub.
///
/// Ripples and the hub droplet drop out below 48px: they silt up.
class AquaLogoMark extends StatelessWidget {
  const AquaLogoMark({
    super.key,
    this.size = 64,
    this.color,
    this.onDark = false,
  });

  final double size;

  /// When null the brand gradient is used.
  final Color? color;
  final bool onDark;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _FluidCartPainter(
        color: color,
        onDark: onDark,
        showDetails: size >= 48,
      ),
    ),
  );
}

class _FluidCartPainter extends CustomPainter {
  _FluidCartPainter({
    this.color,
    required this.onDark,
    required this.showDetails,
  });

  final Color? color;
  final bool onDark;
  final bool showDetails;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final rect = Offset.zero & size;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (showDetails ? 5 : 6) * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()..style = PaintingStyle.fill;

    if (color != null) {
      stroke.color = color!;
      fill.color = color!;
    } else {
      final gradient = onDark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9FF0F2), Color(0xFF49B6DD)],
            )
          : AppColors.brandGradient;
      final shader = gradient.createShader(rect);
      stroke.shader = shader;
      fill.shader = shader;
    }

    // Cart handle + left upright.
    canvas.drawPath(
      Path()
        ..moveTo(4 * s, 15 * s)
        ..cubicTo(4 * s, 9 * s, 8 * s, 8.4 * s, 13.2 * s, 9.6 * s)
        ..lineTo(20.5 * s, 37.5 * s),
      stroke,
    );

    // Basket ribbon.
    canvas.drawPath(
      Path()
        ..moveTo(16.2 * s, 19 * s)
        ..lineTo(56.5 * s, 19 * s)
        ..cubicTo(55.6 * s, 28 * s, 52 * s, 34.6 * s, 46.5 * s, 37.5 * s),
      stroke,
    );

    // Wave floor.
    final wave = Path()..moveTo(20.5 * s, 37.5 * s);
    for (var i = 0; i < 3; i++) {
      final x = 20.5 * s + i * 8.7 * s;
      wave
        ..relativeCubicTo(2.9 * s, -4 * s, 5.8 * s, 4 * s, 8.7 * s, 0)
        ..moveTo(x + 8.7 * s, 37.5 * s);
    }
    canvas.drawPath(wave, stroke);

    if (showDetails) {
      // Ripple ticks.
      final ripple = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..color = (color ?? AppColors.gradientEnd).withValues(alpha: 0.35);
      if (color == null) {
        ripple.shader = stroke.shader;
        ripple.color = Colors.white.withValues(alpha: 0.35);
      }
      canvas
        ..drawLine(Offset(11 * s, 47 * s), Offset(15.5 * s, 47 * s), ripple)
        ..drawLine(Offset(8.5 * s, 53.5 * s), Offset(13 * s, 53.5 * s), ripple)
        ..drawLine(
          Offset(56 * s, 53.5 * s),
          Offset(60.5 * s, 53.5 * s),
          ripple,
        );
    }

    // Wheels.
    canvas
      ..drawCircle(Offset(27 * s, 52.5 * s), (showDetails ? 5.6 : 6) * s, fill)
      ..drawCircle(Offset(45 * s, 52.5 * s), (showDetails ? 5.6 : 6) * s, fill);

    if (showDetails) {
      // Droplet knocked out of the left hub.
      final droplet = Paint()
        ..style = PaintingStyle.fill
        ..color = onDark ? const Color(0xFF062B44) : Colors.white;
      canvas.drawPath(
        Path()
          ..moveTo(27 * s, 49.2 * s)
          ..lineTo(29.3 * s, 52 * s)
          ..arcToPoint(
            Offset(24.7 * s, 52 * s),
            radius: Radius.circular(3 * s),
            clockwise: true,
          )
          ..close(),
        droplet,
      );
    }
  }

  @override
  bool shouldRepaint(_FluidCartPainter old) =>
      old.color != color ||
      old.onDark != onDark ||
      old.showDetails != showDetails;
}

/// AQUA in light cyan, MART in deep blue — never the reverse.
class AquaWordmark extends StatelessWidget {
  const AquaWordmark({super.key, this.fontSize = 32, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'AQUA',
          style: TextStyle(
            color: onDark ? const Color(0xFF8FE6EF) : AppColors.brandAqua,
          ),
        ),
        TextSpan(
          text: ' MART',
          style: TextStyle(color: onDark ? Colors.white : AppColors.brandMart),
        ),
      ],
    ),
    style: AppTypography.heading(
      size: fontSize,
      weight: FontWeight.w800,
      height: 1,
    ).copyWith(letterSpacing: fontSize * 0.045),
  );
}

/// Mark + wordmark, the standard horizontal lockup.
class AquaLockup extends StatelessWidget {
  const AquaLockup({
    super.key,
    this.markSize = 56,
    this.fontSize = 30,
    this.onDark = false,
    this.tagline,
  });

  final double markSize;
  final double fontSize;
  final bool onDark;

  /// Only where the brand is new to the reader — never in-app.
  final String? tagline;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AquaLogoMark(size: markSize, onDark: onDark),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AquaWordmark(fontSize: fontSize, onDark: onDark),
          if (tagline != null) ...[
            const SizedBox(height: 7),
            Text(
              tagline!,
              style: AppTypography.body(
                size: 10,
                weight: FontWeight.w700,
                letterSpacing: 2.4,
                color: onDark
                    ? Colors.white.withValues(alpha: 0.65)
                    : AppColors.textMuted(0.5),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}
