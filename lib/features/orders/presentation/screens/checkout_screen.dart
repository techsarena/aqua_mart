import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
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
      appBar: AppBar(title: const Text('How will you pay?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          for (final method in PaymentMethod.values) ...[
            SelectableOption(
              title: method.label,
              subtitle: _subtitleFor(method, user?.walletBalance ?? 0,
                  user?.khataDue ?? 0),
              icon: _iconFor(method),
              selected: cart.paymentMethod == method,
              enabled: _isEnabled(method, user?.walletBalance ?? 0, cart.total),
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
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Have a promo code?',
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
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                SummaryRow(
                  label: 'Order total',
                  value: Formatters.rupees(cart.total),
                  isTotal: true,
                ),
                SummaryRow(
                  label: 'Arrives',
                  value: 'in about 25 min',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _placing ? 'Placing your order…' : 'Place order',
        enabled: !_placing && cart.isNotEmpty,
        onPressed: _placeOrder,
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
}
