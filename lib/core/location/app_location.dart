import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'pakistan.dart';

/// A map point plus the human-readable value shown in address fields.
class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.country,
    this.isoCountryCode,
  });

  final double latitude;
  final double longitude;
  final String label;

  /// Kept from the geocoder so a result can be checked against the country
  /// the app serves — coordinates alone cannot separate border cities.
  final String? country;
  final String? isoCountryCode;
}

/// Keeps permission, GPS and native geocoding details out of the UI layer.
class AppLocationService {
  AppLocationService({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

  Future<AppLocation?> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final cached = await Geolocator.getLastKnownPosition();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return reverse(position.latitude, position.longitude);
    } catch (_) {
      if (cached == null) rethrow;
      return reverse(cached.latitude, cached.longitude);
    }
  }

  Future<AppLocation> reverse(double latitude, double longitude) async {
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        return AppLocation(
          latitude: latitude,
          longitude: longitude,
          label: _placemarkLabel(place),
          country: place.country,
          isoCountryCode: place.isoCountryCode,
        );
      }
    } catch (_) {
      // Coordinates are still useful if the platform geocoder is unavailable.
    }
    return AppLocation(
      latitude: latitude,
      longitude: longitude,
      label: _coordinateLabel(latitude, longitude),
    );
  }

  /// Uses the platform geocoder, then reverse-geocodes each result so the
  /// picker can show and save the exact value selected by the customer.
  ///
  /// Results outside Pakistan are dropped: the app delivers water there and
  /// nowhere else, and many Pakistani place names ("Model Town", "Johar
  /// Town") also exist abroad, so an unfiltered search offers addresses no
  /// rider could ever reach.
  Future<List<AppLocation>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Naming the country in the query biases the geocoder towards Pakistan
    // before we filter, so the five results we get back are the useful ones.
    final matches = await _geocoding.locationFromAddress(
      trimmed.toLowerCase().contains(Pakistan.countryName.toLowerCase())
          ? trimmed
          : '$trimmed, ${Pakistan.countryName}',
    );

    final results = <AppLocation>[];
    for (final match in matches.take(8)) {
      // Cheap box check first, so an obviously foreign hit costs no
      // reverse-geocode round trip.
      if (!Pakistan.contains(match.latitude, match.longitude)) continue;

      final location = await reverse(match.latitude, match.longitude);

      // Then the authoritative check: the box alone cannot separate a border
      // city such as Kabul from northern Pakistan.
      if (!Pakistan.matches(
        country: location.country,
        isoCountryCode: location.isoCountryCode,
        latitude: location.latitude,
        longitude: location.longitude,
      )) {
        continue;
      }
      final duplicate = results.any(
        (item) =>
            item.label == location.label &&
            item.latitude == location.latitude &&
            item.longitude == location.longitude,
      );
      if (!duplicate) results.add(location);
      if (results.length == 5) break;
    }
    return results;
  }

  String _placemarkLabel(Placemark place) {
    final parts = <String>[];
    void add(String? value) {
      final clean = value?.trim();
      if (clean == null || clean.isEmpty || parts.contains(clean)) return;
      parts.add(clean);
    }

    add(place.street);
    add(place.subLocality);
    add(place.locality);
    add(place.administrativeArea);
    add(place.country);
    return parts.isEmpty ? 'Selected location' : parts.join(', ');
  }

  String _coordinateLabel(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}
