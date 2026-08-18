import 'package:aqua_mart/features/seller_onboarding/presentation/screens/seller_kyc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CNIC source sheet matches the designed action hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SellerKycScreen())),
    );

    await tester.tap(find.text('CNIC — front'));
    await tester.pumpAndSettle();

    expect(find.text('Add CNIC photo'), findsOneWidget);
    expect(find.text('Front side first, then the back.'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Use the camera now'), findsOneWidget);
    expect(find.text('Upload from gallery'), findsOneWidget);
    expect(find.text('Pick a photo you already have'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
