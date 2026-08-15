import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/quantity_stepper.dart';
import '../../domain/entities/bottle.dart';

/// One bottle on a seller's shelf, with both prices offered side by side.
///
/// Each price carries its own stepper — the customer can take two refills and
/// one new bottle of the same size in a single order.
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

    return Opacity(
      opacity: unavailable ? 0.55 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SizeBadge(size: bottle.size),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bottle.name,
                        style: AppTypography.body(
                          size: 14.5,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _availabilityLine,
                        style: AppTypography.body(
                          size: 12,
                          color: bottle.isLowStock
                              ? AppColors.warning
                              : AppColors.textMuted(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _PriceOption(
              kind: PurchaseKind.refill,
              price: bottle.refillPrice,
              quantity: refillQuantity,
              enabled: !unavailable,
              onAdjust: (delta) => onAdjust(PurchaseKind.refill, delta),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PriceOption(
              kind: PurchaseKind.buyNew,
              price: bottle.newPrice,
              quantity: newQuantity,
              enabled: !unavailable,
              onAdjust: (delta) => onAdjust(PurchaseKind.buyNew, delta),
            ),
          ],
        ),
      ),
    );
  }

  String get _availabilityLine {
    if (bottle.isOutOfStock) return 'Out of stock';
    if (bottle.isLowStock) return 'Only ${bottle.filledStock} left';
    return bottle.description.isEmpty ? 'In stock' : bottle.description;
  }
}

class _SizeBadge extends StatelessWidget {
  const _SizeBadge({required this.size});

  final BottleSize size;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.accent100,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(
      size.label,
      style: AppTypography.body(
        size: 12.5,
        weight: FontWeight.w800,
        color: AppColors.accent700,
      ),
    ),
  );
}

class _PriceOption extends StatelessWidget {
  const _PriceOption({
    required this.kind,
    required this.price,
    required this.quantity,
    required this.enabled,
    required this.onAdjust,
  });

  final PurchaseKind kind;
  final int price;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.onTint : AppColors.neutral100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.accent : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: kind.label,
                    style: AppTypography.body(
                      size: 13.5,
                      weight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' · ${Formatters.rupees(price)}',
                    style: AppTypography.body(
                      size: 13.5,
                      color: AppColors.textMuted(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!enabled)
            Text(
              'Unavailable',
              style: AppTypography.body(
                size: 12,
                color: AppColors.textMuted(0.45),
              ),
            )
          else if (quantity == 0)
            TextButton(
              onPressed: () => onAdjust(1),
              style: TextButton.styleFrom(
                minimumSize: const Size(58, 34),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                backgroundColor: AppColors.surface,
                shape: const StadiumBorder(
                  side: BorderSide(color: AppColors.divider),
                ),
              ),
              child: const Text('Add'),
            )
          else
            QuantityStepper(
              quantity: quantity,
              compact: true,
              onIncrement: () => onAdjust(1),
              onDecrement: () => onAdjust(-1),
            ),
        ],
      ),
    );
  }
}
