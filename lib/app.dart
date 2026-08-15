import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_language.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

class AquaMartApp extends ConsumerWidget {
  const AquaMartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final language = ref.watch(sessionProvider).language ?? AppLanguage.english;

    return MaterialApp.router(
      title: 'Aqua Mart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: language.locale,
      supportedLocales: AppLanguage.values.map((l) => l.locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Urdu mirrors the whole layout; Roman Urdu stays left-to-right.
        return Directionality(
          textDirection: language.isRtl ? TextDirection.rtl : TextDirection.ltr,
          // Cap text scaling so dense screens (the seller queue, the rider
          // run) stay readable at large accessibility sizes.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
