import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/map_placeholder.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../domain/entities/seller.dart';
import '../providers/catalog_providers.dart';

/// Sellers plotted on the map, with a preview card for whichever pin is picked.
class SellerMapScreen extends ConsumerStatefulWidget {
  const SellerMapScreen({super.key});

  @override
  ConsumerState<SellerMapScreen> createState() => _SellerMapScreenState();
}

class _SellerMapScreenState extends ConsumerState<SellerMapScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);
    final sellers = address == null
        ? const <Seller>[]
        : (ref.watch(nearbySellersProvider(address.id)).value ??
              const <Seller>[]);

    final selected = sellers.isEmpty
        ? null
        : sellers[_selected.clamp(0, sellers.length - 1)];

    return Scaffold(
      body: Stack(
        children: [
          // The map fills the screen; pins sit at each seller's position.
          Positioned.fill(
            child: MapPlaceholder(
              radius: 0,
              height: double.infinity,
              pins: [
                for (var i = 0; i < sellers.length; i++)
                  MapPin(
                    x: _spread(i, sellers.length).$1,
                    y: _spread(i, sellers.length).$2,
                    label: sellers[i].isOpen
                        ? Formatters.rupees(sellers[i].cheapestRefillPrice ?? 0)
                        : 'Closed',
                    isPrimary: i == _selected,
                    isMuted: !sellers[i].isOpen,
                  ),
              ],
            ),
          ),

          // Where you are, so the prices around it have a reference point.
          const Center(child: UserLocationDot()),

          // Tapping anywhere cycles the selection — a stand-in for real pin
          // hit-testing, which arrives with the Maps SDK.
          if (sellers.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(
                  () => _selected = (_selected + 1) % sellers.length,
                ),
              ),
            ),

          // Above the tap layer, so the controls stay usable.
          Positioned(
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
            top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
            child: Row(
              children: [
                const BackDiscButton(),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 22,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            '${address?.area ?? 'Nearby'} · '
                            '${sellers.length} sellers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              size: 16.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Back to the list of sellers this map is showing.
                Material(
                  color: AppColors.surface,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.pop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.list_alt_rounded, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (selected != null)
            Positioned(
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              bottom: AppSpacing.gutter,
              child: SafeArea(
                child: AppCard(
                  elevated: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A soft tile rather than a round avatar — the
                          // seller is a shop here, not a person.
                          Container(
                            width: 62,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected.isOpen
                                  ? AppColors.accent2_200
                                  : AppColors.neutral200,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.water_drop_outlined,
                              size: 30,
                              color: selected.isOpen
                                  ? AppColors.accent2Deep
                                  : AppColors.textMuted(0.5),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.heading(size: 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (selected.distanceMetres != null)
                                      Formatters.distance(
                                        selected.distanceMetres!,
                                      ),
                                    '★ ${selected.rating}',
                                    Formatters.eta(selected.etaMinutes),
                                  ].join(' · '),
                                  style: AppTypography.body(
                                    size: 13.5,
                                    color: AppColors.textMuted(0.6),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    _PricePill(
                                      label:
                                          'Refill '
                                          '${Formatters.rupees(selected.cheapestRefillPrice ?? 0)}',
                                      highlighted: true,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    // Seller carries no buy-new price, so the
                                    // second pill lists the sizes stocked.
                                    if (selected.sizes.isNotEmpty)
                                      Flexible(
                                        child: _PricePill(
                                          label: selected.subtitle,
                                          highlighted: false,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: () => context.pushNamed(
                          AppRoutes.sellerStore,
                          pathParameters: {'sellerId': selected.id},
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          textStyle: AppTypography.heading(size: 19),
                        ),
                        child: const Text('Order from here'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Spreads pins across the map so they do not stack on one another.
  static (double, double) _spread(int index, int total) {
    const positions = [
      (-0.45, -0.4),
      (0.4, -0.15),
      (-0.2, 0.25),
      (0.5, 0.45),
      (-0.55, 0.5),
    ];
    return positions[index % positions.length];
  }
}

/// A price or detail chip on the map's preview card. The refill price is the
/// one being compared across sellers, so it is the tinted one.
class _PricePill extends StatelessWidget {
  const _PricePill({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: highlighted ? AppColors.accent200 : AppColors.neutral200,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body(
        size: 13.5,
        weight: FontWeight.w700,
        color: highlighted ? AppColors.accent700 : AppColors.textMuted(0.75),
      ),
    ),
  );
}
