import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../orders/presentation/providers/cart_providers.dart';
import '../../domain/entities/bottle.dart';
import '../../domain/entities/seller.dart';
import '../providers/catalog_providers.dart';
import '../widgets/bottle_row.dart';

/// One seller's storefront: their bottles, each with a refill price and a
/// buy-new price side by side so the customer picks one.
class SellerStoreScreen extends ConsumerWidget {
  const SellerStoreScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(sellerProvider(sellerId));
    final bottlesAsync = ref.watch(sellerBottlesProvider(sellerId));
    final cart = ref.watch(cartProvider);

    return Scaffold(
      body: switch (sellerAsync) {
        AsyncLoading() => const _StoreSkeleton(),
        AsyncError(:final error) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            failure: asFailure(error),
            onRetry: () => ref.invalidate(sellerProvider(sellerId)),
          ),
        ),
        AsyncValue(value: final seller) when seller != null => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 168,
              backgroundColor: AppColors.bg,
              flexibleSpace: FlexibleSpaceBar(
                background: _StoreHeader(seller: seller),
                collapseMode: CollapseMode.parallax,
              ),
              title: Text(
                seller.name,
                style: AppTypography.heading(size: 17),
              ),
            ),
            SliverToBoxAdapter(child: _RefillExplainer()),
            switch (bottlesAsync) {
              AsyncLoading() => const SliverToBoxAdapter(
                child: SkeletonList(itemCount: 3, itemHeight: 108),
              ),
              AsyncError(:final error) => SliverToBoxAdapter(
                child: ErrorView(failure: asFailure(error)),
              ),
              AsyncValue(value: final bottles) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                sliver: SliverList.separated(
                  itemCount: bottles?.length ?? 0,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final bottle = bottles![i];
                    return BottleRow(
                      bottle: bottle,
                      refillQuantity: cart.quantityOfKind(
                        bottle.id,
                        PurchaseKind.refill,
                      ),
                      newQuantity: cart.quantityOfKind(
                        bottle.id,
                        PurchaseKind.buyNew,
                      ),
                      onAdjust: (kind, delta) => ref
                          .read(cartProvider.notifier)
                          .adjust(
                            bottle: bottle,
                            kind: kind,
                            sellerName: seller.name,
                            delta: delta,
                          ),
                    );
                  },
                ),
              ),
            },
          ],
        ),
        _ => const SizedBox.shrink(),
      },
      bottomNavigationBar: cart.isEmpty
          ? null
          : StickyCartBar(
              count: cart.bottleCount,
              total: Formatters.rupees(cart.subtotal),
              label: 'View order',
              onPressed: () => context.pushNamed(AppRoutes.cart),
            ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      MediaQuery.paddingOf(context).top + 56,
      AppSpacing.gutter,
      AppSpacing.lg,
    ),
    alignment: Alignment.bottomLeft,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SellerAvatar(size: 56, isOpen: seller.isOpen),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  RatingChip(seller.rating, count: seller.ratingCount, compact: false),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: AppColors.textMuted(0.5),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    Formatters.eta(seller.etaMinutes),
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.6),
                    ),
                  ),
                ],
              ),
              if (seller.freeDeliveryOver != null) ...[
                const SizedBox(height: 6),
                AppTag(
                  seller.freeDeliveryOver == 0
                      ? 'Free delivery'
                      : 'Free over ${Formatters.rupees(seller.freeDeliveryOver!)}',
                  tone: TagTone.accent2,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// The design spells out what refill and buy-new actually mean — the single
/// most confusable idea in the app.
class _RefillExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      0,
      AppSpacing.gutter,
      AppSpacing.lg,
    ),
    child: AppCard(
      color: AppColors.accent100,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final kind in PurchaseKind.values)
            Padding(
              padding: EdgeInsets.only(
                bottom: kind == PurchaseKind.values.last ? 0 : 5,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: kind.label,
                      style: AppTypography.body(
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: AppColors.accent800,
                      ),
                    ),
                    TextSpan(
                      text: ' = ${kind.explainer}.',
                      style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.accent800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Padding(
      padding: EdgeInsets.only(top: AppSpacing.lg),
      child: SkeletonList(itemCount: 3, itemHeight: 108),
    ),
  );
}
