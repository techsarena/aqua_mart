import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
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
/// leads into step 1 of 4.
///
/// The intro is taller than the 600px test viewport, so the action has to be
/// scrolled into view before it can be tapped.
Future<void> _passIntro(WidgetTester tester) async {
  expect(find.text('Get started'), findsOneWidget);
  await tester.ensureVisible(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  expect(find.text('What should we call you?'), findsOneWidget);
}

/// Walks name → phone → OTP → details, leaving the role picker on screen.
Future<void> _reachRolePicker(WidgetTester tester) async {
  await _passIntro(tester);

  await tester.enterText(find.byType(TextField).first, 'Ayesha Khan');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();

  expect(find.text('Your mobile number'), findsOneWidget);
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

  // Land on the optional details step, then skip it.
  expect(find.text('A little about you'), findsOneWidget);
  await tester.ensureVisible(find.text('Skip for now'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Skip for now'));
  await tester.pumpAndSettle();

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

    await tester.ensureVisible(find.text('اردو'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).hasLanguage, isTrue);
  });

  testWidgets('the name step will not continue while empty', (tester) async {
    await _pumpApp(tester);
    await _passIntro(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the role picker is the last step', (tester) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    expect(find.text('Last step. You can switch later in settings.'),
        findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull, reason: 'no role chosen yet');
  });

  testWidgets('rider role reaches the invitation while signed out', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    await tester.tap(find.text('I deliver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Previously bounced straight back to the role picker.
    expect(find.text('Who are you?'), findsNothing);
    expect(find.textContaining('wants you as their rider'), findsOneWidget);
  });

  testWidgets('seller role continues to business registration', (tester) async {
    await _pumpApp(tester);
    await _reachRolePicker(tester);

    await tester.tap(find.text('I sell water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Sellers must be signed in before this route, or the redirect sends
    // them back to the intro.
    expect(find.text('Who are you?'), findsNothing);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('the chosen role is recorded on the session', (tester) async {
    final container = await _pumpApp(tester);
    await _reachRolePicker(tester);

    // Rider is the one role that does not sign in and land in an app, so the
    // session can be inspected without pumping into a screen that animates
    // or counts down forever.
    await tester.tap(find.text('I deliver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).pendingRole?.name, 'rider');
  });
}
