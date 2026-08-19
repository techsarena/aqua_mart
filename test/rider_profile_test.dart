import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/localization/app_language.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
import 'package:aqua_mart/core/router/app_router.dart';
import 'package:aqua_mart/core/router/app_routes.dart';
import 'package:aqua_mart/features/auth/domain/entities/app_user.dart';
import 'package:aqua_mart/features/auth/domain/entities/user_role.dart';
import 'package:aqua_mart/features/auth/presentation/providers/auth_providers.dart';
import 'package:aqua_mart/features/rider/data/datasources/rider_data_source.dart';
import 'package:aqua_mart/features/rider/domain/entities/rider_run.dart';
import 'package:aqua_mart/features/rider/presentation/providers/rider_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers the two calls the profile makes. Without it the real data source
/// reaches for an absent backend, and Riverpod's retry leaves a pending timer
/// the binding then reports at teardown.
class _FakeRiderDataSource implements RiderRemoteDataSource {
  @override
  Future<RiderEarnings> fetchEarnings() async => const RiderEarnings(
        deliveries: 84,
        perDelivery: 60,
        onTimeBonus: 500,
        fuelAdvance: 300,
        rating: 4.9,
        ratingCount: 62,
        isTopRider: true,
      );

  @override
  Future<RiderRun> fetchRun() async => const RiderRun(
        id: 'RUN-1',
        label: 'Today',
        stops: [],
        sellerName: 'Chashma Pure Water',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Boots the app straight into the rider shell.
Future<ProviderContainer> _pumpSignedInRider(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      riderDataSourceProvider.overrideWithValue(_FakeRiderDataSource()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const AquaMartApp(),
    ),
  );
  await tester.pumpAndSettle();

  await container.read(sessionProvider.notifier).setLanguage(
        AppLanguage.english,
      );
  container.read(sessionProvider.notifier).signIn(
        const AppUser(
          id: 'r-1',
          fullName: 'Imran Ali',
          phone: '+923015528841',
          role: UserRole.rider,
        ),
      );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('the rider shell carries a Me tab', (tester) async {
    await _pumpSignedInRider(tester);

    expect(find.text('Me'), findsOneWidget);
    // The three original tabs must survive the fourth being added.
    expect(find.text('My run'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
  });

  testWidgets('signing out from the rider profile clears the session', (
    tester,
  ) async {
    final container = await _pumpSignedInRider(tester);

    container.read(routerProvider).go(AppRoutes.riderProfilePath);
    await tester.pumpAndSettle();

    expect(find.text('Imran Ali'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    // Confirmed first, so a mid-run mistap does not end the shift.
    expect(find.text('Sign out?'), findsOneWidget);
    expect(container.read(sessionProvider).isSignedIn, isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).isSignedIn, isFalse);
  });

  testWidgets('backing out of the confirm keeps the rider signed in', (
    tester,
  ) async {
    final container = await _pumpSignedInRider(tester);

    container.read(routerProvider).go(AppRoutes.riderProfilePath);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).isSignedIn, isTrue);
  });
}
