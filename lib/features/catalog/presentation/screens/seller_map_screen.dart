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
      appBar: AppBar(
        title: Text('${address?.area ?? 'Nearby'} · ${sellers.length} sellers'),
      ),
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
                  ),
              ],
            ),
          ),

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

          if (selected != null)
            Positioned(
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              bottom: AppSpacing.gutter,
              child: SafeArea(
                child: AppCard(
                  elevated: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SellerAvatar(isOpen: selected.isOpen),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected.name,
                                  style: AppTypography.body(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
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
                                    size: 12.5,
                                    color: AppColors.textMuted(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          AppTag(
                            'Refill ${Formatters.rupees(selected.cheapestRefillPrice ?? 0)}',
                            tone: TagTone.accent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (selected.sizes.isNotEmpty)
                            AppTag(
                              selected.subtitle,
                              tone: TagTone.neutral,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: () => context.pushNamed(
                          AppRoutes.sellerStore,
                          pathParameters: {'sellerId': selected.id},
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
