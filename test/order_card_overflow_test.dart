import 'package:aqua_mart/core/utils/formatters.dart';
import 'package:aqua_mart/shared/widgets/app_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the tag row from the order card at a real phone width and fails on
/// any overflow, which is what the seller was seeing.
void main() {
  testWidgets('the order card tag row does not overflow', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    const realAddress =
        'Mufti Mahmood Chowk Bus Stop, Itehad Town Rd, Ittehad Town '
        'Orangi Town, Karachi, Pakistan, Orangi Town, Karachi, Sindh, Pakistan';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppTag(Formatters.areaLabel(realAddress)),
                const AppTag('2 × 25L refill'),
                const AppTag('Cash', tone: TagTone.accent),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('even an unshortened label clips instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Flexible(
                  child: AppTag(
                    'Mufti Mahmood Chowk Bus Stop, Itehad Town Rd, Ittehad '
                    'Town Orangi Town, Karachi, Sindh, Pakistan',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
