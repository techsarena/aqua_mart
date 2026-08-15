import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// How full one bottle on the shelf is.
enum ShelfLevel {
  full('Full', 1),
  half('Half', 0.5),
  empty('Empty', 0);

  const ShelfLevel(this.label, this.fill);

  final String label;
  final double fill;
}

class ShelfBottle {
  const ShelfBottle({required this.level, required this.litres, this.id});

  final ShelfLevel level;
  final int litres;
  final String? id;
}

/// "Your water shelf" — the home screen rebuilt around what the customer
/// already has, rather than a catalogue.
///
/// Tapping an empty selects it to send back for a refill, which is what
/// "reorder" means in this app.
class WaterShelf extends StatelessWidget {
  const WaterShelf({
    super.key,
    required this.bottles,
    required this.selectedIndices,
    required this.onToggle,
    this.daysRemaining,
  });

  final List<ShelfBottle> bottles;
  final Set<int> selectedIndices;
  final ValueChanged<int> onToggle;

  /// "Runs out in ~3 days · based on your use"
  final int? daysRemaining;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // A four-up grid of bottles, each on the .6 aspect ratio of the spec.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < bottles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _ShelfBottleTile(
                bottle: bottles[i],
                selected: selectedIndices.contains(i),
                onTap: bottles[i].level == ShelfLevel.empty
                    ? () => onToggle(i)
                    : null,
              ),
            ),
          ],
        ],
      ),
      if (daysRemaining != null) ...[
        const SizedBox(height: 22),
        _RunsOutPanel(days: daysRemaining!, fraction: 0.34),
      ],
    ],
  );
}

/// "Runs out in ~3 days · from your usage" — the teal panel with the gauge.
class _RunsOutPanel extends StatelessWidget {
  const _RunsOutPanel({required this.days, required this.fraction});

  final int days;
  final double fraction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.accent2_100,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Runs out in ~$days days',
                style: AppTypography.heading(size: 18),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'from your usage',
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.accent2Deep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: 0.6),
            valueColor: const AlwaysStoppedAnimation(AppColors.accent2),
          ),
        ),
      ],
    ),
  );
}

class _ShelfBottleTile extends StatelessWidget {
  const _ShelfBottleTile({
    required this.bottle,
    required this.selected,
    this.onTap,
  });

  final ShelfBottle bottle;
  final bool selected;
  final VoidCallback? onTap;

  /// The bottle body: a solid teal vessel, or a dashed outline when empty.
  ///
  /// `14px 14px 18px 18px` in the spec — the shoulders are tighter than the
  /// base, which is what reads as a bottle rather than a bar.
  static const _shape = BorderRadius.vertical(
    top: Radius.circular(14),
    bottom: Radius.circular(18),
  );

  @override
  Widget build(BuildContext context) {
    final isEmpty = bottle.level == ShelfLevel.empty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.6,
            child: isEmpty
                ? _EmptyBottle(selected: selected)
                : _FilledBottle(level: bottle.level),
          ),
          const SizedBox(height: 7),
          Text(
            bottle.level.label,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 11.5,
              weight: FontWeight.w700,
              color: switch (bottle.level) {
                ShelfLevel.full => AppColors.shelfFullLabel,
                ShelfLevel.half => AppColors.neutral600,
                ShelfLevel.empty => AppColors.accent700,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A bottle with water in it — solid teal, with the ground showing through
/// the top portion when it is only half full.
class _FilledBottle extends StatelessWidget {
  const _FilledBottle({required this.level});

  final ShelfLevel level;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    fit: StackFit.expand,
    children: [
      ClipRRect(
        borderRadius: _ShelfBottleTile._shape,
        // The whole vessel stays visible as a pale tint; the water fills it
        // from the base up, so a half bottle keeps its full silhouette.
        child: ColoredBox(
          color: AppColors.accent2_200,
          child: Column(
            children: [
              // A full bottle has no airspace, so that flex child is dropped
              // entirely — `Expanded` requires a flex of at least 1.
              if (level.fill < 1)
                Expanded(
                  flex: ((1 - level.fill) * 100).round(),
                  child: const SizedBox.expand(),
                ),
              if (level.fill > 0)
                Expanded(
                  flex: (level.fill * 100).round(),
                  child: const ColoredBox(
                    color: AppColors.accent2_300,
                    child: SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
      const _BottleNeck(),
    ],
  );
}

/// An empty bottle — a dashed accent outline with the refill glyph, and the
/// affordance that it is the one thing on the shelf you can tap.
class _EmptyBottle extends StatelessWidget {
  const _EmptyBottle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: double.infinity,
    decoration: BoxDecoration(
      color: selected ? AppColors.accent100 : Colors.transparent,
      borderRadius: _ShelfBottleTile._shape,
    ),
    child: CustomPaint(
      painter: _DashedBottlePainter(
        color: AppColors.accent,
        strokeWidth: 2.5,
      ),
      child: Center(
        child: Icon(
          selected ? Icons.check_rounded : Icons.refresh_rounded,
          size: 22,
          color: AppColors.accent,
        ),
      ),
    ),
  );
}

/// The moulded cap every bottle carries, sitting proud of the shoulders.
class _BottleNeck extends StatelessWidget {
  const _BottleNeck();

  @override
  Widget build(BuildContext context) => Positioned(
    top: -7,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        width: 19,
        height: 11,
        decoration: BoxDecoration(
          color: AppColors.accent2_500,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    ),
  );
}

/// Strokes the bottle silhouette as a dashed line.
class _DashedBottlePainter extends CustomPainter {
  const _DashedBottlePainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  static const _dash = 6.0;
  static const _gap = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(
      _ShelfBottleTile._shape
          .toRRect(Offset.zero & size)
          .deflate(strokeWidth / 2),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(d, (d + _dash).clamp(0.0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBottlePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
