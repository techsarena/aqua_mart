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

/// The language gate stands in front of every other screen.
Future<void> _passLanguageGate(WidgetTester tester) async {
  expect(find.text('Choose your language'), findsOneWidget);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  expect(find.text('Who are you?'), findsOneWidget);
}

void main() {
  testWidgets('language gate leads to the role picker', (tester) async {
    await _pumpApp(tester);
    await _passLanguageGate(tester);
  });

  testWidgets('Continue is disabled until a role is chosen', (tester) async {
    await _pumpApp(tester);
    await _passLanguageGate(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('customer role continues to the name step', (tester) async {
    await _pumpApp(tester);
    await _passLanguageGate(tester);

    await tester.tap(find.text('I need water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);
  });

  testWidgets('seller role continues to business registration', (tester) async {
    await _pumpApp(tester);
    await _passLanguageGate(tester);

    await tester.tap(find.text('I sell water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What should we call you?'), findsOneWidget);
  });

  testWidgets('rider role reaches the invitation while signed out', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _passLanguageGate(tester);

    await tester.tap(find.text('I deliver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Previously bounced straight back to the role picker.
    expect(find.text('Who are you?'), findsNothing);
    expect(find.textContaining('wants you as their rider'), findsOneWidget);
  });

  testWidgets('the chosen role survives the navigation', (tester) async {
    final container = await _pumpApp(tester);
    await _passLanguageGate(tester);

    await tester.tap(find.text('I need water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider).pendingRole?.name, 'customer');
  });
}
