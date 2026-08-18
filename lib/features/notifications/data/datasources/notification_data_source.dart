import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/notification_dto.dart';

abstract interface class NotificationRemoteDataSource {
  Future<List<NotificationDto>> fetchNotifications();
  Future<void> markAllRead();
  Future<void> markRead(String id);

  /// Claim this device for push (API_SPEC 9.1). A token can move between
  /// accounts when a phone is handed on, so the server re-points it rather
  /// than duplicating.
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? appVersion,
  });

  /// Drop this device — called on sign-out so a signed-out phone stops
  /// receiving another account's notifications.
  Future<void> unregisterDevice(String fcmToken);
}

class NotificationApiDataSource implements NotificationRemoteDataSource {
  const NotificationApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<NotificationDto>> fetchNotifications() async {
    final items = await _client.getList(ApiEndpoints.notifications);
    return items.map(NotificationDto.fromJson).toList();
  }

  @override
  Future<void> markAllRead() => _client.post<void>(ApiEndpoints.markAllRead);

  @override
  Future<void> markRead(String id) =>
      _client.patch<void>(ApiEndpoints.notification(id));

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? appVersion,
  }) => _client.post<void>(
    ApiEndpoints.devices,
    body: {
      'fcm_token': fcmToken,
      'platform': platform,
      if (appVersion != null) 'app_version': appVersion,
    },
  );

  @override
  Future<void> unregisterDevice(String fcmToken) => _client.delete<void>(
    ApiEndpoints.devices,
    body: {'fcm_token': fcmToken},
  );
}
