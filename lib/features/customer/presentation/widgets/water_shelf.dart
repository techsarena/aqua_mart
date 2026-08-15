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
      SizedBox(
        height: 148,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bottles.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _ShelfBottleTile(
                    bottle: bottles[i],
                    selected: selectedIndices.contains(i),
                    onTap: bottles[i].level == ShelfLevel.empty
                        ? () => onToggle(i)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      // The shelf plank the bottles stand on.
      Container(
        height: 5,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: AppColors.neutral300,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      if (daysRemaining != null) ...[
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.trending_down_rounded,
              size: 15,
              color: AppColors.textMuted(0.45),
            ),
            const SizedBox(width: 6),
            Text(
              'Runs out in ~$daysRemaining days',
              style: AppTypography.body(size: 12.5, weight: FontWeight.w700),
            ),
            const SizedBox(width: 5),
            Text(
              'based on your use',
              style: AppTypography.body(
                size: 12,
                color: AppColors.textMuted(0.5),
              ),
            ),
          ],
        ),
      ],
    ],
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

  @override
  Widget build(BuildContext context) {
    final isEmpty = bottle.level == ShelfLevel.empty;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                  bottom: Radius.circular(8),
                ),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.neutral300,
                  width: selected ? 2 : 1.2,
                ),
              ),
              child: Stack(
                children: [
                  // The water itself, filling from the bottom.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: bottle.level.fill.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accent300.withValues(alpha: 0.85),
                              AppColors.accent400,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                            bottom: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottle neck.
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 20,
                      height: 12,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent
                            : AppColors.neutral300,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  if (isEmpty)
                    Center(
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.touch_app_outlined,
                        size: 20,
                        color: selected
                            ? AppColors.accent
                            : AppColors.textMuted(0.35),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEmpty && onTap != null && !selected
                ? 'Empty · tap'
                : '${bottle.level.label} · ${bottle.litres}L',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 10.5,
              weight: FontWeight.w700,
              color: selected ? AppColors.accent : AppColors.textMuted(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
