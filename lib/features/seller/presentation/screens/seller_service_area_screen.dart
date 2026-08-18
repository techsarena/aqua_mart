import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/app_location.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/location/pakistan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../domain/entities/service_area.dart';
import '../providers/seller_providers.dart';
import 'area_search_screen.dart';

/// Where the seller delivers: a radius around the shop plus named areas.
///
/// This screen is a **shell tab**, so it must not set `bottomNavigationBar` —
/// that slot belongs to the seller's navigation bar and anything put there is
/// hidden behind it. The save button is therefore pinned inside the body.
class SellerServiceAreaScreen extends ConsumerStatefulWidget {
  const SellerServiceAreaScreen({super.key});

  @override
  ConsumerState<SellerServiceAreaScreen> createState() =>
      _SellerServiceAreaScreenState();
}

class _SellerServiceAreaScreenState
    extends ConsumerState<SellerServiceAreaScreen> {
  final _mapController = MapController();

  double _radiusKm = 4;
  List<String> _areas = const [];
  LatLng? _centre;
  bool _saving = false;

  /// True once the server's saved area has been copied into the fields above,
  /// so a rebuild never discards what the seller is part-way through editing.
  bool _loaded = false;

  /// A sensible first view before the shop's own pin is known.
  static const _fallbackCentre = Pakistan.defaultCity;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Rough households covered, so the radius means something concrete.
  int get _homesCovered => (_radiusKm * _radiusKm * 120).round();

  void _adopt(ServiceArea area) {
    _loaded = true;
    _areas = List.of(area.areas);
    if (area.radiusKm > 0) _radiusKm = area.radiusKm.clamp(1, 12);
    if (area.hasCentre) {
      _centre = LatLng(area.latitude!, area.longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaAsync = ref.watch(serviceAreaProvider);

    // Copy the saved area in once, the first time it arrives.
    ref.listen(serviceAreaProvider, (_, next) {
      final value = next.value;
      if (value != null && !_loaded) setState(() => _adopt(value));
    });
    if (!_loaded && areaAsync.hasValue) _adopt(areaAsync.value!);

    return Scaffold(
      appBar: AppBar(title: const Text('Where you deliver')),
      body: areaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error is Exception ? '$error' : 'Could not load your area.',
          onRetry: () => ref.invalidate(serviceAreaProvider),
        ),
        data: (_) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                children: [
                  _MapPane(
                    controller: _mapController,
                    centre: _centre ?? _fallbackCentre,
                    radiusKm: _radiusKm,
                    hasCentre: _centre != null,
                    onMoved: (point) => setState(() => _centre = point),
                    onUseMyLocation: _useMyLocation,
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_radiusKm.toStringAsFixed(0)} km radius',
                              style: AppTypography.heading(size: 20),
                            ),
                            const Spacer(),
                            Text(
                              '~$_homesCovered homes',
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.textMuted(0.6),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 12,
                          divisions: 11,
                          activeColor: AppColors.accent,
                          onChanged: (v) => setState(() => _radiusKm = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  const FieldLabel('Areas you cover'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final area in _areas)
                        Chip(
                          label: Text(area),
                          onDeleted: () => setState(
                            () => _areas = [..._areas]..remove(area),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 15),
                          backgroundColor: AppColors.accent100,
                          side: BorderSide.none,
                          labelStyle: AppTypography.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.accent700,
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.search_rounded, size: 15),
                        label: const Text('Add area'),
                        onPressed: _addArea,
                        backgroundColor: Colors.transparent,
                        side: const BorderSide(color: AppColors.divider),
                        labelStyle: AppTypography.body(
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Searching an area also moves the map there, so you can '
                    'set the radius around it.',
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.textMuted(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            _SaveBar(
              isSaving: _saving,
              // Saving a radius with no centre would serve nobody, so the
              // button waits for a pin.
              isEnabled: _centre != null && !_saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useMyLocation() async {
    final location = await ref.read(currentLocationProvider.future);
    if (!mounted || location == null) {
      if (mounted) {
        _showMessage('Could not find your location. Drag the map instead.');
      }
      return;
    }
    // GPS can legitimately report a spot outside the country (a border town,
    // or a seller travelling). Moving the pin there would place a Pakistani
    // store abroad, and the camera constraint would silently drag it back.
    if (!Pakistan.contains(location.latitude, location.longitude)) {
      _showMessage('That location is outside Pakistan. Search for your area.');
      return;
    }

    final point = LatLng(location.latitude, location.longitude);
    setState(() => _centre = point);
    _mapController.move(point, _zoomForRadius(_radiusKm));
  }

  Future<void> _save() async {
    final centre = _centre;
    if (centre == null) return;

    setState(() => _saving = true);
    final result = await ref
        .read(serviceAreaProvider.notifier)
        .save(
          ServiceArea(
            areas: _areas,
            radiusKm: _radiusKm,
            latitude: centre.latitude,
            longitude: centre.longitude,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (_) => _showMessage('Service area saved.'),
      failure: (failure) => _showMessage(failure.message),
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// Search for an area, then centre the map on it so the radius is set
  /// around a real place rather than by hunting across the map.
  Future<void> _addArea() async {
    final picked = await Navigator.of(context).push<AppLocation>(
      MaterialPageRoute(builder: (_) => const AreaSearchScreen()),
    );
    if (!mounted || picked == null) return;

    final point = LatLng(picked.latitude, picked.longitude);
    final name = _areaName(picked.label);

    setState(() {
      _centre = point;
      if (name.isNotEmpty && !_areas.contains(name)) {
        _areas = [..._areas, name];
      }
    });

    // Move the map to the picked place and frame the current radius, so the
    // circle the seller is about to size is already on screen.
    _mapController.move(point, _zoomForRadius(_radiusKm));

    if (mounted) {
      _showMessage('Centred on $name. Set how far you deliver, then save.');
    }
  }

  /// A geocoded label is a full address; the chip wants the area.
  /// "Gulberg III, Lahore, Punjab, Pakistan" -> "Gulberg III".
  String _areaName(String label) {
    final first = label.split(',').first.trim();
    return first.isEmpty ? label.trim() : first;
  }
}

/// A zoom that keeps the whole radius circle on screen.
double _zoomForRadius(double radiusKm) {
  if (radiusKm <= 2) return 14;
  if (radiusKm <= 4) return 13;
  if (radiusKm <= 8) return 12;
  return 11;
}

/// The live map, with the delivery circle drawn on it.
class _MapPane extends StatelessWidget {
  const _MapPane({
    required this.controller,
    required this.centre,
    required this.radiusKm,
    required this.hasCentre,
    required this.onMoved,
    required this.onUseMyLocation,
  });

  final MapController controller;
  final LatLng centre;
  final double radiusKm;
  final bool hasCentre;
  final ValueChanged<LatLng> onMoved;
  final VoidCallback onUseMyLocation;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: _zoomForRadius(radiusKm),
                // Zooming out past the country is just scrolling past places
                // this app does not serve.
                minZoom: 5,
                maxZoom: 19,
                // The map centre IS the shop pin, so constraining the centre
                // means the shop can never be placed outside Pakistan —
                // while the view can still pan freely near the borders.
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: LatLngBounds(Pakistan.southWest, Pakistan.northEast),
                ),
                // The shop sits wherever the map is centred, so panning the
                // map IS moving the pin — no separate drag target to find.
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) onMoved(camera.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.aqua_mart',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: centre,
                      // Drawn in metres so the circle keeps its real size as
                      // the map zooms, instead of a fixed pixel blob.
                      radius: radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderColor: AppColors.accent,
                      borderStrokeWidth: 2,
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

          // The shop marker is pinned to the centre of the viewport rather
          // than the map, so it stays under the thumb while panning.
          const IgnorePointer(child: Center(child: _ShopPin())),

          Positioned(
            right: AppSpacing.md,
            top: AppSpacing.md,
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                tooltip: 'Use my location',
                icon: const Icon(Icons.my_location_rounded, size: 20),
                onPressed: onUseMyLocation,
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                hasCentre
                    ? 'drag the map to move your shop'
                    : 'drag the map to place your shop',
                style: AppTypography.body(
                  size: 10.5,
                  color: AppColors.textMuted(0.65),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The shop marker at the centre of the delivery circle.
class _ShopPin extends StatelessWidget {
  const _ShopPin();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const SizedBox.square(
          dimension: 26,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_rounded, size: 15, color: Colors.white),
          ),
        ),
      ),
      Container(width: 4, height: 16, color: AppColors.accent),
    ],
  );
}

/// The save button, pinned inside the body.
///
/// A shell tab cannot use `bottomNavigationBar` — the nav bar already owns it
/// — so this sits at the end of the column instead, above the tabs.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isSaving,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isSaving;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton(
            onPressed: isEnabled ? onPressed : null,
            child: Text(
              isSaving
                  ? 'Saving…'
                  : isEnabled
                  ? 'Save service area'
                  : 'Place your shop on the map',
            ),
          ),
        ),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
