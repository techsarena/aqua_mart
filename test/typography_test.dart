import 'package:aqua_mart/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as ft;

/// Confirms the brand faces are actually bundled and that the two type stacks
/// resolve the way the design system specifies.
void main() {
  ft.TestWidgetsFlutterBinding.ensureInitialized();

  /// Every font declared in pubspec.yaml, with the weight it is mapped to.
  const bundled = <String, int>{
    'assets/fonts/BricolageGrotesque-700.ttf': 700,
    'assets/fonts/BricolageGrotesque-800.ttf': 800,
    'assets/fonts/Figtree-400.ttf': 400,
    'assets/fonts/Figtree-500.ttf': 500,
    'assets/fonts/Figtree-600.ttf': 600,
    'assets/fonts/Figtree-700.ttf': 700,
    'assets/fonts/Figtree-800.ttf': 800,
  };

  group('bundled font assets', () {
    for (final entry in bundled.entries) {
      test('${entry.key} is present and is a valid TrueType file', () async {
        final data = await rootBundle.load(entry.key);
        expect(data.lengthInBytes, greaterThan(1000));

        // TrueType files start with the 0x00010000 sfnt version tag.
        final version = data.getUint32(0);
        expect(
          version,
          0x00010000,
          reason: '${entry.key} is not a TrueType font',
        );
      });
    }

    test('each bundled face can be loaded into the engine', () async {
      for (final path in bundled.keys) {
        final data = await rootBundle.load(path);
        final loader = FontLoader(path)
          ..addFont(Future.value(data.buffer.asByteData()));
        // Throws if the engine rejects the file.
        await loader.load();
      }
    });
  });

  group('type stacks', () {
    test('headings use Bricolage Grotesque, falling back to Figtree', () {
      final style = AppTypography.heading(size: 20);

      expect(style.fontFamily, 'Bricolage Grotesque');
      expect(style.fontFamilyFallback, contains('Figtree'));
      expect(style.fontFamilyFallback, contains('system-ui'));
      expect(style.fontFamilyFallback, contains('sans-serif'));
    });

    test('body text resolves to the platform UI font', () {
      final style = AppTypography.body(size: 14);

      // No explicit family — Flutter falls through to the platform default,
      // which is what -apple-system / system-ui mean.
      expect(style.fontFamily, isNull);
      expect(style.fontFamilyFallback, contains('-apple-system'));
      expect(style.fontFamilyFallback, contains('system-ui'));
    });

    test('brandBody opts into Figtree explicitly', () {
      final style = AppTypography.brandBody(size: 14);
      expect(style.fontFamily, 'Figtree');
    });

    test('heading weights stay within the bundled range', () {
      // Bricolage ships at 700 and 800 only.
      for (final weight in [FontWeight.w700, FontWeight.w800]) {
        final style = AppTypography.heading(size: 20, weight: weight);
        expect(style.fontWeight, weight);
      }
    });

    test('the text theme is wired to both stacks', () {
      final theme = AppTypography.textTheme;

      expect(theme.displayLarge?.fontFamily, 'Bricolage Grotesque');
      expect(theme.headlineSmall?.fontFamily, 'Bricolage Grotesque');
      expect(theme.bodyLarge?.fontFamily, isNull);
      expect(theme.labelMedium?.fontFamily, isNull);
    });
  });

  testWidgets('headings render with the brand face applied', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text('Aqua Mart', style: AppTypography.heading(size: 24)),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Aqua Mart'));
    expect(text.style?.fontFamily, 'Bricolage Grotesque');
    expect(tester.takeException(), isNull);
  });
}
