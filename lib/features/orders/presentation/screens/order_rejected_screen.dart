import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../catalog/domain/entities/seller.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../providers/order_providers.dart';

/// The seller couldn't take the order. Rather than a dead end, this offers the
/// sellers who can do it right now — priced against the original order.
class OrderRejectedScreen extends ConsumerWidget {
  const OrderRejectedScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId)).value;
    final address = ref.watch(selectedAddressProvider);
    final alternatives =
        ref
            .watch(nearbySellersProvider(address?.id))
            .value
            ?.where((s) => s.id != order?.sellerId && s.isOpen)
            .take(2)
            .toList() ??
        const <Seller>[];

    final cheapest = alternatives.isEmpty
        ? null
        : alternatives.reduce(
            (a, b) =>
                (a.cheapestRefillPrice ?? 9999) <=
                    (b.cheapestRefillPrice ?? 9999)
                ? a
                : b,
          );

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.dangerBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.remove_shopping_cart_outlined,
              size: 30,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${order?.sellerName ?? 'The seller'} couldn\'t take your order',
            style: AppTypography.heading(size: 25),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order?.rejectionReason ?? 'They ran out of 25L bottles.',
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.65),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppNote.positive(
            text: '',
            richText: const TextSpan(
              children: [
                TextSpan(
                  text: "You haven't been charged",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: ' — you paid nothing, and no cash is owed.'),
              ],
            ),
          ),

          if (order != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Order #${order.reference} · ${Formatters.time(order.placedAt)}',
              style: AppTypography.body(
                size: 12,
                color: AppColors.textMuted(0.45),
              ),
            ),
          ],

          if (alternatives.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              '${alternatives.length} sellers can do it now',
              style: AppTypography.body(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final seller in alternatives) ...[
              _AlternativeCard(
                seller: seller,
                originalTotal: order?.total,
                isCheapest: seller.id == cheapest?.id,
                onTap: () => context.pushNamed(
                  AppRoutes.sellerStore,
                  pathParameters: {'sellerId': seller.id},
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
      bottomNavigationBar: cheapest == null
          ? null
          : StickyActionBar(
              label:
                  'Order from ${cheapest.name.split(' ').first} · '
                  '${Formatters.rupees(cheapest.cheapestRefillPrice ?? 0)}',
              onPressed: () => context.pushNamed(
                AppRoutes.sellerStore,
                pathParameters: {'sellerId': cheapest.id},
              ),
              secondaryLabel: 'Not now',
              onSecondary: () => context.goNamed(AppRoutes.customerHome),
            ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.seller,
    required this.onTap,
    this.originalTotal,
    this.isCheapest = false,
  });

  final Seller seller;
  final VoidCallback onTap;
  final int? originalTotal;
  final bool isCheapest;

  @override
  Widget build(BuildContext context) {
    final price = seller.cheapestRefillPrice ?? 0;
    final saving = originalTotal == null ? null : originalTotal! - price;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SellerAvatar(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seller.name,
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.rupees(price)} · '
                  '${Formatters.eta(seller.etaMinutes)}',
                  style: AppTypography.body(
                    size: 12.5,
                    color: AppColors.textMuted(0.6),
                  ),
                ),
                if (isCheapest && saving != null && saving > 0) ...[
                  const SizedBox(height: 6),
                  AppTag(
                    '${Formatters.rupees(saving)} cheaper than your order',
                    tone: TagTone.accent2,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.neutral400),
        ],
      ),
    );
  }
}
