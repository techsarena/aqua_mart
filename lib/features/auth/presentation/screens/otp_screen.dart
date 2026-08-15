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
      step: 1,
      totalSteps: 4,
      title: 'Enter the 6-digit code',
      subtitle: null,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_length, (i) {
              final filled = i < _code.length;
              final isNext = i == _code.length;
              return Container(
                width: 48,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _error != null
                        ? AppColors.danger
                        : isNext
                        ? AppColors.accent
                        : AppColors.divider,
                    width: isNext || _error != null ? 1.8 : 1,
                  ),
                ),
                child: Text(
                  filled ? _code[i] : '',
                  style: AppTypography.heading(size: 25),
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.body(size: 13, color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Text(
                "Didn't get it?",
                style: AppTypography.body(
                  size: 13.5,
                  color: AppColors.textMuted(0.6),
                ),
              ),
              const SizedBox(width: 6),
              if (_secondsLeft > 0)
                Text(
                  'Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                  style: AppTypography.body(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted(0.4),
                  ),
                )
              else
                GestureDetector(
                  onTap: _resend,
                  child: Text(
                    'Resend code',
                    style: AppTypography.body(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_verifying)
            const Center(child: CircularProgressIndicator())
          else
            _Keypad(onDigit: _append, onBackspace: _backspace),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.9,
    mainAxisSpacing: AppSpacing.sm,
    crossAxisSpacing: AppSpacing.md,
    children: [
      for (var i = 1; i <= 9; i++) _Key(label: '$i', onTap: () => onDigit('$i')),
      const SizedBox.shrink(),
      _Key(label: '0', onTap: () => onDigit('0')),
      _Key(icon: Icons.backspace_outlined, onTap: onBackspace),
    ],
  );
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Center(
        child: icon != null
            ? Icon(icon, size: 21, color: AppColors.textMuted(0.7))
            : Text(label!, style: AppTypography.heading(size: 22)),
      ),
    ),
  );
}
