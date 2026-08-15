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
    this.minQuantity = 0,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool compact;
  final int minQuantity;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 34.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            size: size,
            onTap: quantity > minQuantity ? onDecrement : null,
          ),
          SizedBox(
            width: compact ? 26 : 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: compact ? 14 : 15,
                weight: FontWeight.w700,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            size: size,
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
    this.onTap,
    this.emphasised = false,
  });

  final IconData icon;
  final double size;
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
            size: 17,
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
