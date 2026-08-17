import 'package:equatable/equatable.dart';

import '../../../orders/domain/entities/order_status.dart';

enum StopStatus { pending, delivered, failed }

/// One stop on the rider's run.
class RunStop extends Equatable {
  const RunStop({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.items,
    required this.amountToCollect,
    required this.paymentMethod,
    required this.distanceMetres,
    this.emptiesToCollect = 0,
    this.status = StopStatus.pending,
    this.completedAt,
    this.plot,
  });

  final String id;
  final String orderId;
  final String customerName;
  final String address;
  final String items;

  /// Zero when the order is already paid.
  final int amountToCollect;
  final PaymentMethod paymentMethod;
  final double distanceMetres;
  final int emptiesToCollect;
  final StopStatus status;
  final DateTime? completedAt;

  /// Where the stop sits on the run map, in `Alignment` space (-1..1).
  ///
  /// The backend sends real coordinates; until the Maps SDK is wired in, the
  /// map view plots these directly. Null keeps the stop off the map rather
  /// than pinning it to the centre.
  final ({double x, double y})? plot;

  bool get isCash => paymentMethod.isCollectedByRider;

  /// "Rs 220 cash · take back 2 empties" / "JazzCash (paid)"
  String get collectionLine {
    if (!isCash) return '${paymentMethod.label} (paid)';
    final base = 'Rs $amountToCollect cash';
    return emptiesToCollect > 0
        ? '$base · take back $emptiesToCollect empties'
        : base;
  }

  RunStop copyWith({StopStatus? status, DateTime? completedAt}) => RunStop(
    id: id,
    orderId: orderId,
    customerName: customerName,
    address: address,
    items: items,
    amountToCollect: amountToCollect,
    paymentMethod: paymentMethod,
    distanceMetres: distanceMetres,
    emptiesToCollect: emptiesToCollect,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    plot: plot,
  );

  @override
  List<Object?> get props => [id, orderId, status];
}

/// A rider's shift.
class RiderRun extends Equatable {
  const RiderRun({
    required this.id,
    required this.label,
    required this.stops,
    this.sellerName = '',
    this.finishedAt,
  });

  final String id;

  /// "Morning run"
  final String label;
  final List<RunStop> stops;
  final String sellerName;
  final DateTime? finishedAt;

  List<RunStop> get pending =>
      stops.where((s) => s.status == StopStatus.pending).toList();

  List<RunStop> get delivered =>
      stops.where((s) => s.status == StopStatus.delivered).toList();

  List<RunStop> get failed =>
      stops.where((s) => s.status == StopStatus.failed).toList();

  RunStop? get nextStop => pending.firstOrNull;

  bool get isComplete => pending.isEmpty;

  /// Cash actually taken at the door so far.
  int get cashCollected => delivered
      .where((s) => s.isCash)
      .fold(0, (sum, s) => sum + s.amountToCollect);

  /// Cash still to come on the remaining stops.
  int get cashOutstanding => pending
      .where((s) => s.isCash)
      .fold(0, (sum, s) => sum + s.amountToCollect);

  int get emptiesCollected =>
      delivered.fold(0, (sum, s) => sum + s.emptiesToCollect);

  /// How far the remaining stops run, end to end.
  ///
  /// Each stop's distance is measured from the one before it, so the run
  /// length is their sum rather than the furthest of them.
  double get remainingMetres =>
      pending.fold(0, (sum, s) => sum + s.distanceMetres);

  /// Rough riding time for what is left, at city-traffic pace plus a minute
  /// at each door.
  Duration get remainingDuration => Duration(
    minutes: (remainingMetres / 1000 * 4).round() + pending.length,
  );

  int get cashOrderCount => delivered.where((s) => s.isCash).length;

  int get prepaidCount => delivered
      .where((s) => !s.isCash && s.paymentMethod != PaymentMethod.khata)
      .length;

  int get khataCount =>
      delivered.where((s) => s.paymentMethod == PaymentMethod.khata).length;

  RiderRun copyWith({List<RunStop>? stops, DateTime? finishedAt}) => RiderRun(
    id: id,
    label: label,
    stops: stops ?? this.stops,
    sellerName: sellerName,
    finishedAt: finishedAt ?? this.finishedAt,
  );

  @override
  List<Object?> get props => [id, stops, finishedAt];
}

/// What the rider takes home.
class RiderEarnings extends Equatable {
  const RiderEarnings({
    required this.deliveries,
    required this.perDelivery,
    required this.onTimeBonus,
    required this.fuelAdvance,
    required this.rating,
    required this.ratingCount,
    this.perDayDeliveries = const [],
    this.isTopRider = false,
  });

  final int deliveries;
  final int perDelivery;
  final int onTimeBonus;

  /// Already drawn against, so it comes off the total.
  final int fuelAdvance;
  final double rating;
  final int ratingCount;

  /// Mon–Sun counts, for the weekly bar chart.
  final List<int> perDayDeliveries;
  final bool isTopRider;

  int get gross => deliveries * perDelivery;

  int get netDue => gross + onTimeBonus - fuelAdvance;

  /// The rider's strongest day, used for the "your days" insight.
  int get bestDayIndex {
    if (perDayDeliveries.isEmpty) return 0;
    var best = 0;
    for (var i = 1; i < perDayDeliveries.length; i++) {
      if (perDayDeliveries[i] > perDayDeliveries[best]) best = i;
    }
    return best;
  }

  @override
  List<Object?> get props => [
    deliveries,
    perDelivery,
    onTimeBonus,
    fuelAdvance,
  ];
}

/// The invitation a seller sends a rider.
class RiderInvitation extends Equatable {
  const RiderInvitation({
    required this.id,
    required this.sellerName,
    required this.sentBy,
    required this.sentTo,
    required this.areas,
    required this.hours,
  });

  final String id;
  final String sellerName;
  final String sentBy;
  final String sentTo;

  /// "Gulberg & Model Town"
  final String areas;

  /// "7 AM – 9 PM"
  final String hours;

  @override
  List<Object?> get props => [id, sellerName, sentTo];
}
