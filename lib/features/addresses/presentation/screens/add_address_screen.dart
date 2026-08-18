import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/app_location.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/location/pakistan.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../../shared/widgets/toggle_panel.dart';
import '../../domain/entities/address.dart';
import '../providers/address_providers.dart';

/// Drop a pin, label it, and note anything the rider needs to find the gate.
///
/// Doubles as the edit screen when an [addressId] is passed.
class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key, this.addressId});

  final String? addressId;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  static const _lahore = AppLocation(
    latitude: 31.5204,
    longitude: 74.3587,
    label: 'Lahore, Punjab, Pakistan',
  );

  final _searchController = TextEditingController();
  final _houseController = TextEditingController();
  final _noteController = TextEditingController();
  Timer? _reverseDebounce;
  AppLocation? _selectedLocation;
  AddressLabel _label = AddressLabel.home;
  bool _makeDefault = false;
  bool _saving = false;
  bool _searching = false;
  bool _locating = false;
  bool _seeded = false;
  bool _currentLocationApplied = false;
  int _reverseRequest = 0;

  Address? get _editing {
    final id = widget.addressId;
    if (id == null) return null;
    final addresses = ref.read(addressBookProvider).value ?? const [];
    return addresses.where((a) => a.id == id).firstOrNull;
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _searchController.dispose();
    _houseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Fills the form from the address being edited, once its data has loaded.
  void _seedIfNeeded() {
    if (_seeded) return;
    final existing = _editing;
    if (existing == null) return;

    _houseController.text = existing.houseNumber;
    _noteController.text = existing.riderNote;
    _label = existing.label;
    _makeDefault = existing.isDefault;
    _selectedLocation = AppLocation(
      latitude: existing.latitude ?? _lahore.latitude,
      longitude: existing.longitude ?? _lahore.longitude,
      label: existing.area,
    );
    _searchController.text = existing.area;
    _seeded = true;
  }

  void _applyLocation(AppLocation location) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = location;
      _searchController.text = location.label;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    });
  }

  void _onMapMoved(LatLng centre) {
    _reverseDebounce?.cancel();
    final request = ++_reverseRequest;
    final coordinateLocation = AppLocation(
      latitude: centre.latitude,
      longitude: centre.longitude,
      label:
          '${centre.latitude.toStringAsFixed(5)}, '
          '${centre.longitude.toStringAsFixed(5)}',
    );
    _applyLocation(coordinateLocation);
    _reverseDebounce = Timer(const Duration(milliseconds: 550), () async {
      final location = await ref
          .read(appLocationServiceProvider)
          .reverse(centre.latitude, centre.longitude);
      if (mounted && request == _reverseRequest) _applyLocation(location);
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final location = await ref.refresh(currentLocationProvider.future);
    if (!mounted) return;
    setState(() => _locating = false);
    if (location != null) {
      _currentLocationApplied = true;
      _applyLocation(location);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Turn on location access to use your current position.'),
      ),
    );
  }

  Future<void> _search(String query) async {
    if (_searching || query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final results = await ref.read(appLocationServiceProvider).search(query);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching location found.')),
        );
      } else if (results.length == 1) {
        _applyLocation(results.first);
      } else {
        final selected = await showModalBottomSheet<AppLocation>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = results[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(result.label),
                  onTap: () => Navigator.pop(context, result),
                );
              },
            ),
          ),
        );
        if (selected != null) _applyLocation(selected);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location search is unavailable. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final existing = _editing;
    final location = _selectedLocation;
    if (location == null) {
      setState(() => _saving = false);
      return;
    }

    final address = Address(
      id: existing?.id ?? '',
      label: _label,
      title: _label.text,
      area: location.label,
      houseNumber: _houseController.text.trim(),
      riderNote: _noteController.text.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
      isDefault: _makeDefault,
    );

    final saved = await ref.read(addressBookProvider.notifier).save(address);

    if (!mounted) return;
    setState(() => _saving = false);

    if (saved != null) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That address couldn't be saved.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the seed runs once the address book resolves.
    ref.watch(addressBookProvider);
    _seedIfNeeded();

    final currentLocation = ref.watch(currentLocationProvider).value;
    if (widget.addressId == null &&
        !_currentLocationApplied &&
        currentLocation != null) {
      _currentLocationApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedLocation == null) {
          _applyLocation(currentLocation);
        }
      });
    }

    final mapLocation = _selectedLocation ?? currentLocation ?? _lahore;

    return Scaffold(
      // The map runs to the edges with the controls floating on it, so the
      // pin has as much room as the screen can give.
      body: Column(
        children: [
          _MapPane(
            location: mapLocation,
            searchController: _searchController,
            searching: _searching,
            locating: _locating,
            hint: widget.addressId == null
                ? 'Drag to your gate'
                : 'Edit address',
            onSearch: _search,
            onMapMoved: _onMapMoved,
            onCurrentLocation: _useCurrentLocation,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                const FieldLabel('SAVE AS'),
                Row(
                  children: [
                    for (final label in AddressLabel.values) ...[
                      Expanded(
                        child: _LabelChoice(
                          label: label,
                          selected: _label == label,
                          onTap: () => setState(() => _label = label),
                        ),
                      ),
                      if (label != AddressLabel.values.last)
                        const SizedBox(width: AppSpacing.md),
                    ],
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),
                const FieldLabel('HOUSE / FLAT NUMBER'),
                TextField(
                  controller: _houseController,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.body(size: 19, weight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: '42-B'),
                ),

                const SizedBox(height: AppSpacing.xl),
                const FieldLabel('NOTE FOR THE RIDER — OPTIONAL'),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: AppTypography.body(size: 17),
                  decoration: InputDecoration(
                    // Square-ish rather than pill: a three-line box cannot
                    // carry a full pill without the text fouling the curve.
                    border: _noteBorder(AppColors.divider),
                    enabledBorder: _noteBorder(AppColors.divider),
                    focusedBorder: _noteBorder(AppColors.accent, width: 1.5),
                    hintText:
                        'Near Hafeez Centre. Ring the bell twice — gate is on '
                        'the side street.',
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                TogglePanel(
                  title: 'Make this my default',
                  value: _makeDefault,
                  onChanged: (v) => setState(() => _makeDefault = v),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _saving ? 'Saving…' : 'Save address',
        enabled:
            !_saving &&
            _selectedLocation != null &&
            _houseController.text.trim().isNotEmpty,
        onPressed: _save,
      ),
    );
  }

  /// The rider note is the one multi-line field in the app, so it gets its
  /// own softer-cornered box instead of the themed pill.
  OutlineInputBorder _noteBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// A real, draggable OpenStreetMap picker with search and GPS recentering.
class _MapPane extends StatefulWidget {
  const _MapPane({
    required this.location,
    required this.searchController,
    required this.searching,
    required this.locating,
    required this.hint,
    required this.onSearch,
    required this.onMapMoved,
    required this.onCurrentLocation,
  });

  final AppLocation location;
  final TextEditingController searchController;
  final bool searching;
  final bool locating;
  final String hint;
  final ValueChanged<String> onSearch;
  final ValueChanged<LatLng> onMapMoved;
  final VoidCallback onCurrentLocation;

  @override
  State<_MapPane> createState() => _MapPaneState();
}

class _MapPaneState extends State<_MapPane> {
  final MapController _mapController = MapController();

  LatLng get _point =>
      LatLng(widget.location.latitude, widget.location.longitude);

  @override
  void didUpdateWidget(covariant _MapPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.latitude == widget.location.latitude &&
        oldWidget.location.longitude == widget.location.longitude) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(_point, _mapController.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.38,
    child: Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _point,
              initialZoom: 16,
              minZoom: 5,
              maxZoom: 19,
              // Deliveries only happen in Pakistan, so an address cannot be
              // dropped outside it. Constraining the centre (the pin) rather
              // than the whole view keeps panning natural near a border.
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(Pakistan.southWest, Pakistan.northEast),
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) widget.onMapMoved(camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aqua_mart',
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
        Positioned(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
          child: Row(
            children: [
              const BackDiscButton(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      key: const Key('address-location-search'),
                      controller: widget.searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: widget.onSearch,
                      textAlignVertical: TextAlignVertical.center,
                      strutStyle: const StrutStyle(
                        fontSize: 17,
                        height: 1,
                        forceStrutHeight: true,
                      ),
                      style: AppTypography.body(
                        size: 17,
                        height: 1,
                        color: AppColors.neutral600,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        isDense: true,
                        hintText: 'Search area or address',
                        hintStyle: AppTypography.body(
                          size: 17,
                          height: 1,
                          color: AppColors.textMuted(0.45),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.lg,
                            right: AppSpacing.sm,
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            size: 22,
                            color: AppColors.neutral500,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 50,
                          minHeight: 48,
                        ),
                        suffixIcon: widget.searching
                            ? const Padding(
                                padding: EdgeInsets.only(
                                  left: AppSpacing.sm,
                                  right: AppSpacing.lg,
                                ),
                                child: SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(
                          minHeight: 48,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.only(
                          right: AppSpacing.lg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const IgnorePointer(child: Center(child: _PickerPin())),
        Align(
          alignment: const Alignment(0, -0.16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.text.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              widget.hint,
              style: AppTypography.body(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.gutter,
          bottom: AppSpacing.lg,
          child: FloatingActionButton.small(
            heroTag: 'address-current-location',
            tooltip: 'Use current location',
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.accent,
            onPressed: widget.locating ? null : widget.onCurrentLocation,
            child: widget.locating
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    ),
  );
}

class _PickerPin extends StatelessWidget {
  const _PickerPin();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, -20),
    child: const Icon(
      Icons.location_pin,
      size: 48,
      color: AppColors.accent,
      shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
    ),
  );
}

/// One of Home / Office / Other — an icon over its name, in a card that
/// tints and outlines when chosen.
class _LabelChoice extends StatelessWidget {
  const _LabelChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
    AddressLabel.home => Icons.home_outlined,
    AddressLabel.office => Icons.business_outlined,
    AddressLabel.other => Icons.location_on_outlined,
  };

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.onTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 22,
              color: selected ? AppColors.accent : AppColors.textMuted(0.7),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label.text,
              style: AppTypography.heading(
                size: 14,
                color: selected ? AppColors.text : AppColors.textMuted(0.8),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
