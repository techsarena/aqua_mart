import '../../domain/entities/app_notification.dart';

class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.deepLink,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String createdAt;
  final bool isRead;
  final String? deepLink;

  factory NotificationDto.fromJson(Map<String, dynamic> json) =>
      NotificationDto(
        id: '${json['id']}',
        kind: json['kind'] as String? ?? 'orderUpdate',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt:
            json['created_at'] as String? ?? DateTime.now().toIso8601String(),
        isRead: json['is_read'] as bool? ?? false,
        deepLink: json['deep_link'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'body': body,
    'created_at': createdAt,
    'is_read': isRead,
    'deep_link': deepLink,
  };

  NotificationDto copyWith({bool? isRead}) => NotificationDto(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    deepLink: deepLink,
  );

  AppNotification toDomain() => AppNotification(
    id: id,
    kind:
        NotificationKind.values.where((k) => k.name == kind).firstOrNull ??
        NotificationKind.orderUpdate,
    title: title,
    body: body,
    createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
    isRead: isRead,
    deepLink: deepLink,
  );
}
