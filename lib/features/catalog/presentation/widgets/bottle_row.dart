import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/bottle_glyph.dart';
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
                BottleGlyph(size: bottle.size),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bottle.name, style: AppTypography.heading(size: 19)),
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
    if (bottle.isLowStock) {
      return '${bottle.description} · ${bottle.filledStock} left';
    }
    return bottle.description.isEmpty
        ? 'In stock'
        : '${bottle.description} · in stock';
  }
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
