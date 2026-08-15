import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/bottle.dart';

/// One bottle on a seller's shelf, with both prices offered side by side.
///
/// Tapping a price adds one of that kind; the badge on the right counts
/// everything taken from this card. Taking one back happens in the cart, so
/// the shelf stays a single-tap surface.
class BottleRow extends StatelessWidget {
  const BottleRow({
    super.key,
    required this.bottle,
    required this.refillQuantity,
    required this.newQuantity,
    required this.onAdjust,
  });

  final Bottle bottle;
  final int refillQuantity;
  final int newQuantity;
  final void Function(PurchaseKind kind, int delta) onAdjust;

  @override
  Widget build(BuildContext context) {
    final unavailable = bottle.isOutOfStock;
    final total = refillQuantity + newQuantity;

    return Opacity(
      opacity: unavailable ? 0.55 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BottleGlyph(size: bottle.size),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bottle.name,
                        style: AppTypography.heading(size: 19),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _availabilityLine,
                        style: AppTypography.body(
                          size: 13.5,
                          color: bottle.isLowStock
                              ? AppColors.warning
                              : AppColors.textMuted(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                // The running count for this bottle, in the corner where the
                // eye lands after reading the name.
                if (total > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _CountBadge(count: total),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _PriceButton(
                    kind: PurchaseKind.refill,
                    price: bottle.refillPrice,
                    filled: true,
                    enabled: !unavailable,
                    onTap: () => onAdjust(PurchaseKind.refill, 1),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _PriceButton(
                    kind: PurchaseKind.buyNew,
                    price: bottle.newPrice,
                    filled: false,
                    enabled: !unavailable,
                    onTap: () => onAdjust(PurchaseKind.buyNew, 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _availabilityLine {
    if (bottle.isOutOfStock) return 'Out of stock';
    if (bottle.isLowStock) return '${bottle.description} · ${bottle.filledStock} left';
    return bottle.description.isEmpty
        ? 'In stock'
        : '${bottle.description} · in stock';
  }
}

/// A bottle drawn as a bottle — body, neck cap, and the size inside it.
class _BottleGlyph extends StatelessWidget {
  const _BottleGlyph({required this.size});

  final BottleSize size;

  /// The 25L cooler bottle is drawn taller than the handheld sizes.
  double get _height => switch (size) {
    BottleSize.twentyFive => 92,
    BottleSize.ten => 82,
    BottleSize.six => 72,
  };

  double get _width => switch (size) {
    BottleSize.twentyFive => 68,
    BottleSize.ten => 60,
    BottleSize.six => 52,
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _width,
    height: _height + 10,
    child: Column(
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
        Expanded(
          child: Container(
            width: _width,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.accent2_200,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              size.label,
              style: AppTypography.body(
                size: 12.5,
                weight: FontWeight.w800,
                color: AppColors.accent2Deep,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.accent,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$count',
      style: AppTypography.body(
        size: 17,
        weight: FontWeight.w800,
        color: AppColors.surface,
      ),
    ),
  );
}

/// One of the two prices, as a full-height pill. Refill is the filled,
/// recommended one; buy new is the quieter outline beside it.
class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.kind,
    required this.price,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final PurchaseKind kind;
  final int price;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${kind.label} · ${Formatters.rupees(price)}';

    return Material(
      color: filled ? AppColors.accent : AppColors.surface,
      shape: StadiumBorder(
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.neutral300),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            enabled ? label : 'Unavailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 16,
              weight: FontWeight.w700,
              color: filled ? AppColors.surface : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
