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
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../catalog/presentation/widgets/seller_card.dart';
import '../../../orders/domain/entities/order.dart';
import '../../../orders/presentation/providers/cart_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../widgets/delivery_header.dart';

/// The customer's home: where you are, what you last ordered, and who can
/// deliver to you.
///
/// "Your usual" is the whole point of the screen — a repeat customer should
/// never have to browse, so the last order sits above the seller list as a
/// one-tap reorder.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  /// Puts the previous order back in the cart and opens it for review.
  void _reorder(BuildContext context, WidgetRef ref, Order usual) {
    ref
        .read(cartProvider.notifier)
        .loadLines(
          sellerId: usual.sellerId,
          sellerName: usual.sellerName,
          lines: usual.lines,
        );
    context.pushNamed(AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(selectedAddressProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final usual = ref.watch(usualOrderProvider);

    final sellersAsync = address == null
        ? const AsyncValue<List<dynamic>>.loading()
        : ref.watch(nearbySellersProvider(address.id));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Pinned: where to, and how to find a seller ────────────────
            // Outside the scroll view so the address and search stay put —
            // both are how you change what the list below is showing.
            DeliveryHeader(address: address, unreadCount: unread),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              child: _SearchBar(
                onTap: () => context.pushNamed(AppRoutes.searchResults),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(addressBookProvider);
                  if (address != null) {
                    ref.invalidate(nearbySellersProvider(address.id));
                  }
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    // ── Your usual ──────────────────────────────────────────
                    if (usual != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter,
                        ),
                        child: _UsualOrderCard(
                          usual: usual,
                          onReorder: () => _reorder(context, ref, usual),
                        ),
                      ),

                    // ── Sellers near you ────────────────────────────────────
                    AppSection(
                      title: 'Sellers near you',
                      actionLabel: 'Map view',
                      onAction: () => context.pushNamed(AppRoutes.sellerMap),
                      child: switch (sellersAsync) {
                        AsyncLoading() => const SkeletonList(),
                        AsyncError(:final error) => ErrorView(
                          failure: asFailure(error),
                          onRetry: () => ref.invalidate(
                            nearbySellersProvider(address!.id),
                          ),
                        ),
                        AsyncValue(value: final sellers) =>
                          (sellers?.isEmpty ?? true)
                              ? _NoSellersHere(
                                  area: address?.area ?? 'this area',
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.gutter,
                                  ),
                                  child: Column(
                                    children: [
                                      for (final seller in sellers!) ...[
                                        SellerCard(
                                          seller: seller,
                                          highlight: seller.isRegular
                                              ? 'Your regular'
                                              : null,
                                          onTap: () => context.pushNamed(
                                            AppRoutes.sellerStore,
                                            pathParameters: {
                                              'sellerId': seller.id,
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                      ],
                                    ],
                                  ),
                                ),
                      },
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
}

/// The search field. A button rather than an input — tapping opens the search
/// screen, which owns the actual text field and its results.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 17,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.textMuted(0.45),
            ),
            const SizedBox(width: AppSpacing.md),
            // Expanded so the placeholder ellipsizes on narrow phones and at
            // large text scales rather than overflowing the pill.
            Expanded(
              child: Text(
                'Search sellers or bottle size',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 15.5,
                  color: AppColors.textMuted(0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Your usual" — the last delivered order, reorderable in one tap.
///
/// The only dark panel on the screen, so it carries the most weight: a repeat
/// customer's whole journey is meant to end at this button.
class _UsualOrderCard extends StatelessWidget {
  const _UsualOrderCard({required this.usual, required this.onReorder});

  final Order usual;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR USUAL',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    usual.itemsSummary,
                    style: AppTypography.heading(
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${usual.sellerName} · '
                    '${Formatters.rupees(usual.total)} · '
                    '${Formatters.eta(usual.etaMinutes)}',
                    style: AppTypography.body(
                      size: 14.5,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // A quiet echo of the reorder action, tinted into the panel.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.replay_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: onReorder,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.accent700,
          ),
          child: const Text('Reorder in one tap'),
        ),
      ],
    ),
  );
}

/// "No sellers here yet" — the unhappy path when an address is out of coverage.
class _NoSellersHere extends StatelessWidget {
  const _NoSellersHere({required this.area});

  final String area;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.location_off_rounded,
    title: 'No sellers here yet',
    message:
        'Nobody delivers to $area right now. '
        "We're signing up plants every week.",
    primaryLabel: 'Tell me when someone does',
    onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("We'll notify you the moment one goes live.")),
    ),
    secondaryLabel: 'Try a different address',
    onSecondary: () => context.pushNamed(AppRoutes.addressBook),
    footer: AppNote(
      icon: Icons.handshake_outlined,
      text: '',
      richText: TextSpan(
        children: [
          const TextSpan(text: 'Know a water plant nearby? Tell them about '),
          const TextSpan(
            text: 'Aqua Mart',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: ' — you both get '),
          const TextSpan(
            text: 'Rs 200',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    ),
  );
}
