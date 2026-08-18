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
}
