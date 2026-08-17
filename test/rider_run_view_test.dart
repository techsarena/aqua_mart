import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/localization/app_language.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
import 'package:aqua_mart/features/auth/domain/entities/app_user.dart';
import 'package:aqua_mart/features/auth/domain/entities/user_role.dart';
import 'package:aqua_mart/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the app straight into the rider shell, on the run.
Future<ProviderContainer> _pumpSignedInRider(WidgetTester tester) async {
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
  await container
      .read(sessionProvider.notifier)
      .setLanguage(AppLanguage.english);
  container.read(sessionProvider.notifier).signIn(
    const AppUser(
      id: 'r-1',
      fullName: 'Imran Bashir',
      phone: '+92 300 4412987',
      role: UserRole.rider,
    ),
  );
  await tester.pumpAndSettle();
  // Mock data sources carry a deliberate latency.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('the run opens on the list with the next stop in full', (
    tester,
  ) async {
    await _pumpSignedInRider(tester);

    expect(find.text('Morning run'), findsOneWidget);
    // The next stop is the whole card, not a row in the queue.
    expect(find.text('House 42-B, Gulberg III'), findsOneWidget);
    expect(find.textContaining('Rs 220 cash'), findsOneWidget);
    // The queue behind it.
    expect(find.text('Then'), findsOneWidget);
  });

  testWidgets('the switch moves between the list and the map', (tester) async {
    await _pumpSignedInRider(tester);

    expect(find.text('List'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    // The map states the run's shape, which the list never does.
    expect(find.textContaining('assigned stops'), findsOneWidget);
    expect(find.text('Navigate to stop 1'), findsOneWidget);
    // The list's own headings are gone.
    expect(find.text('Then'), findsNothing);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.text('Then'), findsOneWidget);
    expect(find.textContaining('assigned stops'), findsNothing);
  });
}
