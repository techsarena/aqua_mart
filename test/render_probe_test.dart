import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:aqua_mart/core/theme/app_colors.dart';
import 'package:aqua_mart/core/theme/app_spacing.dart';
import 'package:aqua_mart/core/theme/app_theme.dart';
import 'package:aqua_mart/core/utils/formatters.dart';
import 'package:aqua_mart/shared/widgets/app_card.dart';
import 'package:aqua_mart/shared/widgets/app_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _shotKey = GlobalKey();
const _out =
    '/private/tmp/claude-501/-Users-mac-Flutter-Projects-aqua-mart/b80a8446-a6da-4399-9bae-f340d0d65a5b/scratchpad';

Widget _box(Widget child, {Color? color}) => AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      color: color,
      child: child,
    );

Widget _row(int earned) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _box(
              const StatTile(
                value: '18',
                label: 'orders today',
                valueColor: AppColors.surface,
                labelColor: AppColors.onTint,
              ),
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _box(const StatTile(
              value: '11',
              label: 'delivered',
              valueColor: AppColors.accent2_700,
            )),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _box(
              StatTile(
                prefix: 'Rs',
                value: Formatters.rupeesCompact(earned),
                label: 'earned',
                valueColor: AppColors.accent2_700,
                labelColor: AppColors.accent2Deep,
              ),
              color: AppColors.accent2_200,
            ),
          ),
        ],
      ),
    );

void main() {
  testWidgets('probe', (tester) async {
    for (final e in {
      'Figtree': ['Figtree-400.ttf', 'Figtree-600.ttf', 'Figtree-700.ttf',
          'Figtree-800.ttf'],
      'Bricolage Grotesque': ['BricolageGrotesque-700.ttf',
          'BricolageGrotesque-800.ttf'],
    }.entries) {
      final loader = FontLoader(e.key);
      for (final f in e.value) {
        loader.addFont(Future.value(
            ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
      }
      await loader.load();
    }

    tester.view.physicalSize = const Size(402 * 3, 400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: RepaintBoundary(
        key: _shotKey,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _row(4820),
                const SizedBox(height: AppSpacing.md),
                _row(148200),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final image = await (_shotKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    File('$_out/stat_boxes3.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    expect(tester.takeException(), isNull);
  });
}
