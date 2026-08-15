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
import '../../../catalog/domain/entities/bottle.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../catalog/presentation/widgets/seller_card.dart';
import '../../../orders/presentation/providers/cart_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../widgets/delivery_header.dart';
import '../widgets/water_shelf.dart';

/// The customer's home, built around the water shelf.
///
/// Reorder is expressed as "send my empties back" — the shelf is what the
/// customer already has, and tapping an empty starts a refill.
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  /// Which empties on the shelf are selected for a refill run.
  final _selectedEmpties = <int>{};

  static const _shelf = [
    ShelfBottle(level: ShelfLevel.full, litres: 25),
    ShelfBottle(level: ShelfLevel.half, litres: 25),
    ShelfBottle(level: ShelfLevel.empty, litres: 25),
    ShelfBottle(level: ShelfLevel.empty, litres: 25),
  ];

  /// The refill price for the customer's regular seller.
  static const _refillPrice = 110;

  void _sendEmpties() {
    final bottles = ref.read(sellerBottlesProvider('s-1')).value;
    if (bottles == null || bottles.isEmpty) return;

    final bottle = bottles.firstWhere(
      (b) => b.size.litres == 25,
      orElse: () => bottles.first,
    );

    ref
        .read(cartProvider.notifier)
        .adjust(
          bottle: bottle,
          kind: PurchaseKind.refill,
          sellerName: 'Chashma Pure Water',
          delta: _selectedEmpties.length,
        );
    context.pushNamed(AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final usual = ref.watch(usualOrderProvider);

    // Preload the regular seller's bottles so "send empties" is instant.
    ref.watch(sellerBottlesProvider('s-1'));

    final sellersAsync = address == null
        ? const AsyncValue<List<dynamic>>.loading()
        : ref.watch(nearbySellersProvider(address.id));

    return Scaffold(
      body: SafeArea(
        bottom: false,
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
              DeliveryHeader(address: address, unreadCount: unread),

              // ── The shelf ───────────────────────────────────────────────
              // Sits directly on the ground, not in a card: the shelf is the
              // screen, so nothing should frame it.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your water shelf',
                      style: AppTypography.heading(size: 30, height: 1.08),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap an empty to send it back for a refill.',
                      style: AppTypography.body(
                        size: 14.5,
                        color: AppColors.textMuted(0.6),
                      ),
                    ),
                    const SizedBox(height: 18),
                    WaterShelf(
                      bottles: _shelf,
                      selectedIndices: _selectedEmpties,
                      daysRemaining: 3,
                      onToggle: (i) => setState(() {
                        _selectedEmpties.contains(i)
                            ? _selectedEmpties.remove(i)
                            : _selectedEmpties.add(i);
                      }),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _selectedEmpties.isEmpty ? null : _sendEmpties,
                      child: Text(
                        _selectedEmpties.isEmpty
                            ? 'Select an empty bottle'
                            : 'Send ${_selectedEmpties.length} '
                                  '${_selectedEmpties.length == 1 ? 'empty' : 'empties'} '
                                  'for refill · '
                                  '${Formatters.rupees(_selectedEmpties.length * _refillPrice)}',
                      ),
                    ),
                  ],
                ),
              ),

              // ── Your usual ──────────────────────────────────────────────
              if (usual != null)
                AppSection(
                  title: 'Your usual',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    child: AppCard(
                      onTap: () {
                        ref
                            .read(cartProvider.notifier)
                            .loadLines(
                              sellerId: usual.sellerId,
                              sellerName: usual.sellerName,
                              lines: usual.lines,
                            );
                        context.pushNamed(AppRoutes.cart);
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent100,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.replay_rounded,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  usual.itemsSummary,
                                  style: AppTypography.body(
                                    size: 14.5,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${usual.sellerName} · '
                                  '${Formatters.rupees(usual.total)} · '
                                  '${Formatters.eta(usual.etaMinutes)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                    size: 12.5,
                                    color: AppColors.textMuted(0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Reorder in one tap',
                                  style: AppTypography.body(
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Sellers near you ────────────────────────────────────────
              AppSection(
                title: 'Or try another seller',
                actionLabel: 'Map',
                onAction: () => context.pushNamed(AppRoutes.sellerMap),
                child: switch (sellersAsync) {
                  AsyncLoading() => const SkeletonList(),
                  AsyncError(:final error) => ErrorView(
                    failure: asFailure(error),
                    onRetry: () => ref.invalidate(
                      nearbySellersProvider(address!.id),
                    ),
                  ),
                  AsyncValue(value: final sellers) => (sellers?.isEmpty ?? true)
                      ? _NoSellersHere(area: address?.area ?? 'this area')
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
                                    pathParameters: {'sellerId': seller.id},
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
    );
  }
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
