import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale.
///
/// Two stacks, matching the design system:
///
/// - headings: `Bricolage Grotesque, Figtree, system-ui, sans-serif`
/// - body:     `-apple-system, system-ui, sans-serif` — the platform UI font
///
/// Both brand faces ship as bundled static instances (see `assets/fonts/`),
/// so headings render identically on every device. Body text deliberately
/// stays on the system font: it is the most legible choice at small sizes and
/// already carries the user's own accessibility settings.
abstract final class AppTypography {
  static const headingFamily = 'Bricolage Grotesque';

  /// The brand body face. Bundled and available, and used as the first
  /// fallback under the heading stack.
  static const brandBodyFamily = 'Figtree';

  /// Nastaliq needs ~2x line-height and one size step up. Applied by the
  /// localisation layer when the active locale is Urdu.
  static const urduFamily = 'Noto Nastaliq Urdu';

  /// `Bricolage Grotesque, Figtree, system-ui, sans-serif`
  static const _headingFallback = <String>[
    brandBodyFamily,
    'system-ui',
    'sans-serif',
  ];

  /// `-apple-system, system-ui, sans-serif`
  ///
  /// Flutter resolves `.SF UI Text` / `-apple-system` on Apple platforms and
  /// falls through to Roboto on Android, which is what `system-ui` means on
  /// each platform.
  static const _bodyFallback = <String>[
    '-apple-system',
    'system-ui',
    'sans-serif',
  ];

  static TextStyle heading({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
  }) => TextStyle(
    fontFamily: headingFamily,
    fontFamilyFallback: _headingFallback,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: -0.025 * size,
    height: height ?? 1.12,
    color: color ?? AppColors.text,
  );

  /// Body copy on the platform UI font.
  ///
  /// Passing `fontFamily: null` lets Flutter use the platform default, which
  /// is exactly what `-apple-system` / `system-ui` resolve to.
  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamilyFallback: _bodyFallback,
    fontSize: size,
    fontWeight: weight,
    height: height ?? 1.45,
    letterSpacing: letterSpacing,
    color: color ?? AppColors.text,
  );

  /// Body copy in the brand face, for the rare places that want Figtree
  /// rather than the system font.
  static TextStyle brandBody({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: brandBodyFamily,
    fontFamilyFallback: _bodyFallback,
    fontSize: size,
    fontWeight: weight,
    height: height ?? 1.45,
    letterSpacing: letterSpacing,
    color: color ?? AppColors.text,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: heading(size: 42),
    displayMedium: heading(size: 32),
    headlineLarge: heading(size: 25),
    headlineMedium: heading(size: 22),
    headlineSmall: heading(size: 20),
    titleLarge: heading(size: 17, height: 1.2),
    titleMedium: body(size: 15, weight: FontWeight.w700),
    titleSmall: body(size: 13.5, weight: FontWeight.w700),
    bodyLarge: body(size: 15),
    bodyMedium: body(size: 13.5),
    bodySmall: body(size: 12, color: AppColors.textMuted(0.6)),
    labelLarge: body(size: 14, weight: FontWeight.w700),
    labelMedium: body(size: 12, weight: FontWeight.w600),
    labelSmall: body(
      size: 10.5,
      weight: FontWeight.w700,
      letterSpacing: 0.8,
      color: AppColors.textMuted(0.6),
    ),
  );
}
