import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../models/notification_dto.dart';

abstract interface class NotificationRemoteDataSource {
  Future<List<NotificationDto>> fetchNotifications();
  Future<void> markAllRead();
  Future<void> markRead(String id);
}

class NotificationApiDataSource implements NotificationRemoteDataSource {
  const NotificationApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<NotificationDto>> fetchNotifications() async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
    );
    final items = (json['data'] ?? json['notifications']) as List? ?? const [];
    return items
        .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAllRead() => _client.post<void>(ApiEndpoints.markAllRead);

  @override
  Future<void> markRead(String id) =>
      _client.patch<void>('${ApiEndpoints.notifications}/$id');
}

/// Serves a different feed per role — customers see order updates, sellers see
/// stock and money, riders see their runs.
class MockNotificationDataSource implements NotificationRemoteDataSource {
  MockNotificationDataSource(this.role) : _items = _seedFor(role);

  final UserRole role;
  List<NotificationDto> _items;

  @override
  Future<List<NotificationDto>> fetchNotifications() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<NotificationDto>.unmodifiable(_items);
  }

  @override
  Future<void> markAllRead() async {
    _items = [for (final n in _items) n.copyWith(isRead: true)];
  }

  @override
  Future<void> markRead(String id) async {
    _items = [
      for (final n in _items) if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  static List<NotificationDto> _seedFor(UserRole role) {
    final now = DateTime.now();
    String iso(Duration ago) => now.subtract(ago).toIso8601String();

    return switch (role) {
      UserRole.customer => [
        NotificationDto(
          id: 'n-1',
          kind: 'riderOnTheWay',
          title: 'Imran is on the way',
          body:
              '2 × 25L refill · about 14 minutes away. Keep 2 empties ready.',
          createdAt: iso(const Duration(minutes: 12)),
          deepLink: '/customer/order/o-1/track',
        ),
        NotificationDto(
          id: 'n-2',
          kind: 'orderUpdate',
          title: 'Chashma accepted your order',
          body: 'Order #SO-2418 · Rs 220 · cash on delivery',
          createdAt: iso(const Duration(minutes: 31)),
          deepLink: '/customer/order/o-1/track',
        ),
        NotificationDto(
          id: 'n-3',
          kind: 'reorderReminder',
          title: 'Time to reorder?',
          body: 'You usually order every 7 days. Tap to send your usual.',
          createdAt: iso(const Duration(days: 1)),
          isRead: true,
        ),
        NotificationDto(
          id: 'n-4',
          kind: 'priceChange',
          title: 'Ravi Aqua dropped 25L to Rs 95',
          body: "A seller you've used before changed their refill price.",
          createdAt: iso(const Duration(days: 13)),
          isRead: true,
          deepLink: '/customer/seller/s-2',
        ),
        NotificationDto(
          id: 'n-5',
          kind: 'khataDue',
          title: 'Khata due in 5 days',
          body: 'Rs 1,180 to Chashma Pure Water, due 30 Aug.',
          createdAt: iso(const Duration(days: 14)),
          isRead: true,
        ),
      ],
      UserRole.seller => [
        NotificationDto(
          id: 's-n1',
          kind: 'orderUpdate',
          title: 'New order from Ayesha K.',
          body:
              '2 × 25L refill · Rs 220 · Gulberg III. Accept within 5 min.',
          createdAt: iso(const Duration(minutes: 2)),
          deepLink: '/seller/orders',
        ),
        NotificationDto(
          id: 's-n2',
          kind: 'stockLow',
          title: '6L bottles running low',
          body: '3 left. Customers can still order them.',
          createdAt: iso(const Duration(hours: 2)),
          deepLink: '/seller/bottles',
        ),
        NotificationDto(
          id: 's-n3',
          kind: 'complaint',
          title: 'Ayesha K. reported a broken seal',
          body:
              'Order #SO-2418 · settle it within 24 hrs to protect your rating.',
          createdAt: iso(const Duration(hours: 1)),
          deepLink: '/seller/disputes/d-1',
        ),
        NotificationDto(
          id: 's-n4',
          kind: 'riderRun',
          title: 'Imran finished the morning run',
          body: '9 delivered · Rs 1,340 cash handed in.',
          createdAt: iso(const Duration(hours: 4)),
          isRead: true,
        ),
        NotificationDto(
          id: 's-n5',
          kind: 'payout',
          title: 'Payout sent · Rs 38,400',
          body: 'Week of 28 Jul, to Meezan ••4471.',
          createdAt: iso(const Duration(days: 12)),
          isRead: true,
          deepLink: '/seller/payouts',
        ),
        NotificationDto(
          id: 's-n6',
          kind: 'review',
          title: 'New 5-star review',
          body: '"Bohat time pe aaye, seal bhi theek tha." — Sana M.',
          createdAt: iso(const Duration(days: 13)),
          isRead: true,
        ),
      ],
      UserRole.rider => [
        NotificationDto(
          id: 'r-n1',
          kind: 'riderRun',
          title: 'Morning run assigned',
          body: '12 stops · Rs 3,580 to collect.',
          createdAt: iso(const Duration(hours: 5)),
          deepLink: '/rider/run',
        ),
      ],
    };
  }
}
