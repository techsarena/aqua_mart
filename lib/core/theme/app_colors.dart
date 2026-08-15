import 'package:flutter/material.dart';

/// Design tokens from the Aqua Mart brand system.
///
/// AQUA carries the light cyan, MART the deep blue — never the reverse.
/// The brand gradient runs top-left aquamarine to bottom-right cerulean.
abstract final class AppColors {
  // Ground
  static const bg = Color(0xFFE8F2F8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF12262F);

  // Neutral ramp
  static const neutral100 = Color(0xFFF4F8FB);
  static const neutral200 = Color(0xFFE4EDF3);
  static const neutral300 = Color(0xFFD2E0EA);
  static const neutral400 = Color(0xFF93AAB9);
  static const neutral500 = Color(0xFF6A8492);
  static const neutral600 = Color(0xFF546B78);
  static const neutral700 = Color(0xFF3F5461);

  // Accent — cerulean
  static const accent = Color(0xFF1C7A9E);
  static const accent100 = Color(0xFFEAF5FA);
  static const accent200 = Color(0xFFCAE6F1);
  static const accent300 = Color(0xFF9FD4E6);
  static const accent400 = Color(0xFF4CA3C4);
  static const accent500 = Color(0xFF1C7A9E);
  static const accent600 = Color(0xFF166480);
  static const accent700 = Color(0xFF0F4E64);
  static const accent800 = Color(0xFF0B3C4E);
  static const accent900 = Color(0xFF082B39);

  // Accent 2 — teal
  static const accent2 = Color(0xFF3F9188);
  static const accent2_100 = Color(0xFFE8F5F3);
  static const accent2_200 = Color(0xFFCBE9E4);
  static const accent2_300 = Color(0xFFA4D9D1);
  static const accent2_400 = Color(0xFF63B0A6);
  static const accent2_500 = Color(0xFF3F9188);
  static const accent2_600 = Color(0xFF347A72);
  static const accent2_700 = Color(0xFF27605A);

  /// The deep teal the design uses for text and icons on `accent2` tints.
  static const accent2Deep = Color(0xFF2B6B64);

  /// The label under a full bottle on the water shelf.
  static const shelfFullLabel = Color(0xFF1F4F4A);

  // Brand logo colours
  static const brandAqua = Color(0xFF49B6DD);
  static const brandMart = Color(0xFF0A3A5A);
  static const gradientStart = Color(0xFF5FD6DF);
  static const gradientEnd = Color(0xFF0B4F7A);

  // Semantic
  static const success = accent2;
  static const warning = Color(0xFFC98A2E);
  static const danger = Color(0xFFC0453C);
  static const dangerBg = Color(0xFFFBECEA);
  static const warningBg = Color(0xFFFDF3E3);

  static const divider = Color(0x1A12262F);
  static const onTint = Color(0xFFF0F8FC);

  /// The brand gradient — always at this angle.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  /// Dark surface gradient used for hero panels and the on-dark logo lockup.
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F6FA8), Color(0xFF062B44)],
  );

  static Color textMuted([double opacity = 0.55]) =>
      text.withValues(alpha: opacity);
}
