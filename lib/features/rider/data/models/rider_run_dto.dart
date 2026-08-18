import '../../../orders/domain/entities/order_status.dart';
import '../../domain/entities/rider_run.dart';

/// Parsing for the run shape (API_SPEC 7.1).
///
/// Lives here rather than inside the data source because the identical shape
/// arrives two ways: as the REST body of `/rider/run`, and as the payload of
/// the `run:updated` socket event (8.4). One definition, so a field rename
/// cannot fix one path and miss the other.
abstract final class RiderRunDto {
  static RiderRun fromJson(Map<String, dynamic> json) => RiderRun(
    id: '${json['id']}',
    label: json['label'] as String? ?? 'Run',
    sellerName: json['seller_name'] as String? ?? '',
    finishedAt: DateTime.tryParse(json['finished_at'] as String? ?? ''),
    stops:
        (json['stops'] as List?)
            ?.map((e) => stopFromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  static RunStop stopFromJson(Map<String, dynamic> json) => RunStop(
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
    plot: _plotFrom(json['plot'] as Map<String, dynamic>?),
  );

  static ({double x, double y})? _plotFrom(Map<String, dynamic>? json) {
    if (json == null) return null;
    final x = (json['x'] as num?)?.toDouble();
    final y = (json['y'] as num?)?.toDouble();
    // A half-supplied plot would pin the stop to an axis it was never on.
    if (x == null || y == null) return null;
    return (x: x, y: y);
  }
}
