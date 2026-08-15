import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/back_disc_button.dart';
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
              expandedHeight: _CollapsingStoreHeader.expandedHeight,
              backgroundColor: AppColors.accent2_200,
              automaticallyImplyLeading: false,
              flexibleSpace: _CollapsingStoreHeader(seller: seller),
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

/// The header as it collapses: the tall band fades out on scroll and the
/// compact bar — back arrow and store name on one line — fades in behind it.
///
/// The two never show at once, so the name is never drawn twice.
class _CollapsingStoreHeader extends StatelessWidget {
  const _CollapsingStoreHeader({required this.seller});

  final Seller seller;

  /// Tall enough for the back button, the 34pt name and the chip row.
  static const expandedHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topPadding + kToolbarHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 1 fully expanded → 0 fully collapsed.
        final range = expandedHeight - collapsedHeight;
        final t = range <= 0
            ? 0.0
            : ((constraints.maxHeight - collapsedHeight) / range).clamp(
                0.0,
                1.0,
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            // The compact bar leads the swap so the name is legible before
            // the big header has finished going.
            IgnorePointer(
              ignoring: t > 0.25,
              child: Opacity(
                opacity: (1 - t * 4).clamp(0.0, 1.0),
                child: _CompactStoreBar(seller: seller),
              ),
            ),
            IgnorePointer(
              ignoring: t < 0.25,
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: _StoreHeader(seller: seller),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The pinned bar once the band is gone.
class _CompactStoreBar extends StatelessWidget {
  const _CompactStoreBar({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.accent2_200,
    padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
    alignment: Alignment.topLeft,
    child: SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.gutter),
          const BackDiscButton(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              seller.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading(size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
        ],
      ),
    ),
  );
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.seller});

  final Seller seller;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.accent2_200,
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      MediaQuery.paddingOf(context).top + AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        const BackDiscButton(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          seller.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.heading(size: 34),
        ),
        const SizedBox(height: AppSpacing.md),
        // Rating, ETA and delivery terms as one uniform row of facts.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _HeaderChip(
              label:
                  '${seller.rating.toStringAsFixed(1)} (${seller.ratingCount})',
              icon: Icons.star_rounded,
              iconColor: AppColors.text,
            ),
            _HeaderChip(label: Formatters.eta(seller.etaMinutes)),
            if (seller.freeDeliveryOver != null)
              _HeaderChip(
                label: seller.freeDeliveryOver == 0
                    ? 'Free delivery'
                    : 'Free over ${Formatters.rupees(seller.freeDeliveryOver!)}',
              ),
          ],
        ),
      ],
    ),
  );
}

/// One white fact pill in the store header.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, this.icon, this.iconColor});

  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor ?? AppColors.text),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: AppTypography.body(size: 14, weight: FontWeight.w700),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: AppColors.accent800,
          ),
          const SizedBox(width: AppSpacing.md),
          // Both definitions run as one paragraph — they are two halves of a
          // single distinction, and reading them together is the point.
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  for (final kind in PurchaseKind.values) ...[
                    TextSpan(
                      text: kind.label,
                      style: AppTypography.body(
                        size: 15,
                        weight: FontWeight.w800,
                        color: AppColors.accent800,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' = ${kind.explainer}.'
                          '${kind == PurchaseKind.values.last ? '' : ' '}',
                      style: AppTypography.body(
                        size: 15,
                        color: AppColors.accent800,
                      ),
                    ),
                  ],
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
