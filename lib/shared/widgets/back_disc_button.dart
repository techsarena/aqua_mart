import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// The round white back button used on every screen that runs its own header
/// instead of an [AppBar] — the seller shelf, the cart, the address picker.
class BackDiscButton extends StatelessWidget {
  const BackDiscButton({super.key, this.onPressed, this.size = diameter});

  /// Defaults to popping the current route.
  final VoidCallback? onPressed;

  /// Headers that set their own title size want a disc to match it.
  final double size;

  static const double diameter = 40;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed ?? () => context.pop(),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.chevron_left_rounded, size: size * 0.65),
      ),
    ),
  );
}
