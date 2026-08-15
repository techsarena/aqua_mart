import 'package:flutter/material.dart';

import '../../../notifications/presentation/screens/notifications_screen.dart';

/// The seller's alerts — orders, stock and money.
///
/// Same feed component as the customer's; the data source supplies the
/// role-appropriate items.
class SellerAlertsScreen extends StatelessWidget {
  const SellerAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NotificationsScreen(title: 'Alerts');
}
