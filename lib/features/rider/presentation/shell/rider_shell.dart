import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// The rider's three tabs: the run, the cash, the money earned.
class RiderShell extends StatelessWidget {
  const RiderShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) =>
          shell.goBranch(index, initialLocation: index == shell.currentIndex),
      // The rider bar sits on white; everything else comes from the theme.
      backgroundColor: AppColors.surface,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route_rounded),
          label: 'My run',
        ),
        NavigationDestination(
          icon: Icon(Icons.payments_outlined),
          selectedIcon: Icon(Icons.payments_rounded),
          label: 'Cash',
        ),
        NavigationDestination(
          icon: Icon(Icons.trending_up_outlined),
          selectedIcon: Icon(Icons.trending_up_rounded),
          label: 'Earnings',
        ),
      ],
    ),
  );
}
