import 'package:intl/intl.dart';

/// Prices, order numbers and phone numbers stay in Latin digits even in Urdu —
/// so these formatters are deliberately locale-independent.
abstract final class Formatters {
  static final _rupees = NumberFormat('#,##0', 'en_US');
  static final _time = DateFormat('h:mm a');
  static final _shortDate = DateFormat('d MMM');
  static final _longDate = DateFormat('EEEE, d MMM');

  /// `Rs 1,180`
  static String rupees(num amount) => 'Rs ${_rupees.format(amount)}';

  /// `1,240` — a plain count with thousands separators.
  static String count(num value) => _rupees.format(value);

  /// `Rs 12.4k` — used in dashboard stat tiles where space is tight.
  static String rupeesCompact(num amount) {
    if (amount >= 1000) {
      final k = amount / 1000;
      final text = k >= 10 ? k.toStringAsFixed(1) : k.toStringAsFixed(1);
      return '${text.replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return _rupees.format(amount);
  }

  /// `8:12 AM`
  static String time(DateTime value) => _time.format(value);

  /// `28 Jul`
  static String shortDate(DateTime value) => _shortDate.format(value);

  /// `Tuesday, 4 Aug`
  static String longDate(DateTime value) => _longDate.format(value);

  /// `~25 min`
  static String eta(int minutes) => '~$minutes min';

  /// `2 min ago`, `Yesterday, 9:00 AM`
  static String relative(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(value);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24 && reference.day == value.day) {
      return _time.format(value);
    }
    if (diff.inDays < 2) return 'Yesterday, ${_time.format(value)}';
    return _shortDate.format(value);
  }

  /// `400 m` / `1.2 km`
  static String distance(double metres) => metres < 1000
      ? '${metres.round()} m'
      : '${(metres / 1000).toStringAsFixed(1)} km';

  /// `+92 300 4412987`
  ///
  /// Accepts the country code, the national trunk `0`, or neither — all three
  /// forms are typed by real users.
  static String phone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10) return raw;
    return '+92 ${digits.substring(0, 3)} ${digits.substring(3)}';
  }

  /// A short, recognisable area label for a tight row.
  ///
  /// Addresses are saved from the device geocoder, so `area` is often a whole
  /// postal line — "Mufti Mahmood Chowk Bus Stop, Itehad Town Rd, Ittehad
  /// Town Orangi Town, Karachi, Sindh, Pakistan". Printed whole it overflows
  /// any chip.
  ///
  /// The first comma-separated part is the neighbourhood, which is what a
  /// seller actually needs, so that is kept and only truncated if it is still
  /// too long — and then on a word boundary, never mid-word.
  static String areaLabel(String area, {int maxChars = 24}) {
    final first = area.split(',').first.trim();
    final label = first.isEmpty ? area.trim() : first;
    if (label.length <= maxChars) return label;

    // Cut back to the last space so a word is never sliced in half.
    final clipped = label.substring(0, maxChars);
    final lastSpace = clipped.lastIndexOf(' ');
    final safe = lastSpace > maxChars ~/ 2
        ? clipped.substring(0, lastSpace)
        : clipped;
    return '${safe.trimRight()}…';
  }

  /// `AK` — avatar initials.
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
