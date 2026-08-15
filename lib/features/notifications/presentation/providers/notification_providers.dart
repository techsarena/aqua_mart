import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/notification_data_source.dart';
import '../../domain/entities/app_notification.dart';

final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>((
  ref,
) {
  if (useMockData) {
    // The feed differs per role, so it is rebuilt when the role changes.
    return MockNotificationDataSource(ref.watch(sessionProvider).activeRole);
  }
  return NotificationApiDataSource(ref.watch(apiClientProvider));
});

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final dtos = await ref
        .watch(notificationDataSourceProvider)
        .fetchNotifications();
    return dtos.map((d) => d.toDomain()).toList();
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
