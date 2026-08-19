import 'api_environment.dart';

/// Single registry of every REST path the app will call.
///
/// Keeping them here means the backend contract lives in one file — when the
/// real API lands, only the paths and the `baseUrl` change.
abstract final class ApiEndpoints {
  /// Kept as an alias so call sites need not know about [ApiEnvironment].
  static const baseUrl = ApiEnvironment.baseUrl;

  // ── Auth ────────────────────────────────────────────────────────────────
  static const requestOtp = '/auth/otp/request';
  static const verifyOtp = '/auth/otp/verify';
  static const refreshToken = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const completeProfile = '/auth/profile';

  // ── Catalogue ───────────────────────────────────────────────────────────
  static const sellers = '/sellers';
  static String seller(String id) => '/sellers/$id';
  static String sellerBottles(String id) => '/sellers/$id/bottles';
  static const searchSellers = '/sellers/search';
  static const sellersNearby = '/sellers/nearby';

  // ── Orders ──────────────────────────────────────────────────────────────
  static const orders = '/orders';
  static String order(String id) => '/orders/$id';
  static String cancelOrder(String id) => '/orders/$id/cancel';
  static String trackOrder(String id) => '/orders/$id/tracking';
  static String rateOrder(String id) => '/orders/$id/rating';
  static String reportOrder(String id) => '/orders/$id/report';
  static String reorder(String id) => '/orders/$id/reorder';

  // ── Addresses ───────────────────────────────────────────────────────────
  static const addresses = '/addresses';
  static String address(String id) => '/addresses/$id';
  static String defaultAddress(String id) => '/addresses/$id/default';

  // ── Wallet & payments ───────────────────────────────────────────────────
  static const wallet = '/wallet';
  static const walletTopUp = '/wallet/top-up';
  static String topUpStatus(String id) => '/wallet/top-up/$id';
  static const walletTransactions = '/wallet/transactions';
  static const cards = '/payment-methods/cards';
  static const khata = '/khata';

  // ── Empties ─────────────────────────────────────────────────────────────
  static const empties = '/empties';
  static const emptiesReturn = '/empties/return';
  static const emptiesPickup = '/empties/pickup';

  // ── Notifications ───────────────────────────────────────────────────────
  static const notifications = '/notifications';
  static String notification(String id) => '/notifications/$id';
  static const markAllRead = '/notifications/read-all';
  // POST registers this device for push, DELETE drops it (§9.1).
  static const devices = '/notifications/devices';

  // ── Seller ──────────────────────────────────────────────────────────────
  static const sellerRegister = '/seller/register';
  static const sellerDocuments = '/seller/documents';
  static const sellerVerification = '/seller/verification';
  static const sellerDashboard = '/seller/dashboard';
  static const sellerOrders = '/seller/orders';
  static String acceptOrder(String id) => '/seller/orders/$id/accept';
  static String declineOrder(String id) => '/seller/orders/$id/decline';
  static String advanceOrder(String id) => '/seller/orders/$id/advance';
  static String assignRider(String id) => '/seller/orders/$id/assign';
  static const sellerInventory = '/seller/inventory';
  static String sellerBottle(String id) => '/seller/inventory/$id';
  static const serviceArea = '/seller/service-area';
  static const businessHours = '/seller/hours';
  static const payouts = '/seller/payouts';
  static String payout(String id) => '/seller/payouts/$id';
  static const sellerRiders = '/seller/riders';
  static const inviteRider = '/seller/riders/invite';
  static const riderCode = '/seller/riders/code';
  static const riderInvites = '/seller/riders/invitations';
  static String resendRiderInvite(String id) =>
      '/seller/riders/invitations/$id/resend';
  static String cancelRiderInvite(String id) =>
      '/seller/riders/invitations/$id';
  static const disputes = '/seller/disputes';
  static String resolveDispute(String id) => '/seller/disputes/$id/resolve';
  static const toggleStoreOpen = '/seller/open';
  static String sellerDispute(String id) => '/seller/disputes/$id';

  // ── Rider ───────────────────────────────────────────────────────────────
  static const riderRun = '/rider/run';
  static String completeStop(String id) => '/rider/stops/$id/complete';
  static String failStop(String id) => '/rider/stops/$id/fail';
  static const riderCashHandover = '/rider/cash-handover';
  static const riderEarnings = '/rider/earnings';
  static const riderInvitations = '/rider/invitations';
  static String respondInvitation(String id) => '/rider/invitations/$id';
  static String sellerCode(String code) => '/rider/seller-codes/$code';
  static const riderApplication = '/rider/application';
}
