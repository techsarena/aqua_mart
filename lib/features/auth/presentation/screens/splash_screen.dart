import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/aqua_logo.dart';

/// Held only while the session is restored from storage.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(gradient: AppColors.darkGradient),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AquaLogoMark(size: 96, onDark: true),
          SizedBox(height: 24),
          AquaWordmark(fontSize: 34, onDark: true),
        ],
      ),
    ),
  );
}
