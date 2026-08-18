import 'package:equatable/equatable.dart';

/// Whether the seller's books and stock are in step with their ERP.
///
/// The design makes this visible rather than silent: an offline banner on
/// Today and a sync row in Profile.
class ErpSyncState extends Equatable {
  const ErpSyncState({
    required this.isOnline,
    this.pendingUploads = 0,
    this.lastSyncedAt,
  });

  final bool isOnline;

  /// Orders taken while offline, waiting to upload.
  final int pendingUploads;
  final DateTime? lastSyncedAt;

  bool get hasBacklog => pendingUploads > 0;

  @override
  List<Object?> get props => [isOnline, pendingUploads, lastSyncedAt];
}

/// The seller's day at a glance.
class SellerDashboard extends Equatable {
  const SellerDashboard({
    required this.ordersToday,
    required this.delivered,
    required this.earned,
    required this.isOpen,
    required this.sync,
    this.businessName = '',
    this.isVerified = false,
    this.pendingCount = 0,
    this.lowStockLabel,
  });

  /// The store's own name — what the header and profile show. Empty until the
  /// dashboard loads, so call sites fall back rather than printing nothing.
  final String businessName;

  /// True once the store is approved, which is what the "Verified seller"
  /// badge means.
  final bool isVerified;

  final int ordersToday;
  final int delivered;
  final int earned;

  /// Turning this off hides the seller from the app without deleting anything.
  final bool isOpen;
  final ErpSyncState sync;
  final int pendingCount;

  /// "6L bottles running low — 3 left in stock"
  final String? lowStockLabel;

  SellerDashboard copyWith({bool? isOpen, ErpSyncState? sync}) =>
      SellerDashboard(
        // Carried through: the open/closed toggle copies optimistically, and
        // dropping these would blank the seller's own name on every tap.
        businessName: businessName,
        isVerified: isVerified,
        ordersToday: ordersToday,
        delivered: delivered,
        earned: earned,
        isOpen: isOpen ?? this.isOpen,
        sync: sync ?? this.sync,
        pendingCount: pendingCount,
        lowStockLabel: lowStockLabel,
      );

  @override
  List<Object?> get props => [
    businessName,
    isVerified,
    ordersToday,
    delivered,
    earned,
    isOpen,
    sync,
    pendingCount,
    lowStockLabel,
  ];
}

/// One of the seller's riders.
class Rider extends Equatable {
  const Rider({
    required this.id,
    required this.name,
    required this.status,
    this.stopsLeft = 0,
    this.distanceFromCustomer,
    this.etaMinutes,
    this.delivered = 0,
    this.onTimePercent = 0,
    this.rating = 0,
    this.lateDeliveries = 0,
    this.complaints = 0,
  });

  final String id;
  final String name;
  final RiderStatus status;
  final int stopsLeft;

  /// Used when picking who should take an order.
  final double? distanceFromCustomer;
  final int? etaMinutes;

  // Weekly performance.
  final int delivered;
  final int onTimePercent;
  final double rating;
  final int lateDeliveries;
  final int complaints;

  bool get isAvailable => status != RiderStatus.offDuty;

  /// "On a run · 6 stops left", "Free · at the plant", "Off duty today"
  String get statusLine => switch (status) {
    RiderStatus.onRun => 'On a run · $stopsLeft stops left',
    RiderStatus.idle => 'Free · at the plant',
    RiderStatus.offDuty => 'Off duty today',
  };

  @override
  List<Object?> get props => [id, name, status, delivered];
}

enum RiderStatus {
  onRun('Active'),
  idle('Idle'),
  offDuty('Off');

  const RiderStatus(this.label);
  final String label;
}

/// A weekly payout statement, itemised the way the design lays it out.
class Payout extends Equatable {
  const Payout({
    required this.id,
    required this.weekLabel,
    required this.ordersDelivered,
    required this.grossSales,
    required this.depositsTaken,
    required this.depositsRefunded,
    required this.commission,
    required this.complaintRefunds,
    required this.cashCollectedByRiders,
    required this.netPaid,
    required this.isPaid,
    this.paidAt,
    this.bankLabel,
    this.reference,
  });

  final String id;
  final String weekLabel;
  final int ordersDelivered;
  final int grossSales;
  final int depositsTaken;
  final int depositsRefunded;
  final int commission;
  final int complaintRefunds;

  /// Already in the seller's hands, so it is netted off the transfer.
  final int cashCollectedByRiders;
  final int netPaid;
  final bool isPaid;
  final DateTime? paidAt;
  final String? bankLabel;
  final String? reference;

  @override
  List<Object?> get props => [id, weekLabel, netPaid, isPaid];
}

/// A customer complaint the seller must settle.
class Dispute extends Equatable {
  const Dispute({
    required this.id,
    required this.orderReference,
    required this.customerName,
    required this.reason,
    required this.customerNote,
    required this.orderSummary,
    required this.amount,
    required this.raisedAt,
    this.customerHistory,
    this.hasPhoto = false,
  });

  final String id;
  final String orderReference;
  final String customerName;
  final String reason;
  final String customerNote;
  final String orderSummary;
  final int amount;
  final DateTime raisedAt;

  /// Context that helps the seller judge — "Her first complaint in 14 orders."
  final String? customerHistory;
  final bool hasPhoto;

  /// Settle within 24 hrs and it won't affect the rating.
  Duration get timeLeft =>
      const Duration(hours: 24) - DateTime.now().difference(raisedAt);

  @override
  List<Object?> get props => [id, orderReference, reason];
}

/// How the seller chooses to settle a complaint.
enum DisputeResolution {
  replacement('Send a free replacement'),
  refund('Refund the customer'),
  escalate('I disagree — send it to Aqua Mart');

  const DisputeResolution(this.label);
  final String label;
}
