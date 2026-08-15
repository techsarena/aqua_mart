import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/domain/entities/order_status.dart';

/// One order in the seller's queue. The single primary button advances the
/// order: Accept → Packed → Sent → Done.
class OrderQueueCard extends ConsumerWidget {
  const OrderQueueCard({
    super.key,
    required this.order,
    required this.onAdvance,
    this.onDecline,
    this.showDecline = false,
  });

  final Order order;
  final VoidCallback onAdvance;
  final VoidCallback? onDecline;
  final bool showDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = order.status == OrderStatus.delivered;
    // Packed orders need a rider before they can go out.
    final needsRider = order.status == OrderStatus.packed;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.customerName} · ${order.address.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                Formatters.relative(order.placedAt),
                style: AppTypography.body(
                  size: 11.5,
                  color: AppColors.textMuted(0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.itemsSummary} · '
                  '${Formatters.rupees(order.total)} · '
                  '${order.paymentMethod.shortLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 12.5,
                    color: AppColors.textMuted(0.6),
                  ),
                ),
              ),
            ],
          ),
          if (order.rider != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTag(
              'With ${order.rider!.name}',
              tone: TagTone.accent,
              icon: Icons.two_wheeler_rounded,
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (showDecline && onDecline != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.dangerBg),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                flex: showDecline ? 1 : 2,
                child: FilledButton(
                  // Dispatching goes through rider selection, not straight
                  // to "sent" — someone has to actually carry it.
                  onPressed: isDone
                      ? null
                      : needsRider
                      ? () => context.pushNamed(
                          AppRoutes.assignRider,
                          pathParameters: {'orderId': order.id},
                        )
                      : onAdvance,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: isDone
                        ? AppColors.accent2_200
                        : AppColors.accent,
                    foregroundColor: isDone
                        ? AppColors.accent2_700
                        : Colors.white,
                    disabledBackgroundColor: AppColors.accent2_200,
                    disabledForegroundColor: AppColors.accent2_700,
                  ),
                  child: Text(
                    needsRider ? 'Send with…' : order.status.sellerActionLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
