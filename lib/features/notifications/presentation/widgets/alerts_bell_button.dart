import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/notification_providers.dart';

/// The alerts bell, on the white disc the seller header uses for its round
/// controls. Carries a dot while anything is unread.
class AlertsBellButton extends ConsumerWidget {
  const AlertsBellButton({super.key, required this.routeName, this.size = 44});

  /// The alerts route for the current role.
  final String routeName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => context.pushNamed(routeName),
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.notifications_none_rounded,
                size: size * 0.5,
                color: AppColors.text,
              ),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                // Rings the dot so it stays legible against the white disc.
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
