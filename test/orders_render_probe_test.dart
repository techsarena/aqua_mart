import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:aqua_mart/core/mock/mock_fixtures.dart';
import 'package:aqua_mart/core/theme/app_colors.dart';
import 'package:aqua_mart/core/theme/app_spacing.dart';
import 'package:aqua_mart/core/theme/app_theme.dart';
import 'package:aqua_mart/features/orders/presentation/screens/order_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  const faces = <String, List<String>>{
    'Figtree': ['assets/fonts/Figtree-400.ttf', 'assets/fonts/Figtree-700.ttf'],
    'Bricolage Grotesque': ['assets/fonts/BricolageGrotesque-700.ttf'],
  };
  for (final entry in faces.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

void main() {
  testWidgets('render order history body', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(402 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('probe'),
        child: ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              backgroundColor: AppColors.bg,
              body: OrderHistoryBody(
                orders: [MockFixtures.activeOrder, ...MockFixtures.pastOrders],
                onRefresh: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final boundary =
        tester.renderObject(find.byKey(const ValueKey('probe')))
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    File(
      '/private/tmp/claude-501/-Users-mac-Flutter-Projects-aqua-mart/'
      '4e40c390-cf55-413a-a7c0-3f959a4a6fce/scratchpad/orders.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
