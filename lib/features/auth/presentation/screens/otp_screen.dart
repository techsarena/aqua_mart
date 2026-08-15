import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Enter the 6-digit code. Ships its own keypad so the boxes and the digits
/// stay on one screen without the OS keyboard covering them.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;
  static const _resendSeconds = 30;

  String _code = '';
  bool _verifying = false;
  String? _error;
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else if (mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _append(String digit) {
    if (_code.length >= _length) return;
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == _length) _verify();
  }

  void _backspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final session = ref.read(sessionProvider);

    final result = await ref
        .read(authRepositoryProvider)
        .verifyOtp(
          phone: session.draft.phone,
          code: _code,
          draft: session.draft,
        );

    if (!mounted) return;
    setState(() => _verifying = false);

    result.when(
      // Verifying the number does NOT sign the user in — the profile is
      // only created at the end, and signing in here would let the router
      // redirect straight past the remaining steps into the app.
      success: (_) {
        if (!mounted) return;
        context.pushNamed(AppRoutes.rolePicker);
      },
      failure: (f) => setState(() {
        _error = f.message;
        _code = '';
      }),
    );
  }

  Future<void> _resend() async {
    final phone = ref.read(sessionProvider).draft.phone;
    await ref.read(authRepositoryProvider).requestOtp(phone);
    if (mounted) _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(sessionProvider).draft.phone;

    return OnboardingScaffold(
      // The code belongs to the same step as the number it was sent to.
      step: 1,
      totalSteps: 4,
      title: 'Enter the 6-digit code',
      subtitle: null,
      // The keypad is pinned so it stays put as the boxes fill.
      bottomBar: _Keypad(onDigit: _append, onBackspace: _backspace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Sent by SMS to $phone · '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Text(
                      'change',
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // The boxes share the width evenly rather than being fixed, so six
          // of them always fit the gutter.
          Row(
            children: [
              for (var i = 0; i < _length; i++) ...[
                if (i > 0) const SizedBox(width: 9),
                Expanded(
                  child: _CodeBox(
                    digit: i < _code.length ? _code[i] : null,
                    active: i == _code.length,
                    hasError: _error != null,
                  ),
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.body(size: 13, color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // The prompt and the timer sit at opposite edges. Both are
          // flexible so a long translation shrinks rather than overflows.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "Didn't get it?",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.textMuted(0.55),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (_secondsLeft > 0)
                Flexible(
                  child: Text(
                    'Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted(0.4),
                    ),
                  ),
                )
              else
                Flexible(
                  child: GestureDetector(
                    onTap: _resend,
                    child: Text(
                      'Resend code',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_verifying) ...[
            const SizedBox(height: AppSpacing.xl),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

/// One of the six code boxes.
///
/// A filled box carries the accent border; the next one to fill shows a
/// blinking caret so it is obvious where the next digit lands.
class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String? digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final outlined = digit != null || active;

    return Container(
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError
              ? AppColors.danger
              : outlined
              ? AppColors.accent
              : Colors.transparent,
          width: 1.8,
        ),
      ),
      child: digit != null
          ? Text(digit!, style: AppTypography.heading(size: 26))
          : active
          ? const _Caret()
          : null,
    );
  }
}

/// The insertion point in the active box.
///
/// Deliberately static rather than blinking: a perpetual animation never
/// lets the widget tree reach a settled frame, which hangs `pumpAndSettle`
/// and keeps the compositor awake for a purely decorative effect.
class _Caret extends StatelessWidget {
  const _Caret();

  @override
  Widget build(BuildContext context) =>
      Container(width: 2, height: 26, color: AppColors.text);
}

/// The number pad, pinned to the bottom of the screen.
///
/// Rows 1–3 are the digits; the last row is dismiss · 0 · backspace, with
/// the two controls sitting flat on the ground rather than on key cards.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _spacing = 10.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.sm,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: _spacing),
          Row(
            children: [
              for (var col = 1; col <= 3; col++) ...[
                if (col > 1) const SizedBox(width: _spacing),
                Expanded(
                  child: _Key(
                    label: '${row * 3 + col}',
                    onTap: () => onDigit('${row * 3 + col}'),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: _spacing),
        Row(
          children: [
            Expanded(
              child: _FlatKey(
                icon: Icons.keyboard_hide_outlined,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ),
            const SizedBox(width: _spacing),
            Expanded(
              child: _Key(label: '0', onTap: () => onDigit('0')),
            ),
            const SizedBox(width: _spacing),
            Expanded(
              child: _FlatKey(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 58,
        child: Center(
          child: Text(label, style: AppTypography.heading(size: 26)),
        ),
      ),
    ),
  );
}

/// A control key — no card behind it, just the glyph on the ground.
class _FlatKey extends StatelessWidget {
  const _FlatKey({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 58,
        child: Center(
          child: Icon(icon, size: 24, color: AppColors.textMuted(0.75)),
        ),
      ),
    ),
  );
}
