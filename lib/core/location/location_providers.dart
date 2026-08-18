import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_location.dart';

final appLocationServiceProvider = Provider<AppLocationService>(
  (_) => AppLocationService(),
);

/// Requested once and shared by the home header and the address picker.
/// Failures resolve to null so denied permission never blocks the app.
final currentLocationProvider = FutureProvider<AppLocation?>((ref) async {
  try {
    return await ref.watch(appLocationServiceProvider).currentLocation();
  } catch (_) {
    return null;
  }
});
