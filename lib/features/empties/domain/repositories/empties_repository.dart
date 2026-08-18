import '../../../../core/utils/result.dart';
import '../entities/empty_holding.dart';

abstract interface class EmptiesRepository {
  Future<Result<EmptiesSummary>> fetchEmpties();

  /// Hand bottles back to the seller, either swapped or refunded.
  Future<Result<void>> returnEmpties({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  });

  /// Book a collection with no order attached.
  Future<Result<void>> schedulePickup({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  });
}
