import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/order_status.dart';
import '../providers/cart_providers.dart';
import '../providers/order_providers.dart';

/// "How will you pay?" — then place the order.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _promoController = TextEditingController();
  bool _placing = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    setState(() => _placing = true);
    final result = await ref.read(orderListProvider.notifier).placeFromCart();
    if (!mounted) return;
    setState(() => _placing = false);

    result.when(
      success: (order) => context.goNamed(
        AppRoutes.orderTracking,
        pathParameters: {'orderId': order.id},
      ),
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
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
                    'How will you pay?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading(size: 28),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                for (final method in PaymentMethod.values) ...[
                  SelectableOption(
                    title: method.label,
                    subtitle: _subtitleFor(
                      method,
                      user?.walletBalance ?? 0,
                      user?.khataDue ?? 0,
                    ),
                    large: true,
                    leading: _MethodIcon(
                      icon: _iconFor(method),
                      tone: _toneFor(method),
                    ),
                    // The card row goes off to a form rather than settling the
                    // choice here, so it points onward instead of ticking.
                    showRadio: false,
                    trailing: method == PaymentMethod.card
                        ? Icon(
                            Icons.chevron_right_rounded,
                            size: 26,
                            color: AppColors.textMuted(0.4),
                          )
                        : null,
                    selected: cart.paymentMethod == method,
                    enabled: _isEnabled(
                      method,
                      user?.walletBalance ?? 0,
                      cart.total,
                    ),
                    onTap: () {
                      ref.read(cartProvider.notifier).setPaymentMethod(method);
                      // A card has to exist before it can be charged.
                      if (method == PaymentMethod.card) {
                        context.pushNamed(AppRoutes.addCard);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 22,
                        color: AppColors.textMuted(0.55),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.body(size: 16.5),
                          decoration: InputDecoration(
                            hintText: 'Have a promo code?',
                            hintStyle: AppTypography.body(
                              size: 16.5,
                              color: AppColors.textMuted(0.45),
                            ),
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final code = _promoController.text.trim();
                          if (code.isEmpty) return;
                          ref.read(cartProvider.notifier).applyPromo(code);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Applied $code')),
                          );
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: AppTypography.body(
                            size: 16.5,
                            weight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  color: AppColors.accent2_100,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _CheckoutRow(
                        label: 'Order total',
                        value: Formatters.rupees(cart.total),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _CheckoutRow(
                        label: 'Arrives',
                        value: 'in about 25 min',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // The same bar as the shelf and the cart, closing the flow.
      bottomNavigationBar: StickyCartBar(
        count: cart.bottleCount,
        total: Formatters.rupees(cart.total),
        label: _placing ? 'Placing your order…' : 'Place order',
        onPressed: _placing || cart.isEmpty ? null : _placeOrder,
      ),
    );
  }

  static IconData _iconFor(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.wallet => Icons.account_balance_wallet_outlined,
    PaymentMethod.jazzCash => Icons.phone_android_rounded,
    PaymentMethod.card => Icons.credit_card_rounded,
    PaymentMethod.khata => Icons.menu_book_outlined,
  };

  static String _subtitleFor(
    PaymentMethod method,
    int walletBalance,
    int khataDue,
  ) => switch (method) {
    PaymentMethod.wallet =>
      'Balance ${Formatters.rupees(walletBalance)} · top up with JazzCash',
    PaymentMethod.khata =>
      'Add to khata · ${Formatters.rupees(khataDue)} due on 30th',
    _ => method.subtitle,
  };

  /// The wallet cannot cover an order larger than its balance.
  static bool _isEnabled(PaymentMethod method, int walletBalance, int total) =>
      method != PaymentMethod.wallet || walletBalance >= total;

  /// Cash and the wallet are the two Aqua Mart handles itself, so they carry
  /// the brand's two accents; the rest stay neutral.
  static Color _toneFor(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => AppColors.accent2_200,
    PaymentMethod.wallet => AppColors.accent200,
    _ => AppColors.neutral200,
  };
}

/// A payment method's icon in its tinted disc.
class _MethodIcon extends StatelessWidget {
  const _MethodIcon({required this.icon, required this.tone});

  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
    child: Icon(icon, size: 26, color: AppColors.text),
  );
}

/// A line in the mint total panel — label left, value right, both sized to
/// be read at a glance before committing.
class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: AppTypography.body(
            size: 13.5,
            color: AppColors.textMuted(0.7),
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Text(
        value,
        style: AppTypography.body(size: 16.5, weight: FontWeight.w800),
      ),
    ],
  );
}
