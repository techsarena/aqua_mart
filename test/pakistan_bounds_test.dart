import 'package:aqua_mart/core/location/pakistan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bounding box is a COARSE filter — the first pass over geocoder results
/// and the leash on the map camera. It cannot be exact: Kabul sits closer to
/// the box than Quetta and Gwadar do, so any rectangle that excluded it would
/// also cut real Pakistani cities. `Pakistan.matches` exists for that reason
/// and prefers the geocoder's country code, which is authoritative.
void main() {
  group('bounding box', () {
    test('covers Pakistani cities from Gwadar to Skardu', () {
      const cities = {
        'Karachi': (24.8607, 67.0011),
        'Lahore': (31.5204, 74.3587),
        'Islamabad': (33.6844, 73.0479),
        'Peshawar': (34.0151, 71.5249),
        'Quetta': (30.1798, 66.9750),
        'Gwadar': (25.1216, 62.3254),
        'Gilgit': (35.9208, 74.3144),
        'Skardu': (35.2971, 75.6333),
        'Multan': (30.1575, 71.5249),
      };
      for (final entry in cities.entries) {
        final (lat, lng) = entry.value;
        expect(
          Pakistan.contains(lat, lng),
          isTrue,
          reason: '${entry.key} must be inside',
        );
      }
    });

    test('excludes far-away places', () {
      const outside = {
        'Delhi': (28.6139, 77.2090),
        'Mumbai': (19.0760, 72.8777),
        'Dubai': (25.2048, 55.2708),
        'London': (51.5074, -0.1278),
      };
      for (final entry in outside.entries) {
        final (lat, lng) = entry.value;
        expect(
          Pakistan.contains(lat, lng),
          isFalse,
          reason: '${entry.key} must be excluded',
        );
      }
    });

    test('Delhi is excluded despite sharing a longitude with the northeast', () {
      // A plain rectangle wide enough for Siachen (~77E) also swallowed
      // Delhi, which sits at the same longitude but far to the south.
      expect(Pakistan.contains(35.4, 77.0), isTrue, reason: 'NE territory');
      expect(Pakistan.contains(28.6139, 77.2090), isFalse, reason: 'Delhi');
    });
  });

  group('matches', () {
    test('the country code decides, even for a border city', () {
      // Kabul is inside the coarse box; the code is what rejects it.
      expect(
        Pakistan.matches(
          isoCountryCode: 'AF',
          latitude: 34.5553,
          longitude: 69.2075,
        ),
        isFalse,
      );
      expect(
        Pakistan.matches(
          isoCountryCode: 'PK',
          latitude: 34.0151,
          longitude: 71.5249,
        ),
        isTrue,
      );
    });

    test('falls back to the country name, then to the box', () {
      expect(
        Pakistan.matches(
          country: 'Pakistan',
          latitude: 31.5204,
          longitude: 74.3587,
        ),
        isTrue,
      );
      expect(Pakistan.matches(latitude: 31.5204, longitude: 74.3587), isTrue);
      expect(Pakistan.matches(latitude: 51.5074, longitude: -0.1278), isFalse);
    });
  });
}
