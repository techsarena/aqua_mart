import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';

/// Initials avatar — `IA` for Imran Ali. Falls back to initials when there is
/// no photo, which in this app is always.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.background,
    this.foreground,
    this.imageUrl,
  });

  final String name;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background ?? AppColors.accent100,
      shape: BoxShape.circle,
      image: imageUrl != null
          ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
          : null,
    ),
    child: imageUrl != null
        ? null
        : Text(
            Formatters.initials(name),
            style: AppTypography.body(
              size: size * 0.34,
              weight: FontWeight.w800,
              color: foreground ?? AppColors.accent700,
            ),
          ),
  );
}

/// The circular seller/brand badge shown on list rows.
class SellerAvatar extends StatelessWidget {
  const SellerAvatar({super.key, this.size = 48, this.isOpen = true});

  final double size;
  final bool isOpen;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: isOpen
          ? AppColors.brandGradient
          : const LinearGradient(
              colors: [AppColors.neutral300, AppColors.neutral400],
            ),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Icon(
      Icons.water_drop_rounded,
      size: size * 0.46,
      color: Colors.white.withValues(alpha: isOpen ? 1 : 0.75),
    ),
  );
}
