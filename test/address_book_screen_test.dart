import 'package:aqua_mart/core/router/app_routes.dart';
import 'package:aqua_mart/features/addresses/domain/entities/address.dart';
import 'package:aqua_mart/features/addresses/presentation/providers/address_providers.dart';
import 'package:aqua_mart/features/addresses/presentation/screens/address_book_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _EmptyAddressBookNotifier extends AddressBookNotifier {
  @override
  Future<List<Address>> build() async => const [];
}

void main() {
  testWidgets('an empty address book offers the add-address flow', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.addressBookPath,
      routes: [
        GoRoute(
          path: AppRoutes.addressBookPath,
          name: AppRoutes.addressBook,
          builder: (_, _) => const AddressBookScreen(),
        ),
        GoRoute(
          path: AppRoutes.addAddressPath,
          name: AppRoutes.addAddress,
          builder: (_, _) => const Scaffold(body: Text('Add-address form')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressBookProvider.overrideWith(_EmptyAddressBookNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved addresses'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add address'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add address'));
    await tester.pumpAndSettle();

    expect(find.text('Add-address form'), findsOneWidget);
  });
}
