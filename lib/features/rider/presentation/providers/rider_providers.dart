import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/rider_data_source.dart';
import '../../domain/entities/rider_run.dart';

final riderDataSourceProvider = Provider<RiderRemoteDataSource>((ref) {
  if (useMockData) return MockRiderDataSource();
  return RiderApiDataSource(ref.watch(apiClientProvider));
});

class RiderRunNotifier extends AsyncNotifier<RiderRun> {
  @override
  Future<RiderRun> build() => ref.watch(riderDataSourceProvider).fetchRun();

  Future<void> completeStop(String stopId) async {
    final run = await ref.read(riderDataSourceProvider).completeStop(stopId);
    state = AsyncData(run);
  }

  Future<void> failStop(String stopId, String reason) async {
    final run = await ref
        .read(riderDataSourceProvider)
        .failStop(stopId, reason);
    state = AsyncData(run);
  }

  Future<Result<void>> handOverCash(int amount) => Result.guard(
    () => ref.read(riderDataSourceProvider).handOverCash(amount),
  );
}

final riderRunProvider = AsyncNotifierProvider<RiderRunNotifier, RiderRun>(
  RiderRunNotifier.new,
);

final riderEarningsProvider = FutureProvider<RiderEarnings>(
  (ref) => ref.watch(riderDataSourceProvider).fetchEarnings(),
);

final riderInvitationProvider = FutureProvider<RiderInvitation?>(
  (ref) => ref.watch(riderDataSourceProvider).fetchInvitation(),
);
