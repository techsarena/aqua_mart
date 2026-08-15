import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// `−  2  +` — the control on every bottle row.
///
/// Collapses to a single "Add" affordance when the quantity is zero so the
/// bottle list stays quiet until the customer engages with it.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.compact = false,
    this.large = false,
    this.minQuantity = 0,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool compact;

  /// The cart's roomier pill — bigger targets, both signs in accent, no
  /// border. Used where the row is the thing being edited.
  final bool large;

  final int minQuantity;

  @override
  Widget build(BuildContext context) {
    final size = large
        ? 44.0
        : compact
        ? 30.0
        : 34.0;

    return Container(
      decoration: BoxDecoration(
        color: large ? AppColors.accent100 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(999),
        border: large ? null : Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            size: size,
            iconSize: large ? 24 : 17,
            onTap: quantity > minQuantity ? onDecrement : null,
            emphasised: large,
          ),
          SizedBox(
            width: large
                ? 34
                : compact
                ? 26
                : 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: large
                    ? 19
                    : compact
                    ? 14
                    : 15,
                weight: FontWeight.w700,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            size: size,
            iconSize: large ? 24 : 17,
            onTap: onIncrement,
            emphasised: true,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.size,
    this.iconSize = 17,
    this.onTap,
    this.emphasised = false,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            icon,
            size: iconSize,
            color: !enabled
                ? AppColors.neutral400
                : emphasised
                ? AppColors.accent
                : AppColors.text,
          ),
        ),
      ),
    );
  }
}
