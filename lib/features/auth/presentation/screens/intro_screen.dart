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
    // The gradient owns the whole screen here — the brand gets the full
    // frame before the app's white surfaces take over.
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F6FA8), Color(0xFF062B44)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _RibbonPainter())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 14, 26, 20),
                      child: Column(
                        children: [
                          _LanguageBar(
                            selected: _language,
                            onSelect: (l) => setState(() => _language = l),
                          ),

                          // The mark and name sit in the middle of whatever
                          // room is left after the bars top and bottom.
                          const Spacer(flex: 3),
                          const AquaLogoMark(size: 96, color: Colors.white),
                          const SizedBox(height: 20),
                          const AquaWordmark(fontSize: 44, onDark: true),
                          const SizedBox(height: 10),
                          Text(
                            'ایکوا مارٹ',
                            style: AppTypography.urdu(
                              AppTypography.body(
                                size: 20,
                                color: const Color(0xFFCFE9F5),
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            'Clean water from the plant nearest you, at a '
                            'price you can see first.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              size: 17,
                              height: 1.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const Spacer(flex: 4),

                          Row(
                            children: [
                              for (final (index, (value, label))
                                  in _stats.indexed) ...[
                                if (index > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: _StatTile(value: value, label: label),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _start,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.accent700,
                              minimumSize: const Size.fromHeight(64),
                              textStyle: AppTypography.heading(size: 21),
                            ),
                            child: const Text('Get started'),
                          ),
                          const SizedBox(height: 14),
                          // One rich line so "Log in" always sits with the
                          // question and wraps with it rather than overflowing.
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Already have an account? ',
                                ),
                                TextSpan(
                                  text: 'Log in',
                                  style: AppTypography.body(
                                    size: 16,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  recognizer: _loginTap,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// The three proof points along the bottom.
  static const _stats = [
    ('120+', 'plants listed'),
    ('28 min', 'average drop'),
    ('Rs 95', '25L refill from'),
  ];
}

/// One of the three frosted proof tiles above the button.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text(
            value,
            style: AppTypography.heading(size: 26, color: Colors.white),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            size: 13,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    ),
  );
}

/// The pale ribbons falling from the top of the screen — water in motion,
/// the same idea as the logo's mark.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  /// `left fraction, width, height fraction, opacity`. The x positions are
  /// fractional so the ribbons stay spread across any screen width.
  static const _ribbons = [
    (0.07, 18.0, 0.30, 0.26),
    (0.16, 11.0, 0.22, 0.16),
    (0.58, 24.0, 0.34, 0.20),
    (0.70, 13.0, 0.24, 0.14),
    (0.80, 20.0, 0.29, 0.18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (leftFactor, width, heightFactor, opacity) in _ribbons) {
      final height = size.height * heightFactor;
      final rect = Rect.fromLTWH(size.width * leftFactor, 0, width, height);
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

    // A soft pool of light behind the mark, lifting it off the gradient.
    // Kept above the lower third so it never washes out the tiles or the
    // button sitting there.
    final glow = Rect.fromLTWH(
      -40,
      size.height * 0.22,
      size.width + 80,
      size.height * 0.36,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(glow),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}

/// "🌐 LANGUAGE" and the three choices, as a segmented control.
///
/// Sits on the dark gradient, so the whole thing is tinted white rather than
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
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.all(5),
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
      size: urdu ? 15 : 14.5,
      weight: FontWeight.w700,
      color: selected ? AppColors.accent700 : Colors.white,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: urdu ? AppTypography.urdu(style) : style),
      ),
    );
  }
}
