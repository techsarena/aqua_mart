import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/realtime/socket_events.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/rider_data_source.dart';
import '../../data/models/rider_run_dto.dart';
import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_run.dart';

final riderDataSourceProvider = Provider<RiderRemoteDataSource>((ref) {
  if (useMockData) return MockRiderDataSource();
  return RiderApiDataSource(ref.watch(apiClientProvider));
});

class RiderRunNotifier extends AsyncNotifier<RiderRun> {
  @override
  Future<RiderRun> build() {
    _listenForRunChanges();
    return ref.watch(riderDataSourceProvider).fetchRun();
  }

  /// `run:updated` on `rider:{id}` — a stop completed elsewhere, a stop added
  /// mid-run, or a resequence. The payload is the whole run (8.4), so this
  /// replaces rather than merges.
  void _listenForRunChanges() {
    ref.listen(socketEventProvider(SocketEvents.runUpdated), (_, next) {
      final payload = next.value;
      if (payload == null || payload['id'] == null) return;
      state = AsyncData(RiderRunDto.fromJson(payload));
    });
  }

  /// The rider's position, pushed while they are on a run (8.5).
  ///
  /// The server drops pings from a rider who is not on an active run and
  /// rate-limits to one per 10s, so callers need not gate this themselves —
  /// but they should still not call it faster than the run moves.
  void pushLocation({
    required double latitude,
    required double longitude,
    double? heading,
  }) => ref
      .read(socketClientProvider)
      .sendRiderPing(
        latitude: latitude,
        longitude: longitude,
        heading: heading,
      );

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

/// The rider's registration as it is filled in across sign-up steps 3–5.
///
/// Held here rather than passed between screens so a back-step keeps what was
/// already typed, and so the review screen can read the whole application.
class RiderApplicationNotifier extends Notifier<RiderApplication> {
  @override
  RiderApplication build() => const RiderApplication();

  void setIdentity({required String fullName, required String cnic}) =>
      state = state.copyWith(fullName: fullName, cnic: cnic);

  void setVehicle(RiderVehicle vehicle) {
    // Switching to on foot drops a plate typed for a previous choice, which
    // would otherwise be submitted for a vehicle that has none.
    state = vehicle.needsRegistration
        ? state.copyWith(vehicle: vehicle)
        : RiderApplication(
            fullName: state.fullName,
            cnic: state.cnic,
            phone: state.phone,
            vehicle: vehicle,
            seller: state.seller,
          );
  }

  void setRegistrationNumber(String value) =>
      state = state.copyWith(registrationNumber: value);

  void setSeller(RiderSellerMatch seller) =>
      state = state.copyWith(seller: seller);

  Future<Result<void>> submit() => Result.guard(
    () => ref.read(riderDataSourceProvider).submitApplication(state),
  );
}

final riderApplicationProvider =
    NotifierProvider<RiderApplicationNotifier, RiderApplication>(
      RiderApplicationNotifier.new,
    );

/// Looks a typed invite code up against the seller who issued it.
///
/// Family-scoped on the code so each attempt is its own request and a
/// corrected code re-runs rather than serving the previous miss.
final sellerCodeProvider = FutureProvider.family<RiderSellerMatch?, String>(
  (ref, code) => ref.watch(riderDataSourceProvider).lookUpSellerCode(code),
);
