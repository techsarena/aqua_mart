import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/localization/app_language.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
import 'package:aqua_mart/core/router/app_router.dart';
import 'package:aqua_mart/core/router/app_routes.dart';
import 'package:aqua_mart/features/auth/domain/entities/app_user.dart';
import 'package:aqua_mart/features/auth/domain/entities/user_role.dart';
import 'package:aqua_mart/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression cover for tapping an alert whose deep link is a shell tab.
///
/// `/seller/orders` is a `StatefulShellBranch` root, so pushing it mounted a
/// second copy of the seller shell — and the shell owns navigator `GlobalKey`s,
/// which tripped `!keyReservation.contains(key)` inside `Navigator`.
/// Boots the app straight into the seller shell.
Future<ProviderContainer> _pumpSignedInSeller(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AquaMartApp(),
    ),
  );
  await tester.pumpAndSettle();

  // The router pins a session without a language to the intro screen.
  await container.read(sessionProvider.notifier).setLanguage(
    AppLanguage.english,
  );
  container.read(sessionProvider.notifier).signIn(
    const AppUser(
      id: 's-1',
      fullName: 'Chashma Pure Water',
      phone: '+92 300 4412987',
      role: UserRole.seller,
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('the Bottles tab adds a bottle from its floating action button', (
    tester,
  ) async {
    final container = await _pumpSignedInSeller(tester);

    container.read(routerProvider).go(AppRoutes.sellerInventoryPath);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add bottle'), findsWidgets);
  });

  test('every shell tab path is recognised, detail routes are not', () {
    expect(AppRoutes.isShellTab(AppRoutes.sellerOrderQueuePath), isTrue);
    expect(AppRoutes.isShellTab(AppRoutes.sellerInventoryPath), isTrue);
    expect(AppRoutes.isShellTab(AppRoutes.riderRunPath), isTrue);

    // Root-level detail routes must still be pushed.
    expect(AppRoutes.isShellTab(AppRoutes.payoutStatementPath), isFalse);
    expect(AppRoutes.isShellTab('/seller/disputes/d-1'), isFalse);
    expect(AppRoutes.isShellTab('/customer/order/o-1/track'), isFalse);
  });
}
