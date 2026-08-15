import 'package:equatable/equatable.dart';

/// What kind of thing happened — drives the icon and tint.
enum NotificationKind {
  orderUpdate,
  riderOnTheWay,
  priceChange,
  reorderReminder,
  khataDue,
  stockLow,
  complaint,
  payout,
  review,
  riderRun;

  /// Alerts the recipient must act on are pulled to the top and tinted.
  bool get needsAction =>
      this == NotificationKind.complaint ||
      this == NotificationKind.stockLow ||
      this == NotificationKind.khataDue;
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.deepLink,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Route to open when tapped — e.g. `/customer/order/o-1/track`.
  final String? deepLink;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    deepLink: deepLink,
  );

  @override
  List<Object?> get props => [id, kind, title, isRead];
}
