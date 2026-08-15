import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../orders/presentation/providers/cart_providers.dart';
import '../../../../core/utils/formatters.dart';

/// The customer's four tabs, with the running cart bar floating above them.
class CustomerShell extends ConsumerWidget {
  const CustomerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The cart bar rides above the tabs so it stays reachable while
          // browsing, and disappears the moment the cart empties.
          if (cart.isNotEmpty && shell.currentIndex == 0)
            StickyCartBar(
              count: cart.bottleCount,
              total: Formatters.rupees(cart.subtotal),
              label: 'View order',
              onPressed: () => context.pushNamed(AppRoutes.cart),
            ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) =>
                shell.goBranch(index, initialLocation: index == shell.currentIndex),
            // The bar sits on the page ground, separated by a hairline only.
            backgroundColor: AppColors.bg,
            indicatorColor: AppColors.accent100,
            surfaceTintColor: Colors.transparent,
            height: 66,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Shelf',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded),
                label: 'Track',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Me',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
