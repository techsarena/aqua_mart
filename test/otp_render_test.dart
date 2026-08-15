import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFont(String f, List<String> p) async {
  final l = FontLoader(f);
  for (final x in p) { l.addFont(Future.value(ByteData.sublistView(File(x).readAsBytesSync()))); }
  await l.load();
}

void main() {
  testWidgets('otp renders', (tester) async {
    await loadFont('Figtree', ['assets/fonts/Figtree-400.ttf','assets/fonts/Figtree-600.ttf','assets/fonts/Figtree-700.ttf']);
    await loadFont('Bricolage Grotesque', ['assets/fonts/BricolageGrotesque-700.ttf']);
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const AquaMartApp()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '3004412987');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    // Four digits, like the screenshot.
    for (final d in ['4','1','7','2']) {
      await tester.tap(find.widgetWithText(InkWell, d).first);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    final img = await tester.binding.runAsync(() async {
      final b = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      return b.toImage(pixelRatio: 2);
    });
    final bytes = await img!.toByteData(format: ImageByteFormat.png);
    File(Platform.environment['PNG']!).writeAsBytesSync(bytes!.buffer.asUint8List());
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
  });
}
