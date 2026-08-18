import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_run.dart';
import '../models/rider_run_dto.dart';

abstract interface class RiderRemoteDataSource {
  Future<RiderRun> fetchRun();
  Future<RiderRun> completeStop(String stopId);
  Future<RiderRun> failStop(String stopId, String reason);
  Future<void> handOverCash(int amount);
  Future<RiderEarnings> fetchEarnings();
  Future<RiderInvitation?> fetchInvitation();
  Future<void> respondToInvitation(String id, {required bool accept});

  /// Resolves a 6-character rider code to the seller who issued it, or null
  /// when no seller matches.
  Future<RiderSellerMatch?> lookUpSellerCode(String code);

  /// Sends the completed registration to the seller for approval.
  Future<void> submitApplication(RiderApplication application);
}

class RiderApiDataSource implements RiderRemoteDataSource {
  const RiderApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<RiderRun> fetchRun() async {
    final json = await _client.getObject(ApiEndpoints.riderRun);
    return RiderRunDto.fromJson(json ?? const {});
  }

  @override
  Future<RiderRun> completeStop(String stopId) async {
    final json = await _client.postObject(ApiEndpoints.completeStop(stopId));
    return RiderRunDto.fromJson(json ?? const {});
  }

  @override
  Future<RiderRun> failStop(String stopId, String reason) async {
    final json = await _client.postObject(
      ApiEndpoints.failStop(stopId),
      body: {'reason': reason},
    );
    return RiderRunDto.fromJson(json ?? const {});
  }

  @override
  Future<void> handOverCash(int amount) => _client.post<void>(
    ApiEndpoints.riderCashHandover,
    body: {'amount': amount},
  );

  @override
  Future<RiderEarnings> fetchEarnings() async {
    final data =
        await _client.getObject(ApiEndpoints.riderEarnings) ?? const {};
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
    final items = await _client.getList(ApiEndpoints.riderInvitations);
    if (items.isEmpty) return null;

    final data = items.first;
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
  Future<void> respondToInvitation(String id, {required bool accept}) => _client
      .post<void>(ApiEndpoints.respondInvitation(id), body: {'accept': accept});

  @override
  Future<RiderSellerMatch?> lookUpSellerCode(String code) async {
    // The backend answers `data: null` for a code that matches nothing,
    // which is a miss rather than an error.
    final data = await _client.getObject(ApiEndpoints.sellerCode(code));
    if (data == null) return null;

    return RiderSellerMatch(
      code: code,
      sellerName: data['seller_name'] as String? ?? '',
      area: data['area'] as String? ?? '',
      riderCount: (data['rider_count'] as num?)?.toInt() ?? 0,
      joinedYear: (data['joined_year'] as num?)?.toInt() ?? DateTime.now().year,
    );
  }

  @override
  Future<void> submitApplication(RiderApplication application) =>
      _client.post<void>(
        ApiEndpoints.riderApplication,
        body: {
          'full_name': application.fullName,
          'cnic': application.cnic,
          'vehicle': application.vehicle?.name,
          'registration_number': application.registrationNumber,
          'seller_code': application.seller?.code,
        },
      );
}
