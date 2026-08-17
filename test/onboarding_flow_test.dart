import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
import 'package:aqua_mart/core/theme/app_colors.dart';
import 'package:aqua_mart/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real widget tree through the onboarding gates.
///
/// Regression cover for "Continue does nothing on the Who are you? screen",
/// which had two causes: the router rebuilding on every session change (losing
/// the navigation stack), and the rider invitation not being reachable while
/// signed out.
///
/// Registration is four steps with the role LAST: intro → name → phone → OTP
/// → details → role.
Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
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
  return container;
}

/// The intro screen stands in front of every other screen, and "Get started"
/// leads into step 1 of 4 — the mobile number.
///
/// The intro is taller than the 600px test viewport, so the action has to be
/// scrolled into view before it can be tapped.
Future<void> _passIntro(WidgetTester tester) async {
  expect(find.text('Get started'), findsOneWidget);
  await tester.ensureVisible(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  expect(find.text('Your mobile number'), findsOneWidget);
}

/// Walks phone → OTP, leaving the role picker (step 2) on screen.
Future<void> _reachRolePicker(WidgetTester tester) async {
  await _passIntro(tester);

  await tester.enterText(find.byType(TextField).first, '3004412987');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();

  // The OTP screen has its own keypad and verifies as soon as six digits
  // are in, so tap the digits rather than typing into a field.
  expect(find.text('Enter the 6-digit code'), findsOneWidget);
  for (var i = 0; i < 6; i++) {
    await tester.tap(find.widgetWithText(InkWell, '1').first);
    await tester.pumpAndSettle();
  }

  expect(find.text('Who are you?'), findsOneWidget);
  await _drainOtpCountdown(tester);
}

/// The OTP screen is pushed, not replaced, so it stays alive beneath the
/// later steps and its 30s resend countdown keeps ticking. Let the countdown
/// run out before a test ends, or the binding reports a pending timer.
Future<void> _drainOtpCountdown(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 31));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the intro leads into the first registration step', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _passIntro(tester);
  });

  testWidgets('choosing a language on the intro records it', (tester) async {
    final container = await _pumpApp(tester);

    // The language bar sits in the hero at the top of the page.
    await tester.ensureVisible(find.text('اردو'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).hasLanguage, isTrue);
  });

  testWidgets('the phone step will not send a code while empty', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _passIntro(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send code'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('every step shows a back button and the progress track', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _passIntro(tester);

    // Step 1 is the first pushed route, so it can be popped back to the
    // intro, and the track draws one segment per step.
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);

    final segments = find.byWidgetPredicate(
      (w) =>
          w is AnimatedContainer &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == AppColors.accent,
    );
    expect(segments, findsOneWidget, reason: 'one filled segment on step 1');

    // Back returns to the intro.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('the role picker is the second step', (tester) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    expect(find.text('2 of 4'), findsOneWidget);

    // Choosing a role is the whole step, so the tap advances on its own —
    // there is no Continue button to confirm against.
    expect(find.widgetWithText(FilledButton, 'Continue'), findsNothing);
    expect(find.text('I need water'), findsOneWidget);
  });

  testWidgets('a customer continues from the role to the name step', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    await tester.tap(find.text('I need water'));
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('3 of 4'), findsOneWidget);
  });

  testWidgets('rider role opens rider registration', (tester) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    await tester.tap(find.text('I deliver'));
    // Like the seller, the rider's account is created here so they are signed
    // in before a route outside the onboarding stack; the mock takes 600ms.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Riders skip the customer's name and details steps for their own.
    expect(find.text('Who are you?'), findsNothing);
    expect(find.text('Your name and CNIC'), findsOneWidget);
  });

  testWidgets('the rider registration runs its three steps', (tester) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    await tester.tap(find.text('I deliver'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 3 of 5 — Continue waits on a name and a full 13-digit CNIC.
    await tester.enterText(find.byType(TextField).at(0), 'Imran Bashir');
    await tester.enterText(find.byType(TextField).at(1), '3520288412345');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 4 of 5 — a vehicle that needs a plate reveals the field.
    expect(find.text('What do you deliver on?'), findsOneWidget);
    await tester.tap(find.text('Motorbike'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'KMR-4471');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 5 of 5 — the code resolves to the seller who issued it.
    expect(find.text('Who invited you?'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'MW7K2I');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Malik Water Supply'), findsOneWidget);
    await tester.ensureVisible(find.text('Join Malik Water Supply'));
    await tester.tap(find.text('Join Malik Water Supply'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // The wait, carrying the vehicle from step 4.
    expect(find.text('Malik Water Supply is reviewing you'), findsOneWidget);
    expect(find.textContaining('KMR-4471'), findsOneWidget);

    // Calling stands in for dialling for now and opens the rider's run. The
    // run is a shell tab, so a push here would mount a second shell and trip
    // the navigator's key reservation.
    await tester.tap(find.text('Call Malik Water Supply'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Morning run'), findsOneWidget);
  });

  testWidgets('picking the seller role opens business registration', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    // Sellers skip the personal name and details steps — the business is what
    // gets registered, and the owner name is collected there instead.
    await tester.tap(find.text('I sell water'));
    // The account is created here so the seller is signed in before the
    // route, and the mock repository takes 600ms.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsNothing);
    expect(find.text('A little about you'), findsNothing);
    // Signed in before this route, or the redirect sends them to the intro.
    expect(find.text('Your water business'), findsOneWidget);
  });

  testWidgets('the seller registration runs all four business steps', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    await tester.tap(find.text('I sell water'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 1 of 4 — the business. Continue stays disabled until a type is picked.
    await tester.enterText(find.byType(TextField).at(0), 'Chashma Pure Water');
    await tester.enterText(find.byType(TextField).at(1), 'Imran Ali');
    await tester.tap(find.text('RO plant'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 2 of 4 — the required documents gate the step.
    expect(find.text("Prove it's you"), findsOneWidget);
    await tester.tap(find.text('CNIC — front & back'));
    await tester.tap(find.text('Water testing certificate'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 3 of 4 — a size seeds its own prices, so it is priced once selected.
    expect(find.text('What do you sell?'), findsOneWidget);
    await tester.tap(find.text('25 L cooler bottle'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The waiting room, reflecting what was entered on step 1.
    expect(find.text("We're checking your papers"), findsOneWidget);
    expect(find.textContaining('Chashma Pure Water'), findsOneWidget);
  });

  testWidgets('the chosen role is recorded on the session', (tester) async {
    final container = await _pumpApp(tester);
    await _reachRolePicker(tester);

    // Customer is the one role that does not create its account at this step
    // — sellers and riders both sign in here and route onward — so the
    // pending role can be read before anything has been committed.
    await tester.tap(find.text('I need water'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).pendingRole?.name, 'customer');
  });
}
