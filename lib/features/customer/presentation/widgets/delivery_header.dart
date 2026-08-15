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
      22,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textMuted(0.55),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Deliver to',
                        style: AppTypography.body(
                          size: 12.5,
                          color: AppColors.textMuted(0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address?.shortLine ?? 'Choose an address',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 18,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more_rounded, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (onSearch != null) ...[
          _HeaderButton(icon: Icons.search_rounded, onTap: onSearch!),
          const SizedBox(width: AppSpacing.sm),
        ],
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
            dimension: 44,
            child: Icon(icon, size: 21, color: AppColors.text),
          ),
        ),
      ),
      // An unread dot, not a count — the design keeps the header quiet.
      if (badge > 0)
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: 2),
            ),
          ),
        ),
    ],
  );
}
