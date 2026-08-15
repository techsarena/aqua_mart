import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// The round white back button used on every screen that runs its own header
/// instead of an [AppBar] — the seller shelf, the cart, the address picker.
class BackDiscButton extends StatelessWidget {
  const BackDiscButton({super.key, this.onPressed});

  /// Defaults to popping the current route.
  final VoidCallback? onPressed;

  static const double diameter = 40;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed ?? () => context.pop(),
      child: const SizedBox(
        width: diameter,
        height: diameter,
        child: Icon(Icons.chevron_left_rounded, size: 26),
      ),
    ),
  );
}
