import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/realtime/socket_events.dart';
import '../../data/datasources/notification_data_source.dart';
import '../../data/models/notification_dto.dart';
import '../../domain/entities/app_notification.dart';

final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>(
  (ref) => NotificationApiDataSource(ref.watch(apiClientProvider)),
);

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    _listenForPushes();
    final dtos = await ref
        .watch(notificationDataSourceProvider)
        .fetchNotifications();
    return dtos.map((d) => d.toDomain()).toList();
  }

  /// `notification:new` on `user:{id}` replaces polling this feed (8.4).
  ///
  /// The socket carries the whole object, so a new arrival is prepended
  /// rather than triggering a refetch. If the socket never connects the feed
  /// is still correct — it just updates on the next load (8.6).
  void _listenForPushes() {
    ref.listen(socketEventProvider(SocketEvents.notificationNew), (_, next) {
      final payload = next.value?['notification'];
      if (payload is! Map<String, dynamic>) return;

      final incoming = NotificationDto.fromJson(payload).toDomain();
      final current = state.value ?? const <AppNotification>[];
      // The server may re-send one we already hold; last write wins.
      state = AsyncData([
        incoming,
        ...current.where((n) => n.id != incoming.id),
      ]);
    });
  }

  Future<void> markAllRead() async {
    await ref.read(notificationDataSourceProvider).markAllRead();
    ref.invalidateSelf();
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationDataSourceProvider).markRead(id);
    ref.invalidateSelf();
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).value ?? const [];
  return items.where((n) => !n.isRead).length;
});
