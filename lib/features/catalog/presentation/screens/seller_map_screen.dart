import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// `hide Path`: latlong2 exports its own Path, which shadows the one
// CustomPainter draws with.
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/location/pakistan.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/back_disc_button.dart';
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
  final _mapController = MapController();

  /// Tracked by id, not index: the nearby list re-sorts as distances refresh,
  /// so an index would silently select a different shop.
  String? _selectedId;

  /// True once the camera has been framed around the sellers, so a later
  /// rebuild does not yank the map back while the customer is panning.
  bool _framed = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);
    // A customer without a saved address still sees every seller, so the map
    // is never blank just because they have not added an address yet.
    final sellers =
        ref.watch(nearbySellersProvider(address?.id)).value ?? const <Seller>[];

    // A seller with no coordinates cannot be drawn. They stay in the list
    // view; plotting them at 0,0 would put a Lahore shop in the Atlantic.
    final plottable = [
      for (final seller in sellers)
        if (seller.latitude != null && seller.longitude != null) seller,
    ];

    // Shops genuinely share a point — a plaza, a market street, or several
    // branches at one address. Stacked markers look like ONE seller and only
    // the top one can be tapped, so a cluster is fanned into a small ring.
    final points = _fanOut(plottable);

    final selected = plottable.isEmpty
        ? null
        : plottable.firstWhere(
            (s) => s.id == _selectedId,
            orElse: () => plottable.first,
          );

    final home = address?.latitude != null && address?.longitude != null
        ? LatLng(address!.latitude!, address.longitude!)
        : null;

    // Frame everything once the sellers arrive.
    if (!_framed && plottable.isNotEmpty) {
      _framed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit(plottable, home);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // The map fills the screen; each seller is a real marker at their
          // own coordinates.
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    home ??
                    (plottable.isNotEmpty
                        ? LatLng(
                            plottable.first.latitude!,
                            plottable.first.longitude!,
                          )
                        : Pakistan.defaultCity),
                initialZoom: 13,
                minZoom: 5,
                maxZoom: 19,
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: LatLngBounds(Pakistan.southWest, Pakistan.northEast),
                ),
                // Tapping bare map dismisses the preview card, so the map
                // underneath can be read.
                onTap: (_, _) => setState(() => _selectedId = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.aqua_mart',
                ),

                // "You are here", drawn under the sellers so a shop at the
                // same spot stays tappable.
                if (home != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: home,
                        width: 30,
                        height: 30,
                        child: const _HomeDot(),
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    // Sellers can share a spot (a plaza, or two shops on one
                    // street). Drawing the selected one LAST puts it on top,
                    // so the card and the highlighted pin always agree.
                    for (final seller in [
                      for (final s in plottable)
                        if (s.id != selected?.id) s,
                      if (selected != null) selected,
                    ])
                      Marker(
                        point: points[seller.id]!,
                        width: 108,
                        height: 54,
                        alignment: Alignment.topCenter,
                        child: _SellerMarker(
                          seller: seller,
                          isSelected: seller.id == selected?.id,
                          onTap: () {
                            setState(() => _selectedId = seller.id);
                            _mapController.move(
                              points[seller.id]!,
                              _mapController.camera.zoom.clamp(13, 19),
                            );
                          },
                        ),
                      ),
                  ],
                ),

                const RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
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
                            // Counts what is actually ON the map, so the
                            // number matches the pins the customer can see.
                            '${address?.area ?? 'Nearby'} · '
                            '${plottable.length} '
                            '${plottable.length == 1 ? 'seller' : 'sellers'}',
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

          // Sellers exist but none can be placed: say so, rather than
          // leaving an empty map that reads as "nobody delivers here".
          if (plottable.isEmpty && sellers.isNotEmpty)
            Positioned(
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              bottom: AppSpacing.gutter,
              child: SafeArea(
                child: AppCard(
                  elevated: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          '${sellers.length} sellers deliver here, but none '
                          'have pinned their shop yet. Open the list to order.',
                          style: AppTypography.body(size: 13.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
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

  /// Nudges sellers that share a coordinate onto a small ring around it, so
  /// each one is separately visible and tappable.
  ///
  /// The offset is metres-scale — far too small to misrepresent where a shop
  /// is, but enough to separate the bubbles at street zoom.
  static Map<String, LatLng> _fanOut(List<Seller> sellers) {
    final byPoint = <String, List<Seller>>{};
    for (final seller in sellers) {
      // Rounded so coordinates that differ only in noise still group.
      final key =
          '${seller.latitude!.toStringAsFixed(5)},'
          '${seller.longitude!.toStringAsFixed(5)}';
      byPoint.putIfAbsent(key, () => []).add(seller);
    }

    const spreadDegrees = 0.00035; // ~40 m
    final placed = <String, LatLng>{};

    for (final group in byPoint.values) {
      final origin = LatLng(group.first.latitude!, group.first.longitude!);
      if (group.length == 1) {
        placed[group.first.id] = origin;
        continue;
      }
      for (var i = 0; i < group.length; i++) {
        final angle = (2 * math.pi * i) / group.length;
        placed[group[i].id] = LatLng(
          origin.latitude + spreadDegrees * math.sin(angle),
          origin.longitude + spreadDegrees * math.cos(angle),
        );
      }
    }
    return placed;
  }

  /// Frames the camera so every seller — and the customer's own address —
  /// is on screen at once, rather than opening on an arbitrary one.
  void _fit(List<Seller> sellers, LatLng? home) {
    final fanned = _fanOut(sellers);
    final points = <LatLng>[
      ...fanned.values,
      if (home != null) home,
    ];
    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        // Padding keeps a pin from sitting under the search bar or the
        // preview card, both of which float over the map.
        padding: const EdgeInsets.fromLTRB(48, 130, 48, 220),
        maxZoom: 16,
      ),
    );
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

/// The customer's own address — a dark dot, deliberately unlike the seller
/// bubbles so it never reads as one of them.
class _HomeDot extends StatelessWidget {
  const _HomeDot();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: const SizedBox.square(
      dimension: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.text,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// A seller on the map: a price bubble with a tail pointing at the shop.
///
/// The price is the thing being compared across sellers, so it is what the
/// bubble carries; a closed shop says so instead and is faded back.
class _SellerMarker extends StatelessWidget {
  const _SellerMarker({
    required this.seller,
    required this.isSelected,
    required this.onTap,
  });

  final Seller seller;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? AppColors.accent
        : (seller.isOpen ? Colors.white : AppColors.neutral200);
    final foreground = isSelected
        ? Colors.white
        : (seller.isOpen ? AppColors.text : AppColors.textMuted(0.7));

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: seller.isOpen ? 1 : 0.75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                seller.isOpen
                    ? Formatters.rupees(seller.cheapestRefillPrice ?? 0)
                    : 'Closed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(14, 8),
              painter: _TailPainter(color: background),
            ),
          ],
        ),
      ),
    );
  }
}

/// The little triangle under a price bubble.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.color != color;
}
