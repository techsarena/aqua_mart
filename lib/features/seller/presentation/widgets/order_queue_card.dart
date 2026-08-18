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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading(size: 17),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.relative(order.placedAt),
                style: AppTypography.body(
                  size: 12.5,
                  color: AppColors.textMuted(0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Area · items · payment. The payment method carries the accent tint
          // so it reads apart from the two neutral facts beside it.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // The saved area is a full geocoded line; the chip shows the
              // neighbourhood so the row stays one line per fact.
              AppTag(Formatters.areaLabel(order.address.area)),
              AppTag(order.itemsSummary),
              AppTag(order.paymentMethod.shortLabel, tone: TagTone.accent),
            ],
          ),
          if (order.rider != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTag(
              'With ${order.rider!.name}',
              tone: TagTone.accent2,
              icon: Icons.two_wheeler_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.rupees(order.total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.heading(size: 21),
                ),
              ),
              if (showDecline && onDecline != null) ...[
                TextButton(
                  onPressed: onDecline,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              FilledButton(
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
                  minimumSize: const Size(126, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  textStyle: AppTypography.body(
                    size: 15,
                    weight: FontWeight.w700,
                  ),
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
            ],
          ),
        ],
      ),
    );
  }
}
