import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/aqua_logo.dart';
import '../providers/auth_providers.dart';

/// The first screen: what the app is, and the language you want it in.
///
/// Language moved off its own gate and into the hero's top bar rather than
/// being a step of its own. "Get started" opens the four-step registration:
/// phone → role → name → details.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  AppLanguage _language = AppLanguage.english;

  late final _loginTap = TapGestureRecognizer()..onTap = _start;

  @override
  void dispose() {
    _loginTap.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await ref.read(sessionProvider.notifier).setLanguage(_language);
    // Pushed, not replaced: step 1 keeps a back route to the intro, which
    // is where its back chevron goes.
    if (mounted) context.pushNamed(AppRoutes.signUpPhone);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // The hero is a fixed 430px, so on a short viewport the page scrolls
    // rather than overflowing.
    body: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              children: [
                _IntroHero(
                  language: _language,
                  onLanguage: (l) => setState(() => _language = l),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Water at your door,\nin one tap',
                        style: AppTypography.heading(size: 34, height: 1.06),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Order 6L, 10L and 25L bottles from the filter plants '
                        'already delivering on your street.',
                        style: AppTypography.body(
                          size: 16,
                          height: 1.5,
                          color: AppColors.textMuted(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pushes the actions to the bottom when there is room to
                // spare, and simply yields when there is not.
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        onPressed: _start,
                        child: const Text('Get started'),
                      ),
                      const SizedBox(height: 14),
                      // One rich line so "Log in" always sits with the
                      // question and wraps with it rather than overflowing.
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Log in',
                              style: AppTypography.body(
                                size: 15,
                                weight: FontWeight.w700,
                                color: AppColors.accent700,
                              ),
                              recognizer: _loginTap,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: AppTypography.body(
                          size: 15,
                          color: AppColors.textMuted(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The gradient panel: the wordmark and the three promises, over the
/// falling water ribbons.
class _IntroHero extends StatelessWidget {
  const _IntroHero({required this.language, required this.onLanguage});

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguage;

  static const _promises = [
    (Icons.water_drop_outlined, 'Every filter plant that delivers to you'),
    (Icons.sort_rounded, 'Prices and ETA before you order'),
    (Icons.refresh_rounded, 'Your usual, again, in one tap'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    // The design draws this at 430px. It is a minimum rather than a fixed
    // height: the promise rows wrap to two lines on narrow phones and in
    // Urdu, and a hard height would clip them.
    constraints: const BoxConstraints(minHeight: 430),
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3AA6D8), Color(0xFF0D5C88)],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
    ),
    child: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _RibbonPainter())),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 18, 26, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Language rides at the very top of the hero, on the dark.
                _LanguageBar(selected: language, onSelect: onLanguage),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const AquaLogoMark(size: 48, color: Colors.white),
                    const SizedBox(width: 13),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Aqua Mart',
                          style: AppTypography.heading(
                            size: 30,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'ایکوا مارٹ',
                          style: AppTypography.body(
                            size: 17,
                            color: const Color(0xFFBFE4F3),
                            height: 1.6,
                          ).copyWith(fontFamily: AppTypography.urduFamily),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                for (final (index, (icon, text)) in _promises.indexed) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _PromiseRow(icon: icon, text: text),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Icon(icon, size: 21, color: Colors.white),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            // These read as one line each in the design; allow a second
            // only when a translation genuinely needs it.
            style: AppTypography.body(size: 15, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

/// The pale ribbons falling from the top of the hero — water in motion,
/// the same idea as the logo's mark.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  /// `left, width, height fraction, opacity` — straight from the design.
  static const _ribbons = [
    (30.0, 18.0, 0.52, 0.32),
    (66.0, 11.0, 0.38, 0.20),
    (236.0, 24.0, 0.58, 0.26),
    (284.0, 13.0, 0.42, 0.18),
    (322.0, 20.0, 0.50, 0.24),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (left, width, heightFactor, opacity) in _ribbons) {
      final height = size.height * heightFactor;
      final rect = Rect.fromLTWH(left, 0, width, height);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          bottomLeft: Radius.circular(width / 2),
          bottomRight: Radius.circular(width / 2),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    // The glow pooling at the base of the panel.
    final glow = Rect.fromLTWH(-40, size.height - 130, size.width + 80, 200);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}

/// "🌐 LANGUAGE" and the three choices, as a segmented control on the hero.
///
/// Sits on the dark panel, so the whole thing is tinted white rather than
/// using the light-theme surface colours.
class _LanguageBar extends StatelessWidget {
  const _LanguageBar({required this.selected, required this.onSelect});

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelect;

  /// The bar is tight on width, so the labels shorten here: the design
  /// prints "Roman", not "Roman Urdu".
  static String _short(AppLanguage language) => switch (language) {
    AppLanguage.english => 'English',
    AppLanguage.urdu => 'اردو',
    AppLanguage.romanUrdu => 'Roman',
  };

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.language_rounded,
        size: 16,
        color: Colors.white.withValues(alpha: 0.75),
      ),
      const SizedBox(width: 7),
      // The label yields first: the segmented control must never be clipped.
      Flexible(
        child: Text(
          'LANGUAGE',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: AppTypography.body(
            size: 11,
            weight: FontWeight.w700,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in AppLanguage.values)
              _LanguageSegment(
                label: _short(language),
                urdu: language == AppLanguage.urdu,
                selected: selected == language,
                onTap: () => onSelect(language),
              ),
          ],
        ),
      ),
    ],
  );
}

class _LanguageSegment extends StatelessWidget {
  const _LanguageSegment({
    required this.label,
    required this.urdu,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool urdu;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.body(
      size: urdu ? 13 : 12.5,
      weight: FontWeight.w700,
      color: selected ? AppColors.accent700 : Colors.white,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: urdu
              ? style.copyWith(fontFamily: AppTypography.urduFamily)
              : style,
        ),
      ),
    );
  }
}
