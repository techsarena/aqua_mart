import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../providers/rider_providers.dart';

/// Rider sign-up 3 of 5 — the name customers see at the door, and the CNIC
/// the seller keeps on file.
///
/// The two are on one screen because they are the same question — who is
/// this person — asked once for the customer and once for the seller.
class RiderIdentityScreen extends ConsumerStatefulWidget {
  const RiderIdentityScreen({super.key});

  @override
  ConsumerState<RiderIdentityScreen> createState() =>
      _RiderIdentityScreenState();
}

class _RiderIdentityScreenState extends ConsumerState<RiderIdentityScreen> {
  late final TextEditingController _name;
  late final TextEditingController _cnic;

  @override
  void initState() {
    super.initState();
    // Seeded from the application so stepping back and forward keeps what
    // was already typed.
    final application = ref.read(riderApplicationProvider);
    _name = TextEditingController(text: application.fullName)
      ..addListener(_onChanged);
    _cnic = TextEditingController(text: application.cnic)
      ..addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    super.dispose();
  }

  /// Persists each edit so an app restart restores the unfinished form.
  void _onChanged() {
    ref
        .read(riderApplicationProvider.notifier)
        .setIdentity(fullName: _name.text, cnic: _cnic.text);
    setState(() {});
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _cnic.text.replaceAll(RegExp(r'\D'), '').length == 13;

  void _continue() {
    ref
        .read(riderApplicationProvider.notifier)
        .setIdentity(fullName: _name.text.trim(), cnic: _cnic.text.trim());
    context.pushNamed(AppRoutes.riderVehicle);
  }

  @override
  Widget build(BuildContext context) => OnboardingScaffold(
    step: 3,
    totalSteps: 5,
    title: 'Your name and CNIC',
    subtitle:
        'Customers see your name at the door. The CNIC stays with the '
        'seller who hires you.',
    primaryLabel: 'Continue',
    primaryEnabled: _complete,
    onPrimary: _continue,
    footer: const AppNote(
      icon: Icons.lock_outline_rounded,
      text: 'Customers never see your CNIC — only your first name and vehicle.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('FULL NAME'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Imran Bashir'),
        ),
        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('CNIC NUMBER'),
        TextField(
          controller: _cnic,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_complete) _continue();
          },
          inputFormatters: [_CnicFormatter()],
          decoration: const InputDecoration(hintText: '35202-8841234-5'),
        ),
      ],
    ),
  );
}

/// Punctuates a CNIC as it is typed — `35202-8841234-5`.
///
/// The dashes are inserted rather than required, so the rider can type the
/// 13 digits straight through off the card.
class _CnicFormatter extends TextInputFormatter {
  static const _firstBlock = 5;
  static const _secondBlock = 12;
  static const _digits = 13;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final stripped = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = stripped.length > _digits
        ? stripped.substring(0, _digits)
        : stripped;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == _firstBlock || i == _secondBlock) buffer.write('-');
      buffer.write(digits[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
