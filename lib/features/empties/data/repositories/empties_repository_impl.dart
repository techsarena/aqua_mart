import '../../../../core/utils/result.dart';
import '../../domain/entities/empty_holding.dart';
import '../../domain/repositories/empties_repository.dart';
import '../datasources/empties_data_source.dart';

class EmptiesRepositoryImpl implements EmptiesRepository {
  const EmptiesRepositoryImpl(this._remote);

  final EmptiesRemoteDataSource _remote;

  @override
  Future<Result<EmptiesSummary>> fetchEmpties() =>
      Result.guard(() async => (await _remote.fetchEmpties()).toDomain());

  @override
  Future<Result<void>> returnEmpties({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  }) => Result.guard(
    () => _remote.returnEmpties(holdingIds: holdingIds, handling: handling),
  );

  @override
  Future<Result<void>> schedulePickup({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  }) => Result.guard(
    () => _remote.schedulePickup(holdingIds: holdingIds, handling: handling),
  );
}
