import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/addresses/presentation/screens/add_address_screen.dart';
import '../../features/addresses/presentation/screens/address_book_screen.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/intro_screen.dart';
import '../../features/auth/presentation/screens/language_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/role_screen.dart';
import '../../features/auth/presentation/screens/signup_details_screen.dart';
import '../../features/auth/presentation/screens/signup_name_screen.dart';
import '../../features/auth/presentation/screens/signup_phone_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/catalog/presentation/screens/search_results_screen.dart';
import '../../features/catalog/presentation/screens/seller_map_screen.dart';
import '../../features/catalog/presentation/screens/seller_store_screen.dart';
import '../../features/customer/presentation/screens/customer_home_screen.dart';
import '../../features/customer/presentation/screens/customer_profile_screen.dart';
import '../../features/customer/presentation/shell/customer_shell.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/orders/presentation/screens/cancel_order_screen.dart';
import '../../features/orders/presentation/screens/cart_screen.dart';
import '../../features/orders/presentation/screens/checkout_screen.dart';
import '../../features/orders/presentation/screens/order_history_screen.dart';
import '../../features/orders/presentation/screens/order_rejected_screen.dart';
import '../../features/orders/presentation/screens/order_tracking_screen.dart';
import '../../features/orders/presentation/screens/rate_order_screen.dart';
import '../../features/orders/presentation/screens/report_order_screen.dart';
import '../../features/payments/presentation/screens/add_card_screen.dart';
import '../../features/payments/presentation/screens/top_up_pending_screen.dart';
import '../../features/payments/presentation/screens/top_up_result_screen.dart';
import '../../features/payments/presentation/screens/top_up_screen.dart';
import '../../features/payments/presentation/screens/wallet_screen.dart';
import '../../features/empties/presentation/screens/empty_bottles_screen.dart';
import '../../features/rider/presentation/screens/rider_cash_handover_screen.dart';
import '../../features/rider/presentation/screens/rider_earnings_screen.dart';
import '../../features/rider/presentation/screens/rider_identity_screen.dart';
import '../../features/rider/presentation/screens/rider_invitation_screen.dart';
import '../../features/rider/presentation/screens/rider_pending_approval_screen.dart';
import '../../features/rider/presentation/screens/rider_run_screen.dart';
import '../../features/rider/presentation/screens/rider_seller_code_screen.dart';
import '../../features/rider/presentation/screens/rider_vehicle_screen.dart';
import '../../features/rider/presentation/shell/rider_shell.dart';
import '../../features/seller/presentation/screens/assign_rider_screen.dart';
import '../../features/seller/presentation/screens/business_hours_screen.dart';
import '../../features/seller/presentation/screens/dispute_screen.dart';
import '../../features/seller/presentation/screens/edit_bottle_screen.dart';
import '../../features/seller/presentation/screens/payout_statement_screen.dart';
import '../../features/seller/presentation/screens/rider_performance_screen.dart';
import '../../features/seller/presentation/screens/seller_alerts_screen.dart';
import '../../features/seller/presentation/screens/seller_dashboard_screen.dart';
import '../../features/seller/presentation/screens/seller_inventory_screen.dart';
import '../../features/seller/presentation/screens/seller_order_queue_screen.dart';
import '../../features/seller/presentation/screens/seller_profile_screen.dart';
import '../../features/seller/presentation/screens/seller_service_area_screen.dart';
import '../../features/seller/presentation/shell/seller_shell.dart';
import '../../features/seller_onboarding/presentation/screens/seller_catalog_setup_screen.dart';
import '../../features/seller_onboarding/presentation/screens/seller_kyc_screen.dart';
import '../../features/seller_onboarding/presentation/screens/seller_onboarding_screen.dart';
import '../../features/seller_onboarding/presentation/screens/seller_verification_screen.dart';
import 'app_routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _customerShellKey = GlobalKey<NavigatorState>(debugLabel: 'customer');
final _registrationObserver = RouteObserver<ModalRoute<dynamic>>();

/// The app's single [GoRouter].
///
/// Structure:
/// - a flat onboarding stack (intro → phone → OTP → role → name → details)
/// - one `StatefulShellRoute` per role, so each role's tabs keep their own
///   navigation stack
/// - detail routes pushed above the shells on the root navigator
final routerProvider = Provider<GoRouter>((ref) {
  // The router is built once. Session changes are surfaced through
  // `refreshListenable` instead of `ref.watch`, because rebuilding the
  // GoRouter would discard the whole navigation stack on every sign-in step.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    observers: [_registrationObserver],
    initialLocation: AppRoutes.splashPath,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      if (session.isLoading) return null;

      final location = state.matchedLocation;
      final inOnboarding =
          location == AppRoutes.splashPath ||
          location.startsWith('/intro') ||
          location.startsWith('/language') ||
          location.startsWith('/role') ||
          location.startsWith('/signup') ||
          // Riders are invited rather than self-serve, so the invitation is
          // reachable before they have a session.
          location == AppRoutes.riderInvitationPath ||
          // Rider registration continues the sign-up under /rider, so these
          // steps are part of the onboarding stack despite the path.
          location.startsWith('/rider/signup');

      // Language is chosen on the intro screen rather than at its own gate,
      // so a first run starts there and registration follows in four steps.
      if (!session.hasLanguage) {
        return location == AppRoutes.introPath ? null : AppRoutes.introPath;
      }

      // Signed out: stay inside the onboarding stack.
      if (!session.isSignedIn) {
        if (location == AppRoutes.splashPath) return AppRoutes.introPath;
        return inOnboarding ? null : AppRoutes.introPath;
      }

      final resumeRoute = session.registrationRoute;
      if (resumeRoute != null) {
        // A verified provisional session must resume instead of being sent to
        // a role home. Registration routes remain freely navigable so Back
        // works; each route checkpoints itself when it becomes visible.
        if (_isResumableRegistrationPath(location)) return null;
        if (location == AppRoutes.splashPath || inOnboarding) {
          return resumeRoute;
        }
      }

      // Migration/fallback for a provisional account created before local
      // route checkpoints existed.
      if (session.user?.isProfileComplete == false) {
        return _isResumableRegistrationPath(location)
            ? null
            : AppRoutes.rolePath;
      }

      // Signed in but sitting on an onboarding screen — send them to their app.
      // The rider screens are exempt: a rider signs in at the role step and
      // then still has registration to finish, or an invitation to answer.
      final isRiderStep =
          location == AppRoutes.riderInvitationPath ||
          location.startsWith('/rider/signup');

      if (inOnboarding && !isRiderStep) {
        return _homeFor(session.activeRole);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splashPath,
        name: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),

      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.introPath,
        name: AppRoutes.intro,
        builder: (_, _) => const IntroScreen(),
      ),
      // Still reachable from settings, where the language can be changed.
      GoRoute(
        path: AppRoutes.languagePath,
        name: AppRoutes.languagePicker,
        builder: (_, _) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.rolePath,
        name: AppRoutes.rolePicker,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.rolePath,
          child: RoleScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUpNamePath,
        name: AppRoutes.signUpName,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.signUpNamePath,
          child: SignUpNameScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUpPhonePath,
        name: AppRoutes.signUpPhone,
        builder: (_, _) => const SignUpPhoneScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpPath,
        name: AppRoutes.otp,
        builder: (_, _) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUpDetailsPath,
        name: AppRoutes.signUpDetails,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.signUpDetailsPath,
          child: SignUpDetailsScreen(),
        ),
      ),

      // ── Customer shell ──────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _customerShellKey,
            routes: [
              GoRoute(
                path: AppRoutes.customerHomePath,
                name: AppRoutes.customerHome,
                builder: (_, _) => const CustomerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customerOrdersPath,
                name: AppRoutes.customerOrders,
                builder: (_, _) => const OrderHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customerTrackPath,
                name: AppRoutes.customerTrack,
                builder: (_, _) => const OrderTrackingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customerProfilePath,
                name: AppRoutes.customerProfile,
                builder: (_, _) => const CustomerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Customer detail routes ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.sellerStorePath,
        name: AppRoutes.sellerStore,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            SellerStoreScreen(sellerId: state.pathParameters['sellerId']!),
      ),
      GoRoute(
        path: AppRoutes.cartPath,
        name: AppRoutes.cart,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkoutPath,
        name: AppRoutes.checkout,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.addCardPath,
        name: AppRoutes.addCard,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AddCardScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderTrackingPath,
        name: AppRoutes.orderTracking,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['orderId']),
      ),
      GoRoute(
        path: AppRoutes.rateOrderPath,
        name: AppRoutes.rateOrder,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            RateOrderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.reportOrderPath,
        name: AppRoutes.reportOrder,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ReportOrderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.cancelOrderPath,
        name: AppRoutes.cancelOrder,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            CancelOrderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.orderRejectedPath,
        name: AppRoutes.orderRejected,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            OrderRejectedScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.searchPath,
        name: AppRoutes.searchResults,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            SearchResultsScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: AppRoutes.sellerMapPath,
        name: AppRoutes.sellerMap,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.addressBookPath,
        name: AppRoutes.addressBook,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AddressBookScreen(),
      ),
      GoRoute(
        path: AppRoutes.addAddressPath,
        name: AppRoutes.addAddress,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            AddAddressScreen(addressId: state.uri.queryParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.notificationsPath,
        name: AppRoutes.notifications,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.walletPath,
        name: AppRoutes.wallet,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.topUpPath,
        name: AppRoutes.topUp,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const TopUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.topUpPendingPath,
        name: AppRoutes.topUpPending,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => TopUpPendingScreen(
          amount:
              int.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 1000,
          topUpId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.topUpResultPath,
        name: AppRoutes.topUpResult,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => TopUpResultScreen(
          amount:
              int.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 1000,
          succeeded: state.uri.queryParameters['status'] != 'failed',
        ),
      ),
      GoRoute(
        path: AppRoutes.emptyBottlesPath,
        name: AppRoutes.emptyBottles,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const EmptyBottlesScreen(),
      ),

      // ── Seller onboarding ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.sellerOnboardingPath,
        name: AppRoutes.sellerOnboarding,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.sellerOnboardingPath,
          child: SellerOnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerKycPath,
        name: AppRoutes.sellerKyc,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.sellerKycPath,
          child: SellerKycScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerCatalogSetupPath,
        name: AppRoutes.sellerCatalogSetup,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.sellerCatalogSetupPath,
          child: SellerCatalogSetupScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.sellerVerificationPath,
        name: AppRoutes.sellerVerification,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.sellerVerificationPath,
          child: SellerVerificationScreen(),
        ),
      ),

      // ── Seller shell ────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => SellerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sellerDashboardPath,
                name: AppRoutes.sellerDashboard,
                builder: (_, _) => const SellerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sellerOrderQueuePath,
                name: AppRoutes.sellerOrderQueue,
                builder: (_, _) => const SellerOrderQueueScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sellerInventoryPath,
                name: AppRoutes.sellerInventory,
                builder: (_, _) => const SellerInventoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sellerServiceAreaPath,
                name: AppRoutes.sellerServiceArea,
                builder: (_, _) => const SellerServiceAreaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sellerProfilePath,
                name: AppRoutes.sellerProfile,
                builder: (_, _) => const SellerProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Seller detail routes ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.sellerEditBottlePath,
        name: AppRoutes.sellerEditBottle,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            EditBottleScreen(bottleId: state.pathParameters['bottleId']!),
      ),
      GoRoute(
        path: AppRoutes.sellerAlertsPath,
        name: AppRoutes.sellerAlerts,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SellerAlertsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sellerDisputePath,
        name: AppRoutes.sellerDispute,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            DisputeScreen(disputeId: state.pathParameters['disputeId']!),
      ),
      GoRoute(
        path: AppRoutes.assignRiderPath,
        name: AppRoutes.assignRider,
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            AssignRiderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.businessHoursPath,
        name: AppRoutes.businessHours,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const BusinessHoursScreen(),
      ),
      GoRoute(
        path: AppRoutes.payoutStatementPath,
        name: AppRoutes.payoutStatement,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PayoutStatementScreen(),
      ),
      GoRoute(
        path: AppRoutes.riderPerformancePath,
        name: AppRoutes.riderPerformance,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const RiderPerformanceScreen(),
      ),

      // ── Rider shell ─────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RiderShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.riderRunPath,
                name: AppRoutes.riderRun,
                builder: (_, _) => const RiderRunScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.riderCashHandoverPath,
                name: AppRoutes.riderCashHandover,
                builder: (_, _) => const RiderCashHandoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.riderEarningsPath,
                name: AppRoutes.riderEarnings,
                builder: (_, _) => const RiderEarningsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.riderInvitationPath,
        name: AppRoutes.riderInvitation,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const RiderInvitationScreen(),
      ),

      // ── Rider registration, steps 3–5 ───────────────────────────────────
      // Outside the shell: a rider works through these before there is a run
      // to show them.
      GoRoute(
        path: AppRoutes.riderIdentityPath,
        name: AppRoutes.riderIdentity,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.riderIdentityPath,
          child: RiderIdentityScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.riderVehiclePath,
        name: AppRoutes.riderVehicle,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.riderVehiclePath,
          child: RiderVehicleScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.riderSellerCodePath,
        name: AppRoutes.riderSellerCode,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.riderSellerCodePath,
          child: RiderSellerCodeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.riderPendingApprovalPath,
        name: AppRoutes.riderPendingApproval,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const _RegistrationCheckpoint(
          route: AppRoutes.riderPendingApprovalPath,
          child: RiderPendingApprovalScreen(),
        ),
      ),
    ],
  );
});

String _homeFor(UserRole role) => switch (role) {
  UserRole.customer => AppRoutes.customerHomePath,
  UserRole.seller => AppRoutes.sellerDashboardPath,
  UserRole.rider => AppRoutes.riderRunPath,
};

bool _isResumableRegistrationPath(String location) =>
    location == AppRoutes.rolePath ||
    location == AppRoutes.signUpNamePath ||
    location == AppRoutes.signUpDetailsPath ||
    location.startsWith('/seller/onboarding') ||
    location.startsWith('/rider/signup');

/// Persists the visible registration route, including when Back reveals it.
class _RegistrationCheckpoint extends ConsumerStatefulWidget {
  const _RegistrationCheckpoint({required this.route, required this.child});

  final String route;
  final Widget child;

  @override
  ConsumerState<_RegistrationCheckpoint> createState() =>
      _RegistrationCheckpointState();
}

class _RegistrationCheckpointState
    extends ConsumerState<_RegistrationCheckpoint>
    with RouteAware {
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _checkpoint();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route || route == null) return;
    if (_route != null) _registrationObserver.unsubscribe(this);
    _route = route;
    _registrationObserver.subscribe(this, route);
  }

  void _checkpoint() {
    Future.microtask(() {
      if (mounted && ref.read(sessionProvider).isSignedIn) {
        ref.read(sessionProvider.notifier).checkpointRegistration(widget.route);
      }
    });
  }

  @override
  void didPush() => _checkpoint();

  @override
  void didPopNext() => _checkpoint();

  @override
  void dispose() {
    _registrationObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
