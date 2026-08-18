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

/// The two holdings from the design, with the handover applied locally so the
/// screen behaves end to end.
class MockEmptiesDataSource implements EmptiesRemoteDataSource {
  MockEmptiesDataSource();

  static const _latency = Duration(milliseconds: 600);

  final List<EmptyHoldingDto> _holdings = [
    const EmptyHoldingDto(
      id: 'e-25',
      litres: 25,
      count: 2,
      sellerId: 'slr-chashma',
      sellerName: 'Chashma',
      deposit: 600,
    ),
    const EmptyHoldingDto(
      id: 'e-10',
      litres: 10,
      count: 1,
      sellerId: 'slr-ravi',
      sellerName: 'Ravi Aqua',
      deposit: 300,
    ),
  ];

  @override
  Future<EmptiesSummaryDto> fetchEmpties() async {
    await Future<void>.delayed(_latency);
    return EmptiesSummaryDto(
      holdings: List.of(_holdings),
      totalDeposit: _holdings.fold(0, (sum, h) => sum + h.deposit),
      refillPricePerBottle: 180,
    );
  }

  @override
  Future<void> returnEmpties({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  }) => _collect(holdingIds);

  @override
  Future<void> schedulePickup({
    required List<String> holdingIds,
    required EmptiesHandling handling,
  }) => _collect(holdingIds);

  Future<void> _collect(List<String> ids) async {
    await Future<void>.delayed(_latency);
    _holdings.removeWhere((h) => ids.contains(h.id));
  }
}
