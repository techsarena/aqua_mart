import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/nav_avatar.dart';

/// The seller's five tabs — one thumb, on the move.
class SellerShell extends StatelessWidget {
  const SellerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) => shell.goBranch(
        index,
        initialLocation: index == shell.currentIndex,
      ),
      // The seller bar sits on white; everything else comes from the theme.
      backgroundColor: AppColors.surface,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today_rounded),
          label: 'Today',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Orders',
        ),
        const NavigationDestination(
          icon: Icon(Icons.water_drop_outlined),
          selectedIcon: Icon(Icons.water_drop_rounded),
          label: 'Bottles',
        ),
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: 'Area',
        ),
        // Your own face rather than a generic person glyph — the ring
        // carries the selected state.
        NavigationDestination(
          icon: const NavAvatar(),
          selectedIcon: const NavAvatar(isSelected: true),
          label: 'Me',
        ),
      ],
    ),
  );
}
