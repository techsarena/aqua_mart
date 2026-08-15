import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../orders/domain/entities/order_status.dart';
import '../../domain/entities/rider_run.dart';

abstract interface class RiderRemoteDataSource {
  Future<RiderRun> fetchRun();
  Future<RiderRun> completeStop(String stopId);
  Future<RiderRun> failStop(String stopId, String reason);
  Future<void> handOverCash(int amount);
  Future<RiderEarnings> fetchEarnings();
  Future<RiderInvitation?> fetchInvitation();
  Future<void> respondToInvitation(String id, {required bool accept});
}

class RiderApiDataSource implements RiderRemoteDataSource {
  const RiderApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<RiderRun> fetchRun() async {
    final json = await _client.get<Map<String, dynamic>>(ApiEndpoints.riderRun);
    return _runFrom(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<RiderRun> completeStop(String stopId) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.completeStop(stopId),
    );
    return _runFrom(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<RiderRun> failStop(String stopId, String reason) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.failStop(stopId),
      body: {'reason': reason},
    );
    return _runFrom(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<void> handOverCash(int amount) => _client.post<void>(
    ApiEndpoints.riderCashHandover,
    body: {'amount': amount},
  );

  @override
  Future<RiderEarnings> fetchEarnings() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.riderEarnings,
    );
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return RiderEarnings(
      deliveries: (data['deliveries'] as num?)?.toInt() ?? 0,
      perDelivery: (data['per_delivery'] as num?)?.toInt() ?? 0,
      onTimeBonus: (data['on_time_bonus'] as num?)?.toInt() ?? 0,
      fuelAdvance: (data['fuel_advance'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (data['rating_count'] as num?)?.toInt() ?? 0,
      perDayDeliveries:
          (data['per_day'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const [],
      isTopRider: data['is_top_rider'] as bool? ?? false,
    );
  }

  @override
  Future<RiderInvitation?> fetchInvitation() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.riderInvitations,
    );
    final items = (json['data'] ?? json['invitations']) as List? ?? const [];
    if (items.isEmpty) return null;

    final data = items.first as Map<String, dynamic>;
    return RiderInvitation(
      id: '${data['id']}',
      sellerName: data['seller_name'] as String? ?? '',
      sentBy: data['sent_by'] as String? ?? '',
      sentTo: data['sent_to'] as String? ?? '',
      areas: data['areas'] as String? ?? '',
      hours: data['hours'] as String? ?? '',
    );
  }

  @override
  Future<void> respondToInvitation(String id, {required bool accept}) =>
      _client.post<void>(
        ApiEndpoints.respondInvitation(id),
        body: {'accept': accept},
      );

  RiderRun _runFrom(Map<String, dynamic> json) => RiderRun(
    id: '${json['id']}',
    label: json['label'] as String? ?? 'Run',
    sellerName: json['seller_name'] as String? ?? '',
    finishedAt: DateTime.tryParse(json['finished_at'] as String? ?? ''),
    stops:
        (json['stops'] as List?)
            ?.map((e) => _stopFrom(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  RunStop _stopFrom(Map<String, dynamic> json) => RunStop(
    id: '${json['id']}',
    orderId: '${json['order_id']}',
    customerName: json['customer_name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    items: json['items'] as String? ?? '',
    amountToCollect: (json['amount_to_collect'] as num?)?.toInt() ?? 0,
    paymentMethod:
        PaymentMethod.values
            .where((p) => p.name == json['payment_method'])
            .firstOrNull ??
        PaymentMethod.cash,
    distanceMetres: (json['distance_metres'] as num?)?.toDouble() ?? 0,
    emptiesToCollect: (json['empties_to_collect'] as num?)?.toInt() ?? 0,
    status:
        StopStatus.values.where((s) => s.name == json['status']).firstOrNull ??
        StopStatus.pending,
    completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
  );
}

/// The morning run from the design, playable end to end.
class MockRiderDataSource implements RiderRemoteDataSource {
  MockRiderDataSource() : _run = _seedRun();

  RiderRun _run;

  static const _latency = Duration(milliseconds: 350);

  @override
  Future<RiderRun> fetchRun() async {
    await Future<void>.delayed(_latency);
    return _run;
  }

  @override
  Future<RiderRun> completeStop(String stopId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _updateStop(stopId, StopStatus.delivered);
  }

  @override
  Future<RiderRun> failStop(String stopId, String reason) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _updateStop(stopId, StopStatus.failed);
  }

  RiderRun _updateStop(String stopId, StopStatus status) {
    final stops = [
      for (final stop in _run.stops)
        if (stop.id == stopId)
          stop.copyWith(status: status, completedAt: DateTime.now())
        else
          stop,
    ];

    _run = _run.copyWith(
      stops: stops,
      // The run closes itself once nothing is left pending.
      finishedAt: stops.every((s) => s.status != StopStatus.pending)
          ? DateTime.now()
          : null,
    );
    return _run;
  }

  @override
  Future<void> handOverCash(int amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (amount < 0) throw const ValidationFailure('That amount is not valid.');
  }

  @override
  Future<RiderEarnings> fetchEarnings() async {
    await Future<void>.delayed(_latency);
    return const RiderEarnings(
      deliveries: 58,
      perDelivery: 150,
      onTimeBonus: 600,
      fuelAdvance: 1000,
      rating: 4.9,
      ratingCount: 58,
      perDayDeliveries: [8, 7, 9, 6, 8, 14, 6],
      isTopRider: true,
    );
  }

  @override
  Future<RiderInvitation?> fetchInvitation() async {
    await Future<void>.delayed(_latency);
    return const RiderInvitation(
      id: 'inv-1',
      sellerName: 'Chashma Pure Water',
      sentBy: 'Kamran Sahib',
      sentTo: '0301 552 8841',
      areas: 'Gulberg & Model Town',
      hours: '7 AM – 9 PM',
    );
  }

  @override
  Future<void> respondToInvitation(String id, {required bool accept}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  static RiderRun _seedRun() => RiderRun(
    id: 'run-1',
    label: 'Morning run',
    sellerName: 'Chashma Pure Water',
    stops: const [
      RunStop(
        id: 'st-1',
        orderId: 'so-a',
        customerName: 'Ayesha K.',
        address: 'House 42-B, Gulberg III',
        items: '2 × 25L refill',
        amountToCollect: 220,
        paymentMethod: PaymentMethod.cash,
        distanceMetres: 400,
        emptiesToCollect: 2,
      ),
      RunStop(
        id: 'st-2',
        orderId: 'so-b',
        customerName: 'Bilal R.',
        address: 'Model Town',
        items: '1 × 25L new',
        amountToCollect: 0,
        paymentMethod: PaymentMethod.jazzCash,
        distanceMetres: 1200,
      ),
      RunStop(
        id: 'st-3',
        orderId: 'so-c',
        customerName: 'Sana M.',
        address: 'Garden Town',
        items: '3 × 10L refill',
        amountToCollect: 210,
        paymentMethod: PaymentMethod.cash,
        distanceMetres: 2600,
        emptiesToCollect: 3,
      ),
      RunStop(
        id: 'st-4',
        orderId: 'so-d',
        customerName: 'Ahmad Store',
        address: 'Gulberg II',
        items: '6 × 25L refill',
        amountToCollect: 0,
        paymentMethod: PaymentMethod.khata,
        distanceMetres: 3100,
        emptiesToCollect: 6,
      ),
    ],
  );
}
