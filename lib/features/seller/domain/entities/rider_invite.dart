import 'package:equatable/equatable.dart';

/// An invite the seller has sent to a rider's phone, still waiting on a reply.
///
/// Accepted invites are deliberately not modelled here: once a rider accepts,
/// they appear in the seller's rider list, and carrying them in both places
/// would show the same person twice.
class RiderInvite extends Equatable {
  const RiderInvite({
    required this.id,
    required this.phone,
    required this.sentAt,
    this.daysLeft = 0,
  });

  final String id;

  /// E.164, as the server normalised it — never as the seller typed it.
  final String phone;
  final DateTime sentAt;

  /// Whole days before the invite lapses. 0 means it expires today.
  final int daysLeft;

  /// `0301 552 8841` — the design prints the local form, not `+92…`.
  String get phoneLabel {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('92') ? digits.substring(2) : digits;
    if (national.length != 10) return phone;
    return '0${national.substring(0, 3)} ${national.substring(3, 6)} '
        '${national.substring(6)}';
  }

  /// "Sent just now", "Sent 2 days ago · expires in 5".
  ///
  /// Deliberately not `Formatters.relative`: that one falls back to a date
  /// ("17 Aug") past two days and to a clock time within the day, and the
  /// design wants an age in days all the way out.
  String subtitle({DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(sentAt);
    final sent = switch (age) {
      Duration(inMinutes: < 1) => 'Sent just now',
      Duration(inMinutes: final m) when m < 60 => 'Sent $m min ago',
      Duration(inHours: final h) when h < 24 =>
        'Sent $h ${h == 1 ? 'hour' : 'hours'} ago',
      Duration(inDays: final d) => 'Sent $d ${d == 1 ? 'day' : 'days'} ago',
    };

    // The expiry only earns its space once the invite has aged — on a fresh
    // one it just repeats the full window back at the seller.
    return age.inHours < 24 ? sent : '$sent · expires in $daysLeft';
  }

  @override
  List<Object?> get props => [id, phone, sentAt, daysLeft];
}
