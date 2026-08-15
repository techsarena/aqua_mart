import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../addresses/domain/entities/address.dart';

/// "Deliver to · House 42-B, Gulberg III" plus the search and alerts actions.
///
/// Tapping the address opens the address book — the design's note that
/// "Change" finally goes somewhere.
class DeliveryHeader extends StatelessWidget {
  const DeliveryHeader({
    super.key,
    required this.address,
    this.unreadCount = 0,
    this.onSearch,
  });

  final Address? address;
  final int unreadCount;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.md,
    ),
    child: Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => context.pushNamed(AppRoutes.addressBook),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliver to',
                    style: AppTypography.body(
                      size: 11,
                      weight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.textMuted(0.5),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address?.shortLine ?? 'Choose an address',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 15,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 19,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _HeaderButton(
          icon: Icons.search_rounded,
          onTap: onSearch ?? () => context.pushNamed(AppRoutes.searchResults),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderButton(
          icon: Icons.notifications_none_rounded,
          badge: unreadCount,
          onTap: () => context.pushNamed(AppRoutes.notifications),
        ),
      ],
    ),
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(icon, size: 21, color: AppColors.text),
          ),
        ),
      ),
      if (badge > 0)
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.bg, width: 1.5),
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 9.5,
                weight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
    ],
  );
}
