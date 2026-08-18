import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/realtime/socket_events.dart';
import '../../data/models/order_dto.dart';
import '../../domain/entities/order.dart';
import 'order_providers.dart';

/// A rider's last known position, as `rider:location` reported it (8.4).
class RiderPosition {
  const RiderPosition({
    required this.riderId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.stopsBefore,
    this.etaMinutes,
    this.at,
  });

  final String riderId;
  final double latitude;
  final double longitude;
  final double? heading;
  final int? stopsBefore;
  final int? etaMinutes;
  final DateTime? at;

  static RiderPosition? fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble();
    final lng = (json['longitude'] as num?)?.toDouble();
    // A half-filled fix would pin the rider to an axis they were never on.
    if (lat == null || lng == null) return null;

    return RiderPosition(
      riderId: '${json['rider_id']}',
      latitude: lat,
      longitude: lng,
      heading: (json['heading'] as num?)?.toDouble(),
      stopsBefore: (json['stops_before'] as num?)?.toInt(),
      etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
      at: DateTime.tryParse(json['at'] as String? ?? ''),
    );
  }
}

/// One order, kept live while the tracking screen is on it (API_SPEC 8.3).
///
/// Joins `order:{id}` on build and leaves it on dispose — a customer is in
/// that room only while actually watching, which is what keeps the rider's
/// position from being fanned out to nobody.
///
/// REST is still the source of truth: the first value is a fetch, and the
/// socket only overwrites it with the whole object the server sends (8.6).
class OrderTrackingNotifier extends AsyncNotifier<Order> {
  OrderTrackingNotifier(this.orderId);

  final String orderId;

  @override
  Future<Order> build() async {
    final socket = ref.watch(socketClientProvider);
    socket.subscribeToOrder(orderId);
    ref.onDispose(() => socket.unsubscribeFromOrder(orderId));

    _listenForStatus(orderId);
    _listenForRiderAssigned(orderId);

    final result = await ref
        .watch(orderRepositoryProvider)
        .orderById(orderId);
    return result.when(success: (order) => order, failure: (f) => throw f);
  }

  void _listenForStatus(String orderId) {
    ref.listen(socketEventProvider(SocketEvents.orderStatus), (_, next) {
      final payload = next.value;
      if (payload == null || '${payload['order_id']}' != orderId) return;

      // Whole object, never a diff — so this is a replace, not a merge.
      final order = payload['order'];
      if (order is! Map<String, dynamic>) return;
      state = AsyncData(OrderDto.fromJson(order).toDomain());

      // A status change moves the order between the active/past lists.
      ref.invalidate(orderListProvider);
    });
  }

  /// `order:rider_assigned` carries only the rider's details, not a whole
  /// order, so this one genuinely is a merge onto what we already hold.
  void _listenForRiderAssigned(String orderId) {
    ref.listen(socketEventProvider(SocketEvents.riderAssigned), (_, next) {
      final payload = next.value;
      if (payload == null || '${payload['order_id']}' != orderId) return;

      final current = state.value;
      if (current == null) return;

      state = AsyncData(
        current.copyWith(
          rider: RiderSummary(
            id: '${payload['rider_id']}',
            name: payload['rider_name'] as String? ?? '',
            sellerName: current.sellerName,
            rating: (payload['rider_rating'] as num?)?.toDouble() ?? 0,
            stopsBefore: (payload['stops_before'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    });
  }
}

final orderTrackingProvider =
    AsyncNotifierProvider.autoDispose.family<
      OrderTrackingNotifier,
      Order,
      String
    >(OrderTrackingNotifier.new);

/// The rider's live position for one order, or null until the first ping.
///
/// Autodisposed with the screen watching it, so a closed tracking screen
/// stops the server fanning positions to it.
final riderPositionProvider = Provider.autoDispose
    .family<RiderPosition?, String>((ref, orderId) {
      final event = ref.watch(
        socketEventProvider(SocketEvents.riderLocation),
      );
      final payload = event.value;
      if (payload == null || '${payload['order_id']}' != orderId) return null;
      return RiderPosition.fromJson(payload);
    });
