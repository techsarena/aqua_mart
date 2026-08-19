import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../providers/seller_providers.dart';

/// "Invite a rider" — the seller's join code, and an optional SMS on their
/// behalf.
///
/// The code is the primary path: it works for anyone the seller shares it
/// with, so the phone field below is explicitly the lesser option ("or send
/// it for me") rather than a required step.
class InviteRiderScreen extends ConsumerStatefulWidget {
  const InviteRiderScreen({super.key});

  @override
  ConsumerState<InviteRiderScreen> createState() => _InviteRiderScreenState();
}

class _InviteRiderScreenState extends ConsumerState<InviteRiderScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _digits => _controller.text.replaceAll(RegExp(r'\D'), '');

  /// `0301 5528841` and `301 5528841` are both what sellers type; the server
  /// normalises, so the field only has to reject what cannot be a number.
  bool get _isValid => _digits.length >= 10;

  Future<void> _send() async {
    setState(() => _sending = true);

    final result = await ref
        .read(riderInvitesProvider.notifier)
        .invite(_digits);
    if (!mounted) return;
    setState(() => _sending = false);

    result.when(
      // The confirmation replaces this form rather than stacking on it: the
      // number has been sent, so there is nothing left here to come back to.
      success: (invite) => context.pushReplacementNamed(
        AppRoutes.riderInvites,
        extra: invite.id,
      ),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codeAsync = ref.watch(riderCodeProvider);

    return Scaffold(
      body: Column(
        children: [
          _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'Riders sign up on their own phone. Send them your code — '
                  'they enter it during signup and land under your name.',
                  style: AppTypography.body(
                    size: 15,
                    color: AppColors.textMuted(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _CodePanel(code: codeAsync),

                const SizedBox(height: AppSpacing.xl),
                const _OrDivider(),
                const SizedBox(height: AppSpacing.xl),

                const FieldLabel("Rider's mobile number"),
                _PhoneField(
                  controller: _controller,
                  onChanged: () => setState(() {}),
                ),

                const SizedBox(height: AppSpacing.md),
                const AppNote.positive(
                  text: 'They get an SMS with the code and a link. Nothing '
                      'changes for you until they accept.',
                  icon: Icons.info_outline_rounded,
                ),
              ],
            ),
          ),
          StickyActionBar(
            label: _sending ? 'Sending…' : 'Send invite',
            enabled: _isValid && !_sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      MediaQuery.paddingOf(context).top + AppSpacing.sm,
      AppSpacing.gutter,
      AppSpacing.lg,
    ),
    child: Row(
      children: [
        const BackDiscButton(),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            'Invite a rider',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading(size: 28),
          ),
        ),
      ],
    ),
  );
}

/// The blue block holding the six code characters, with copy and share.
class _CodePanel extends StatelessWidget {
  const _CodePanel({required this.code});

  final AsyncValue<String> code;

  static const _placeholder = '••••••';

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code $value copied.')),
    );
  }

  /// No share plugin ships with the app, so "Share" puts the whole sentence a
  /// seller would send on the clipboard — one paste into WhatsApp, rather
  /// than the bare code they would have to write around.
  void _share(BuildContext context, String value) {
    Clipboard.setData(
      ClipboardData(
        text:
            'Join my water delivery team on Aqua Mart. Enter code $value when '
            'you sign up.',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite message copied — paste it to send.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = code.value;
    final characters = value ?? _placeholder;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR RIDER CODE',
            style: AppTypography.body(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.onTint.withValues(alpha: 0.75),
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (code case AsyncError(:final error))
            Text(
              asFailure(error).message,
              style: AppTypography.body(
                size: 13.5,
                color: AppColors.onTint,
                height: 1.4,
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < characters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(child: _CodeBox(character: characters[i])),
                ],
              ],
            ),

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _CodeAction(
                  label: 'Copy code',
                  icon: Icons.copy_rounded,
                  filled: true,
                  onPressed: value == null ? null : () => _copy(context, value),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _CodeAction(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: value == null
                      ? null
                      : () => _share(context, value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One character of the code, on a lighter tile so it reads on the blue.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.character});

  final String character;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(
      character,
      style: AppTypography.heading(size: 26, color: AppColors.surface),
    ),
  );
}

/// A pill button sitting on the blue panel — filled for the primary action,
/// outlined for the secondary.
class _CodeAction extends StatelessWidget {
  const _CodeAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppColors.accent : AppColors.surface;

    return Material(
      color: filled ? AppColors.surface : Colors.transparent,
      shape: StadiumBorder(
        side: filled
            ? BorderSide.none
            : BorderSide(color: AppColors.surface.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `──── OR SEND IT FOR ME ────`
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.divider)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          'OR SEND IT FOR ME',
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w700,
            color: AppColors.textMuted(0.55),
            letterSpacing: 0.9,
          ),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.divider)),
    ],
  );
}

/// `+92 │ 0301 552 8841` in one pill, matching the sign-up phone step.
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.accent, width: 1.6),
    ),
    child: Row(
      children: [
        Text(
          '+92',
          style: AppTypography.body(
            size: 16,
            weight: FontWeight.w700,
            color: AppColors.textMuted(0.5),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(width: 1, height: 26, color: AppColors.divider),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            onChanged: (_) => onChanged(),
            style: AppTypography.body(size: 17, weight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '0301 552 8841',
              hintStyle: AppTypography.body(
                size: 17,
                color: AppColors.textMuted(0.35),
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    ),
  );
}
