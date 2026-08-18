import 'package:latlong2/latlong.dart';

/// Aqua Mart operates in Pakistan only, so every map and every place search
/// is bounded to it. Kept in one place because a mismatch between the two
/// would let a seller search a city the map cannot pan to.
abstract final class Pakistan {
  /// ISO country code, as the platform geocoder reports it.
  static const countryCode = 'PK';

  /// Country name, for geocoders that return the name rather than the code.
  static const countryName = 'Pakistan';

  /// The national bounding box, padded slightly so border cities such as
  /// Karachi and Gwadar are not clipped at the edge of the map.
  static const south = 23.5;
  static const north = 37.2;
  static const west = 60.7;

  /// The eastern edge, used for the map camera. It has to reach ~77°E to
  /// include the far northeast (Siachen), which is well east of Lahore.
  static const east = 77.3;

  /// East of this, the country only extends in the north — so a single
  /// rectangle would also swallow Delhi (28.6N, 77.2E), which sits at the
  /// same longitude as the northeast but far to the south.
  static const _northeastOnlyEast = 75.9;
  static const _northeastMinLatitude = 32.0;

  /// The country's rough centre, used as a first view before any pin exists.
  static const centre = LatLng(30.3753, 69.3451);

  /// Lahore — a better default than the geographic centre, which lands in a
  /// sparsely-populated area with nothing recognisable on the map.
  static const defaultCity = LatLng(31.5204, 74.3587);

  static final LatLng southWest = LatLng(south, west);
  static final LatLng northEast = LatLng(north, east);

  /// True when a point is inside the country.
  ///
  /// Not a plain rectangle: the eastern limit steps back below the northern
  /// latitudes, because a box wide enough for Siachen would otherwise include
  /// Delhi and much of northern India.
  static bool contains(double latitude, double longitude) {
    if (latitude < south || latitude > north) return false;
    if (longitude < west || longitude > east) return false;

    // The far east is northern territory only.
    if (longitude > _northeastOnlyEast) {
      return latitude >= _northeastMinLatitude;
    }
    return true;
  }

  /// True when a geocoded result belongs to Pakistan.
  ///
  /// Checks the country text first because it is authoritative, then falls
  /// back to the box — some geocoders return an empty country on sparse
  /// results, and dropping those would hide valid places.
  static bool matches({
    String? country,
    String? isoCountryCode,
    required double latitude,
    required double longitude,
  }) {
    final code = isoCountryCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) return code == countryCode;

    final name = country?.trim().toLowerCase();
    if (name != null && name.isNotEmpty) return name == countryName.toLowerCase();

    return contains(latitude, longitude);
  }
}
