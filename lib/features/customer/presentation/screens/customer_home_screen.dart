import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../addresses/domain/entities/address.dart';
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

  void _showAddressPicker(BuildContext context, Address? currentAddress) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _AddressPickerSheet(
        currentAddress: currentAddress,
        onSeeAll: () {
          Navigator.pop(sheetContext);
          context.pushNamed(AppRoutes.addressBook);
        },
        onAddAddress: () {
          Navigator.pop(sheetContext);
          context.pushNamed(AppRoutes.addAddress);
        },
      ),
    );
  }

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
    final selectedAddressId = ref.watch(deliveryAddressSelectionProvider);
    final currentLocation = ref.watch(currentLocationProvider).value;
    final currentAddress = currentLocation == null
        ? null
        : Address(
            id: 'current-location',
            label: AddressLabel.other,
            title: 'Current location',
            area: currentLocation.label,
            latitude: currentLocation.latitude,
            longitude: currentLocation.longitude,
          );
    final displayAddress = selectedAddressId == null
        ? currentAddress ?? address
        : address;
    final unread = ref.watch(unreadNotificationCountProvider);
    final usual = ref.watch(usualOrderProvider);

    // Without an address this used to sit on a loading spinner forever. The
    // shelf now falls back to every approved seller, so a customer who has
    // not saved an address still has something to order from.
    final sellersAsync = ref.watch(nearbySellersProvider(address?.id));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Pinned: where to, and how to find a seller ────────────────
            // Outside the scroll view so the address and search stay put —
            // both are how you change what the list below is showing.
            DeliveryHeader(
              address: displayAddress,
              unreadCount: unread,
              onAddressTap: () => _showAddressPicker(context, currentAddress),
            ),
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
                  ref.invalidate(nearbySellersProvider(address?.id));
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
                            nearbySellersProvider(address?.id),
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

class _AddressPickerSheet extends ConsumerWidget {
  const _AddressPickerSheet({
    required this.currentAddress,
    required this.onSeeAll,
    required this.onAddAddress,
  });

  final Address? currentAddress;
  final VoidCallback onSeeAll;
  final VoidCallback onAddAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressBookProvider);
    final selectedId = ref.watch(deliveryAddressSelectionProvider);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose delivery address',
                      style: AppTypography.heading(size: 24),
                    ),
                  ),
                  TextButton(onPressed: onSeeAll, child: const Text('See all')),
                ],
              ),
            ),
            Expanded(
              child: switch (addressesAsync) {
                AsyncLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncError() => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(addressBookProvider),
                    child: const Text('Try loading addresses again'),
                  ),
                ),
                AsyncValue(value: final addresses) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.lg,
                  ),
                  children: [
                    if (currentAddress != null) ...[
                      _AddressPickerRow(
                        icon: Icons.my_location_rounded,
                        title: 'Current location',
                        subtitle: currentAddress!.area,
                        selected: selectedId == null,
                        onTap: () {
                          ref
                              .read(deliveryAddressSelectionProvider.notifier)
                              .select(null);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final address in addresses ?? const <Address>[]) ...[
                      _AddressPickerRow(
                        icon: switch (address.label) {
                          AddressLabel.home => Icons.home_outlined,
                          AddressLabel.office => Icons.business_outlined,
                          AddressLabel.other => Icons.location_on_outlined,
                        },
                        title: address.title,
                        subtitle: address.shortLine,
                        selected:
                            selectedId == address.id ||
                            (currentAddress == null &&
                                selectedId == null &&
                                address.isDefault),
                        onTap: () {
                          ref
                              .read(deliveryAddressSelectionProvider.notifier)
                              .select(address.id);
                          ref.read(cartProvider.notifier).setAddress(address);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _AddressPickerRow(
                      icon: Icons.add_location_alt_outlined,
                      title: 'Add new address',
                      subtitle: 'Choose a location on the map',
                      onTap: onAddAddress,
                    ),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressPickerRow extends StatelessWidget {
  const _AddressPickerRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.onTint : AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 23,
              color: selected ? AppColors.accent : AppColors.neutral600,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13.5,
                      height: 1.3,
                      color: AppColors.textMuted(0.58),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.md),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    ),
  );
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
                    style: AppTypography.heading(size: 26, color: Colors.white),
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
      const SnackBar(
        content: Text("We'll notify you the moment one goes live."),
      ),
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
