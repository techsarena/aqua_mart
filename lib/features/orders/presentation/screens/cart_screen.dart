import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/map_placeholder.dart';
import '../../../../shared/widgets/quantity_stepper.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../providers/cart_providers.dart';

/// "Your order" — the drop pin, the lines, and what it all adds up to.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final address = cart.address ?? ref.watch(selectedAddressProvider);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your order')),
        body: Center(
          child: EmptyView(
            icon: Icons.shopping_basket_outlined,
            title: 'Nothing in your order yet',
            message: 'Pick a seller and add the bottles you need.',
            primaryLabel: 'Browse sellers',
            onPrimary: () => context.goNamed(AppRoutes.customerHome),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your order')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          // ── Where it goes ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: MapPlaceholder(
              height: 160,
              showCentrePin: true,
              caption: 'drag pin to set exact spot',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              0,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 19,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address?.shortLine ?? 'Choose an address',
                          style: AppTypography.body(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if (address?.riderNote.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(
                            address!.riderNote,
                            style: AppTypography.body(
                              size: 12.5,
                              color: AppColors.textMuted(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pushNamed(AppRoutes.addressBook),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),

          // ── What's in it ────────────────────────────────────────────────
          AppSection(
            title: 'Bottles',
            subtitle: cart.sellerName,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: AppCard(
                child: Column(
                  children: [
                    for (final line in cart.orderedLines) ...[
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent100,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Text(
                              line.size.label,
                              style: AppTypography.body(
                                size: 11.5,
                                weight: FontWeight.w800,
                                color: AppColors.accent700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.name,
                                  style: AppTypography.body(
                                    size: 14,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  line.unitLabel,
                                  style: AppTypography.body(
                                    size: 12,
                                    color: AppColors.textMuted(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          QuantityStepper(
                            quantity: line.quantity,
                            compact: true,
                            onIncrement: () => ref
                                .read(cartProvider.notifier)
                                .adjustLine(line, 1),
                            onDecrement: () => ref
                                .read(cartProvider.notifier)
                                .adjustLine(line, -1),
                          ),
                        ],
                      ),
                      if (line != cart.orderedLines.last)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Divider(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── What it costs ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              0,
            ),
            child: AppCard(
              child: Column(
                children: [
                  SummaryRow(
                    label: 'Bottles',
                    value: Formatters.rupees(cart.subtotal),
                  ),
                  SummaryRow(
                    label: 'Delivery',
                    value: cart.deliveryFee == 0
                        ? 'Free'
                        : Formatters.rupees(cart.deliveryFee),
                    valueColor: cart.deliveryFee == 0
                        ? AppColors.accent2
                        : null,
                  ),
                  if (cart.emptiesReturned > 0)
                    SummaryRow(
                      label: 'Empties you return',
                      value: '${cart.emptiesReturned} bottles',
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Divider(),
                  ),
                  SummaryRow(
                    label: 'Total',
                    value: Formatters.rupees(cart.total),
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: 'Choose payment',
        enabled: address != null,
        onPressed: () {
          if (address != null) {
            ref.read(cartProvider.notifier).setAddress(address);
          }
          context.pushNamed(AppRoutes.checkout);
        },
      ),
    );
  }
}
