import 'package:aqua_mart/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Addresses are saved from the device geocoder, so `area` is often a whole
/// postal line. These are real values from the database.
void main() {
  test('keeps the neighbourhood from a full geocoded line', () {
    expect(
      Formatters.areaLabel(
        'Mufti Mahmood Chowk Bus Stop, Itehad Town Rd, Ittehad Town '
        'Orangi Town, Karachi, Pakistan, Orangi Town, Karachi, Sindh, Pakistan',
      ),
      'Mufti Mahmood Chowk Bus…',
    );
  });

  test('short areas are passed through untouched', () {
    expect(Formatters.areaLabel('Gulberg III'), 'Gulberg III');
    expect(Formatters.areaLabel('Model Town'), 'Model Town');
  });

  test('never exceeds the character budget', () {
    const samples = [
      'Mufti Mahmood Chowk Bus Stop, Itehad Town Rd, Karachi, Sindh',
      'VXJQ+R27, Street Number 22, Shershah Colony, Karachi, Pakistan',
      'Plot ZC 7, Jinnah Housing Society P.E.C.H.S., Karachi, Pakistan',
      'Gulberg III',
    ];
    for (final sample in samples) {
      // +1 for the ellipsis character.
      expect(Formatters.areaLabel(sample).length, lessThanOrEqualTo(25));
    }
  });

  test('never slices a word in half', () {
    final label = Formatters.areaLabel(
      'Muhammadan Cooperative Housing Society Extension',
    );
    // Anything before the ellipsis must be whole words.
    final body = label.replaceAll('…', '').trimRight();
    expect(
      'Muhammadan Cooperative Housing Society Extension'.startsWith(body),
      isTrue,
    );
    expect(body.endsWith(' '), isFalse);
  });

  test('handles empty and comma-only input', () {
    expect(Formatters.areaLabel(''), '');
    expect(Formatters.areaLabel('   '), '');
  });

  test('respects a custom budget', () {
    expect(Formatters.areaLabel('Gulberg III Lahore', maxChars: 8).length,
        lessThanOrEqualTo(9));
  });
}
