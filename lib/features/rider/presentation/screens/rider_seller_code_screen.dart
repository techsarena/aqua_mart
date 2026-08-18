import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../../domain/entities/rider_application.dart';
import '../providers/rider_providers.dart';

/// Rider sign-up 5 of 5 — the seller's 6-character rider code.
///
/// The code is looked up as the last box fills, and the seller it resolves to
/// is shown for confirmation: joining the wrong business is the mistake worth
/// preventing here, and a name is easier to check than a code.
class RiderSellerCodeScreen extends ConsumerStatefulWidget {
  const RiderSellerCodeScreen({super.key});

  @override
  ConsumerState<RiderSellerCodeScreen> createState() =>
      _RiderSellerCodeScreenState();
}

class _RiderSellerCodeScreenState extends ConsumerState<RiderSellerCodeScreen> {
  static const _length = 6;

  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(
          text: ref.read(riderApplicationProvider).inviteCode,
        )..addListener(() {
          ref
              .read(riderApplicationProvider.notifier)
              .setInviteCode(_controller.text);
          setState(() {});
        });
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _code => _controller.text;

  Future<void> _join(RiderSellerMatch seller) async {
    ref.read(riderApplicationProvider.notifier).setSeller(seller);

    final result = await ref.read(riderApplicationProvider.notifier).submit();
    if (!mounted) return;

    result.when(
      success: (_) => context.goNamed(AppRoutes.riderPendingApproval),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only look the code up once it is the full length — a partial code is
    // never a match, and querying each keystroke would flash a miss.
    final match = _code.length == _length
        ? ref.watch(sellerCodeProvider(_code))
        : null;
    final seller = switch (match) {
      AsyncValue(value: final found) => found,
      _ => null,
    };

    return OnboardingScaffold(
      step: 5,
      totalSteps: 5,
      title: 'Who invited you?',
      subtitle:
          'Ask your seller for the 6-character rider code from their app.',
      primaryLabel: seller == null ? 'Join' : 'Join ${seller.sellerName}',
      primaryEnabled: seller != null,
      onPrimary: () => _join(seller!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One hidden field drives all six boxes: the OS keyboard needs a
          // real input to attach to, and a letter code can't use the OTP
          // screen's digit keypad.
          Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < _length; i++) ...[
                    if (i > 0) const SizedBox(width: 9),
                    Expanded(
                      child: _CodeBox(
                        character: i < _code.length ? _code[i] : null,
                        active: i == _code.length && _focus.hasFocus,
                      ),
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: EditableText(
                  controller: _controller,
                  focusNode: _focus,
                  // The real field is invisible behind the boxes, which draw
                  // the code themselves.
                  style: const TextStyle(color: Colors.transparent),
                  cursorColor: Colors.transparent,
                  backgroundCursorColor: Colors.transparent,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_length),
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          if (match != null)
            switch (match) {
              AsyncLoading() => const _LookupRow(
                text: 'Checking that code…',
                showSpinner: true,
              ),
              AsyncError() => const _LookupRow(
                text: "Couldn't check that code. Try again.",
                isError: true,
              ),
              AsyncValue(value: final found) when found != null => _SellerCard(
                seller: found,
              ),
              _ => const _LookupRow(
                text: 'No seller has that code. Check it with them.',
                isError: true,
              ),
            },

          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: () => context.goNamed(AppRoutes.riderInvitation),
              child: const Text('No code? Ask a seller to invite you'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Upper-cases as typed, so the boxes and the lookup agree on one case.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => TextEditingValue(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
  );
}

/// One of the six character boxes.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.character, required this.active});

  final String? character;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: character != null || active
            ? AppColors.accent
            : Colors.transparent,
        width: 1.8,
      ),
    ),
    child: character != null
        ? Text(character!, style: AppTypography.heading(size: 24))
        : null,
  );
}

/// The seller the code resolved to, confirmed with a tick.
class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller});

  final RiderSellerMatch seller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.accent2_100,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.accent2,
            shape: BoxShape.circle,
          ),
          child: Text(
            seller.initials,
            style: AppTypography.body(
              size: 15,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(seller.sellerName, style: AppTypography.heading(size: 17)),
              const SizedBox(height: 2),
              Text(
                seller.summary,
                style: AppTypography.body(
                  size: 12.5,
                  color: AppColors.accent2Deep,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_rounded, size: 22, color: AppColors.accent2_700),
      ],
    ),
  );
}

/// The in-between states of the lookup — checking, missed, or failed.
class _LookupRow extends StatelessWidget {
  const _LookupRow({
    required this.text,
    this.showSpinner = false,
    this.isError = false,
  });

  final String text;
  final bool showSpinner;
  final bool isError;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (showSpinner) ...[
        const SizedBox.square(
          dimension: 15,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
      Expanded(
        child: Text(
          text,
          style: AppTypography.body(
            size: 13,
            color: isError ? AppColors.danger : AppColors.textMuted(0.6),
          ),
        ),
      ),
    ],
  );
}
