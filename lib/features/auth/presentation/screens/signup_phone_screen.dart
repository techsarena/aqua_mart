import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../providers/auth_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// Sign-up 1 of 4 — the number the OTP goes to, and the number the rider
/// reaches (through the app, never directly).
class SignUpPhoneScreen extends ConsumerStatefulWidget {
  const SignUpPhoneScreen({super.key});

  @override
  ConsumerState<SignUpPhoneScreen> createState() => _SignUpPhoneScreenState();
}

class _SignUpPhoneScreenState extends ConsumerState<SignUpPhoneScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');
  bool get _isValid => _digits.length >= 10;

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    final phone = '+92$_digits';

    ref
        .read(sessionProvider.notifier)
        .updateDraft((d) => d.copyWith(phone: phone));

    final result = await ref.read(authRepositoryProvider).requestOtp(phone);
    if (!mounted) return;
    setState(() => _sending = false);

    result.when(
      success: (_) => context.pushNamed(AppRoutes.otp),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    step: 1,
    totalSteps: 4,
    title: 'Your mobile number',
    subtitle:
        'We send a 6-digit code to confirm it. This is also how the rider '
        'reaches you.',
    primaryLabel: _sending ? 'Sending…' : 'Send code',
    primaryEnabled: _isValid && !_sending,
    onPrimary: _sendCode,
    footer: const AppNote(
      text:
          'Sellers and riders never see your real number — calls go through '
          'the app.',
      icon: Icons.shield_outlined,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Mobile number'),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇵🇰', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 6),
                  Text(
                    '+92',
                    style: AppTypography.body(size: 14.5, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '300 441 2987'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
