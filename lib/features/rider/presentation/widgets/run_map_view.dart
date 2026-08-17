import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/domain/entities/order_status.dart';
import '../../domain/entities/rider_run.dart';

/// The run plotted in order: every assigned stop, joined by the path between
/// them, with the next one called out.
///
/// Stops without a plot are simply left off — the map shows where the run
/// goes, and the list below is the complete record.
class RunMapView extends StatelessWidget {
  const RunMapView({
    super.key,
    required this.run,
    required this.onNavigate,
    required this.onCall,
    this.topInset = 0,
  });

  final RiderRun run;
  final VoidCallback onNavigate;
  final VoidCallback onCall;

  /// Clears whatever the screen floats above the map — the List/Map switch —
  /// so the run summary sits under it rather than behind it.
  final double topInset;

  List<RunStop> get _plotted =>
      run.pending.where((s) => s.plot != null).toList();

  @override
  Widget build(BuildContext context) {
    final next = run.nextStop;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The terrain, with the route and markers painted over it.
        const _MapTerrain(),
        CustomPaint(painter: _RouteLinePainter(_plotted)),

        for (var i = 0; i < _plotted.length; i++)
          Align(
            alignment: Alignment(_plotted[i].plot!.x, _plotted[i].plot!.y),
            child: _StopMarker(
              stop: _plotted[i],
              position: i + 1,
              isNext: _plotted[i].id == next?.id,
            ),
          ),

        // ── The run's shape, under whatever the screen floats above ─────
        Positioned(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          top: AppSpacing.sm + topInset,
          child: _RunSummaryPill(run: run),
        ),

        // ── The next stop, docked at the foot ───────────────────────────
        if (next != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MapStopSheet(
              stop: next,
              onNavigate: onNavigate,
              onCall: onCall,
            ),
          ),
      ],
    );
  }
}

/// "6 assigned stops · 8.4 km · about 1 h 10 m"
class _RunSummaryPill extends StatelessWidget {
  const _RunSummaryPill({required this.run});

  final RiderRun run;

  /// "1 h 10 m" / "35 m"
  String get _duration {
    final total = run.remainingDuration;
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    return hours > 0 ? '$hours h $minutes m' : '$minutes m';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      boxShadow: [
        BoxShadow(
          color: AppColors.text.withValues(alpha: 0.12),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '${run.pending.length} assigned stops',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(size: 14, weight: FontWeight.w800),
          ),
        ),
        Container(
          width: 1,
          height: 15,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: AppColors.divider,
        ),
        Flexible(
          child: Text(
            '${Formatters.distance(run.remainingMetres)} · about $_duration',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 13.5,
              color: AppColors.textMuted(0.6),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A numbered stop on the map.
///
/// The next stop is the filled accent disc with its label attached; a khata
/// stop is warmed so the rider can see an account delivery coming before they
/// reach the door.
class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.position,
    required this.isNext,
  });

  final RunStop stop;
  final int position;
  final bool isNext;

  bool get _isKhata => stop.paymentMethod == PaymentMethod.khata;

  @override
  Widget build(BuildContext context) {
    final fill = isNext
        ? AppColors.accent
        : _isKhata
        ? AppColors.warning
        : AppColors.surface;
    final foreground = isNext || _isKhata ? Colors.white : AppColors.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '$position',
            style: AppTypography.body(
              size: 15,
              weight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ),
        // Only the two that need naming carry a label, so the map doesn't
        // fill with text.
        if (isNext || _isKhata) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isKhata && !isNext
                  ? AppColors.warningBg
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: AppColors.text.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              isNext
                  ? '${stop.customerName} · '
                        '${Formatters.distance(stop.distanceMetres)}'
                  : 'khata',
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: _isKhata && !isNext
                    ? AppColors.warning
                    : AppColors.text,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The next stop docked at the bottom of the map — enough to ride to it
/// without switching back to the list.
class _MapStopSheet extends StatelessWidget {
  const _MapStopSheet({
    required this.stop,
    required this.onNavigate,
    required this.onCall,
  });

  final RunStop stop;
  final VoidCallback onNavigate;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.text.withValues(alpha: 0.14),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The grabber, so the panel reads as the sheet it is.
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.neutral300,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '1',
                style: AppTypography.body(
                  size: 16,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading(size: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stop.customerName} · ${stop.items} · '
                    '${stop.collectionLine}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              Formatters.distance(stop.distanceMetres),
              style: AppTypography.body(
                size: 13,
                weight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onNavigate,
                child: const Text('Navigate to stop 1'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded, size: 19),
              style: IconButton.styleFrom(
                minimumSize: const Size(56, 56),
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.accent,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The road grid the markers sit on.
///
/// Stands in for the Maps SDK exactly as [MapPlaceholder] does elsewhere;
/// this one is its own painter because the run map is full-bleed and needs
/// the route drawn between arbitrary stops rather than a single trip line.
class _MapTerrain extends StatelessWidget {
  const _MapTerrain();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _TerrainPainter(), child: const SizedBox.expand());
}

class _TerrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9EFE8),
    );

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final lane = Paint()
      ..color = const Color(0xFFDCE5DB)
      ..strokeWidth = 9;

    // A loose grid — enough structure for the route to look like streets.
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lane);
    }

    final block = Paint()..color = const Color(0xFFDFE8DE);
    for (var i = 0; i < 6; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * (0.05 + (i % 3) * 0.32),
            size.height * (0.08 + (i ~/ 3) * 0.46),
            size.width * 0.2,
            size.height * 0.12,
          ),
          const Radius.circular(4),
        ),
        block,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Joins the stops in run order.
///
/// Drawn as right angles rather than straight hops, so the path reads as a
/// route through streets instead of a set of flight lines.
class _RouteLinePainter extends CustomPainter {
  const _RouteLinePainter(this.stops);

  final List<RunStop> stops;

  Offset _resolve(RunStop stop, Size size) => Offset(
    (stop.plot!.x + 1) / 2 * size.width,
    (stop.plot!.y + 1) / 2 * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (stops.length < 2) return;

    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(_resolve(stops.first, size).dx, _resolve(stops.first, size).dy);
    for (var i = 1; i < stops.length; i++) {
      final from = _resolve(stops[i - 1], size);
      final to = _resolve(stops[i], size);
      // Turn the corner on whichever axis moves further, so the dog-leg
      // follows the longer street rather than always turning the same way.
      if ((to.dx - from.dx).abs() > (to.dy - from.dy).abs()) {
        path
          ..lineTo(to.dx, from.dy)
          ..lineTo(to.dx, to.dy);
      } else {
        path
          ..lineTo(from.dx, to.dy)
          ..lineTo(to.dx, to.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter oldDelegate) =>
      oldDelegate.stops != stops;
}
