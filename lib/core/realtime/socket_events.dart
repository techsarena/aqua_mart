/// The realtime event names, server → client and client → server (API_SPEC 8.4/8.5).
///
/// String literals scattered across listeners are how a rename silently stops
/// a screen updating — every subscriber names its event from here.
abstract final class SocketEvents {
  // ── Server → client ─────────────────────────────────────────────────────
  /// Room `order:{id}` and `seller:{id}`. Every transition, including the
  /// unhappy terminals (`cancelledByCustomer`, `rejectedBySeller`).
  static const orderStatus = 'order:status';

  /// Room `seller:{id}`. Fires the seller's new-order sound and badge.
  static const orderNew = 'order:new';

  /// Room `order:{id}`.
  static const riderAssigned = 'order:rider_assigned';

  /// Room `order:{id}`. The one high-frequency event — at most every 10s.
  static const riderLocation = 'rider:location';

  /// Room `rider:{id}`. The whole run object after any change.
  static const runUpdated = 'run:updated';

  /// Room `user:{id}`. Replaces polling `/notifications`.
  static const notificationNew = 'notification:new';

  /// Room `seller:{id}`. Throttled server-side to once per 5s.
  static const sellerDashboard = 'seller:dashboard';

  // ── Client → server ─────────────────────────────────────────────────────
  /// Ownership is validated server-side on every call.
  static const subscribeOrder = 'subscribe:order';
  static const unsubscribeOrder = 'unsubscribe:order';

  /// Riders only, every 10s while on a run. Dropped unless on an active run.
  static const riderPing = 'rider:ping';
}
