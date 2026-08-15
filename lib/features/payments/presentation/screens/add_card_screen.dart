import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../providers/wallet_providers.dart';

/// Add a debit or credit card, with a live preview of what is being typed.
class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _numberController = TextEditingController();
  final _holderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _saveForNextTime = true;
  bool _saving = false;

  @override
  void dispose() {
    _numberController.dispose();
    _holderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _numberController.text.replaceAll(' ', '').length >= 15 &&
      _holderController.text.trim().isNotEmpty &&
      _expiryController.text.replaceAll(RegExp(r'\D'), '').length == 4 &&
      _cvvController.text.length >= 3;

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(walletProvider.notifier)
        .saveCard(
          number: _numberController.text.replaceAll(' ', ''),
          holder: _holderController.text.trim(),
          expiry: _expiryController.text,
          cvv: _cvvController.text,
          saveForNextTime: _saveForNextTime,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Card saved.')));
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add a card')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        _CardPreview(
          number: _numberController.text,
          holder: _holderController.text,
          expiry: _expiryController.text,
        ),

        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Card number'),
        TextField(
          controller: _numberController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            _CardNumberFormatter(),
          ],
          decoration: const InputDecoration(hintText: '5412 7512 3412 0000'),
        ),

        const SizedBox(height: AppSpacing.lg),
        const FieldLabel('Card holder'),
        TextField(
          controller: _holderController,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'AYESHA KHAN'),
        ),

        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Expiry'),
                  TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryFormatter(),
                    ],
                    decoration: const InputDecoration(hintText: '09 / 28'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('CVV'),
                  TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(hintText: '•••'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        SwitchListTile.adaptive(
          value: _saveForNextTime,
          onChanged: (v) => setState(() => _saveForNextTime = v),
          title: Text(
            'Save for next time',
            style: AppTypography.body(size: 14, weight: FontWeight.w600),
          ),
          subtitle: Text(
            'Stored by our payment partner, never on your phone',
            style: AppTypography.body(
              size: 12,
              color: AppColors.textMuted(0.55),
            ),
          ),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.accent2,
        ),
      ],
    ),
    bottomNavigationBar: StickyActionBar(
      label: _saving ? 'Saving…' : 'Save card',
      enabled: _isValid && !_saving,
      onPressed: _save,
    ),
  );
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.number,
    required this.holder,
    required this.expiry,
  });

  final String number;
  final String holder;
  final String expiry;

  @override
  Widget build(BuildContext context) => Container(
    height: 178,
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      gradient: AppColors.darkGradient,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent900.withValues(alpha: 0.28),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const Spacer(),
            Text(
              'Debit / credit',
              style: AppTypography.body(
                size: 11.5,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          number.isEmpty ? '•••• •••• •••• ••••' : number.padRight(19, '•'),
          style: AppTypography.body(
            size: 18,
            weight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1.6,
          ),
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARD HOLDER',
                    style: AppTypography.body(
                      size: 8.5,
                      weight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    holder.isEmpty ? 'YOUR NAME' : holder.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPIRES',
                  style: AppTypography.body(
                    size: 8.5,
                    weight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expiry.isEmpty ? 'MM / YY' : expiry,
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

/// Groups the card number into fours as it is typed.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Renders MMYY as `MM / YY`.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)} / ${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
