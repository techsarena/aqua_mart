import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import 'app_avatar.dart';

/// The signed-in user's face, sized for the "Me" slot in a [NavigationBar].
///
/// The bar's icon slot is 25px tall, so the avatar is drawn just inside that
/// and the selected state is carried by a ring rather than a filled icon —
/// there is no outlined/filled pair to swap between for a photo.
class NavAvatar extends ConsumerWidget {
  const NavAvatar({super.key, this.isSelected = false});

  final bool isSelected;

  static const double _diameter = 26;
  static const double _ring = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Container(
      padding: const EdgeInsets.all(_ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.accent : Colors.transparent,
          width: _ring,
        ),
      ),
      child: AppAvatar(
        name: user?.fullName ?? 'You',
        imageUrl: user?.avatarUrl,
        size: _diameter,
        background: AppColors.accent2_200,
        foreground: AppColors.accent2Deep,
      ),
    );
  }
}
