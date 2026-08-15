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
import '../../../../shared/widgets/bottle_glyph.dart';
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const _CartTitle(),

          // ── Where it goes ───────────────────────────────────────────────
          // Map and address read as one object: the map's bottom corners are
          // square so the card below butts straight onto it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  child: MapPlaceholder(
                    height: 190,
                    radius: 0,
                    showCentrePin: true,
                    caption: 'drag pin to set exact spot',
                  ),
                ),
                // Square on top to meet the map, rounded below to close the
                // pair off.
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.lg),
                  ),
                  child: AppCard(
                    radius: 0,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 26,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address?.shortLine ?? 'Choose an address',
                                style: AppTypography.heading(size: 16),
                              ),
                              if (address?.riderNote.isNotEmpty ?? false) ...[
                                const SizedBox(height: 3),
                                Text(
                                  address!.riderNote,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                    size: 13,
                                    color: AppColors.textMuted(0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        TextButton(
                          onPressed: () =>
                              context.pushNamed(AppRoutes.addressBook),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: AppTypography.body(
                              size: 13.5,
                              weight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── What's in it ────────────────────────────────────────────────
          // Each line is its own card; the seller's name already sits on the
          // screen you came from, so no section header is needed.
          for (final line in cart.orderedLines)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.gutter,
                0,
              ),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    BottleGlyph(size: line.size, compact: true),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: AppTypography.heading(size: 15.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            line.unitLabel,
                            style: AppTypography.body(
                              size: 12.5,
                              color: AppColors.textMuted(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    QuantityStepper(
                      quantity: line.quantity,
                      onIncrement: () =>
                          ref.read(cartProvider.notifier).adjustLine(line, 1),
                      onDecrement: () =>
                          ref.read(cartProvider.notifier).adjustLine(line, -1),
                    ),
                  ],
                ),
              ),
            ),

          // ── What it costs ───────────────────────────────────────────────
          // Tinted, so the money reads as a distinct block rather than one
          // more white card in the stack.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xl,
              AppSpacing.gutter,
              0,
            ),
            child: AppCard(
              color: AppColors.accent2_100,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  _CartSummaryRow(
                    label: 'Bottles',
                    value: Formatters.rupees(cart.subtotal),
                  ),
                  _CartSummaryRow(
                    label: 'Delivery',
                    value: cart.deliveryFee == 0
                        ? 'Free'
                        : Formatters.rupees(cart.deliveryFee),
                    valueColor: cart.deliveryFee == 0
                        ? AppColors.accent2
                        : null,
                  ),
                  if (cart.emptiesReturned > 0)
                    _CartSummaryRow(
                      label: 'Empties you return',
                      value: '${cart.emptiesReturned} bottles',
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Divider(height: 1),
                  ),
                  _CartSummaryRow(
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
      // The same bar as the shelf, carrying the next step of the flow.
      bottomNavigationBar: StickyCartBar(
        count: cart.bottleCount,
        total: Formatters.rupees(cart.total),
        label: 'Choose payment',
        onPressed: address == null
            ? null
            : () {
                ref.read(cartProvider.notifier).setAddress(address);
                context.pushNamed(AppRoutes.checkout);
              },
      ),
    );
  }
}

/// "Your order", with the back button on its own disc — the same head the
/// seller's shelf uses, so the flow keeps one shape.
class _CartTitle extends StatelessWidget {
  const _CartTitle();

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
            'Your order',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading(size: 28),
          ),
        ),
      ],
    ),
  );
}

/// A money line in the tinted summary — bigger than the shared [SummaryRow],
/// which is tuned for denser cards elsewhere.
class _CartSummaryRow extends StatelessWidget {
  const _CartSummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: isTotal
                ? AppTypography.heading(size: 19)
                : AppTypography.body(size: 15, color: AppColors.textMuted(0.7)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          value,
          style: isTotal
              ? AppTypography.heading(size: 25, color: valueColor)
              : AppTypography.body(
                  size: 15,
                  weight: FontWeight.w800,
                  color: valueColor,
                ),
        ),
      ],
    ),
  );
}
