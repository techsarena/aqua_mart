/// Every named route in the app, in one registry.
///
/// Paths are grouped by role. Names are what the app navigates by
/// (`context.goNamed(AppRoutes.customerHome)`), so screens never hard-code
/// path strings.
abstract final class AppRoutes {
  // ── Onboarding & auth ───────────────────────────────────────────────────
  static const splash = 'splash';
  static const splashPath = '/';

  /// The intro — the hero, the three promises, and the language pills.
  static const intro = 'intro';
  static const introPath = '/intro';

  static const languagePicker = 'language';
  static const languagePath = '/language';

  static const rolePicker = 'role';
  static const rolePath = '/role';

  static const signUpName = 'signup-name';
  static const signUpNamePath = '/signup/name';

  static const signUpPhone = 'signup-phone';
  static const signUpPhonePath = '/signup/phone';

  static const otp = 'otp';
  static const otpPath = '/signup/otp';

  static const signUpDetails = 'signup-details';
  static const signUpDetailsPath = '/signup/details';

  // ── Customer ────────────────────────────────────────────────────────────
  static const customerHome = 'customer-home';
  static const customerHomePath = '/customer/home';

  static const customerOrders = 'customer-orders';
  static const customerOrdersPath = '/customer/orders';

  static const customerTrack = 'customer-track';
  static const customerTrackPath = '/customer/track';

  static const customerProfile = 'customer-profile';
  static const customerProfilePath = '/customer/profile';

  static const sellerStore = 'seller-store';
  static const sellerStorePath = '/customer/seller/:sellerId';

  static const cart = 'cart';
  static const cartPath = '/customer/cart';

  static const checkout = 'checkout';
  static const checkoutPath = '/customer/checkout';

  static const addCard = 'add-card';
  static const addCardPath = '/customer/checkout/card';

  static const orderTracking = 'order-tracking';
  static const orderTrackingPath = '/customer/order/:orderId/track';

  static const rateOrder = 'rate-order';
  static const rateOrderPath = '/customer/order/:orderId/rate';

  static const reportOrder = 'report-order';
  static const reportOrderPath = '/customer/order/:orderId/report';

  static const cancelOrder = 'cancel-order';
  static const cancelOrderPath = '/customer/order/:orderId/cancel';

  static const orderRejected = 'order-rejected';
  static const orderRejectedPath = '/customer/order/:orderId/rejected';

  static const searchResults = 'search';
  static const searchPath = '/customer/search';

  static const sellerMap = 'seller-map';
  static const sellerMapPath = '/customer/map';

  static const addressBook = 'addresses';
  static const addressBookPath = '/customer/addresses';

  static const addAddress = 'add-address';
  static const addAddressPath = '/customer/addresses/new';

  static const notifications = 'notifications';
  static const notificationsPath = '/customer/notifications';

  static const wallet = 'wallet';
  static const walletPath = '/customer/wallet';

  static const topUp = 'top-up';
  static const topUpPath = '/customer/wallet/top-up';

  static const topUpPending = 'top-up-pending';
  static const topUpPendingPath = '/customer/wallet/top-up/pending';

  static const topUpResult = 'top-up-result';
  static const topUpResultPath = '/customer/wallet/top-up/result';

  static const emptyBottles = 'empties';
  static const emptyBottlesPath = '/customer/empties';

  // ── Seller ──────────────────────────────────────────────────────────────
  static const sellerOnboarding = 'seller-onboarding';
  static const sellerOnboardingPath = '/seller/onboarding';

  static const sellerKyc = 'seller-kyc';
  static const sellerKycPath = '/seller/onboarding/kyc';

  static const sellerCatalogSetup = 'seller-catalog-setup';
  static const sellerCatalogSetupPath = '/seller/onboarding/catalog';

  static const sellerVerification = 'seller-verification';
  static const sellerVerificationPath = '/seller/onboarding/verification';

  static const sellerDashboard = 'seller-dashboard';
  static const sellerDashboardPath = '/seller/today';

  static const sellerOrderQueue = 'seller-orders';
  static const sellerOrderQueuePath = '/seller/orders';

  static const sellerInventory = 'seller-inventory';
  static const sellerInventoryPath = '/seller/bottles';

  static const sellerEditBottle = 'seller-edit-bottle';
  static const sellerEditBottlePath = '/seller/bottles/:bottleId';

  static const sellerServiceArea = 'seller-area';
  static const sellerServiceAreaPath = '/seller/area';

  static const sellerProfile = 'seller-profile';
  static const sellerProfilePath = '/seller/profile';

  static const sellerAlerts = 'seller-alerts';
  static const sellerAlertsPath = '/seller/alerts';

  static const sellerDispute = 'seller-dispute';
  static const sellerDisputePath = '/seller/disputes/:disputeId';

  static const assignRider = 'assign-rider';
  static const assignRiderPath = '/seller/orders/:orderId/assign';

  static const businessHours = 'business-hours';
  static const businessHoursPath = '/seller/hours';

  static const payoutStatement = 'payout';
  static const payoutStatementPath = '/seller/payouts';

  static const riderPerformance = 'rider-performance';
  static const riderPerformancePath = '/seller/riders';

  static const inviteRider = 'invite-rider';
  static const inviteRiderPath = '/seller/riders/invite';

  /// The confirmation shown after an invite goes out. Its own route rather
  /// than a flag on the form, so backing out of it lands on the riders list
  /// instead of a form still holding a number that was already sent.
  static const riderInvites = 'rider-invites';
  static const riderInvitesPath = '/seller/riders/invites';

  // ── Rider ───────────────────────────────────────────────────────────────
  static const riderRun = 'rider-run';
  static const riderRunPath = '/rider/run';

  static const riderCashHandover = 'rider-cash';
  static const riderCashHandoverPath = '/rider/cash';

  static const riderEarnings = 'rider-earnings';
  static const riderEarningsPath = '/rider/earnings';

  static const riderInvitation = 'rider-invitation';
  static const riderInvitationPath = '/rider/invitation';

  /// Rider registration, steps 3–5 of the sign-up. Riders branch here from
  /// the role step instead of finishing the customer's personal details.
  static const riderIdentity = 'rider-identity';
  static const riderIdentityPath = '/rider/signup/identity';

  static const riderVehicle = 'rider-vehicle';
  static const riderVehiclePath = '/rider/signup/vehicle';

  static const riderSellerCode = 'rider-seller-code';
  static const riderSellerCodePath = '/rider/signup/code';

  static const riderPendingApproval = 'rider-pending';
  static const riderPendingApprovalPath = '/rider/signup/pending';

  /// The tab roots of the three shells.
  ///
  /// These must be switched to with `go`, never `push`ed: pushing one mounts a
  /// second copy of the shell, and the shell owns navigator `GlobalKey`s — so
  /// the duplicate reservation trips an assertion inside `Navigator`.
  static const shellTabPaths = <String>{
    customerHomePath,
    customerOrdersPath,
    customerTrackPath,
    customerProfilePath,
    sellerDashboardPath,
    sellerOrderQueuePath,
    sellerInventoryPath,
    sellerServiceAreaPath,
    sellerProfilePath,
    riderRunPath,
    riderCashHandoverPath,
    riderEarningsPath,
  };

  /// Whether [location] should be navigated to with `go` rather than `push`.
  static bool isShellTab(String location) =>
      shellTabPaths.contains(Uri.parse(location).path);
}
