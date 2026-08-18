import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/empty_holding.dart';
import '../models/empty_holding_dto.dart';

abstract interface class EmptiesRemoteDataSource {
  Future<EmptiesSummaryDto> fetchEmpties();
  Future<void> returnEmpties({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  });
  Future<void> schedulePickup({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  });
}

class EmptiesApiDataSource implements EmptiesRemoteDataSource {
  const EmptiesApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<EmptiesSummaryDto> fetchEmpties() async {
    final json = await _client.getObject(ApiEndpoints.empties);
    return EmptiesSummaryDto.fromJson(json ?? const {});
  }

  @override
  Future<void> returnEmpties({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  }) => _client.post<void>(
    ApiEndpoints.emptiesReturn,
    body: _body(holdingIds, handling),
  );

  @override
  Future<void> schedulePickup({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  }) => _client.post<void>(
    ApiEndpoints.emptiesPickup,
    body: _body(holdingIds, handling),
  );

  Map<String, dynamic> _body(List<String> ids, EmptiesHandling handling) => {
    'holding_ids': ids,
    'handling': handling.name,
  };
}
