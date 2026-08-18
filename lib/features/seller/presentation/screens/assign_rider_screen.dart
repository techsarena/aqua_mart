import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../domain/entities/seller_dashboard.dart';
import '../providers/seller_providers.dart';

/// "Send with who?" — pick a rider for a packed order.
///
/// The best fit is computed and labelled rather than left for the seller to
/// work out from raw distances.
class AssignRiderScreen extends ConsumerStatefulWidget {
  const AssignRiderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<AssignRiderScreen> createState() => _AssignRiderScreenState();
}

class _AssignRiderScreenState extends ConsumerState<AssignRiderScreen> {
  String? _selectedRiderId;

  /// Sentinel for "I'll deliver it myself".
  static const _selfId = '__self__';

  bool _assigning = false;

  Future<void> _assign() async {
    setState(() => _assigning = true);

    if (_selectedRiderId != _selfId) {
      await ref
          .read(sellerQueueProvider.notifier)
          .assignRider(orderId: widget.orderId, riderId: _selectedRiderId!);
    }

    if (!mounted) return;
    setState(() => _assigning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rider notified — order is on its way.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final riders = ref.watch(sellerRidersProvider).value ?? const <Rider>[];
    final order = (ref.watch(sellerQueueProvider).value ?? const [])
        .where((o) => o.id == widget.orderId)
        .firstOrNull;

    // Closest available rider wins the "Best fit" badge.
    final available = riders.where((r) => r.isAvailable).toList()
      ..sort(
        (a, b) => (a.distanceFromCustomer ?? double.infinity).compareTo(
          b.distanceFromCustomer ?? double.infinity,
        ),
      );
    final bestFitId = available.firstOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Send with who?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          // ── What's going out ────────────────────────────────────────────
          if (order != null)
            AppCard(
              color: AppColors.accent100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #${order.reference}',
                        style: AppTypography.body(
                          size: 13,
                          weight: FontWeight.w800,
                          color: AppColors.accent800,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const AppTag('Packed', tone: TagTone.accent2),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // Geocoded areas run to a full postal line; shortened so
                    // the row stays one line beside the customer's name.
                    '${order.customerName} · '
                    '${Formatters.areaLabel(order.address.area)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.accent800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.itemsSummary} · '
                    '${Formatters.rupees(order.total)} '
                    '${order.paymentMethod.shortLabel.toLowerCase()}'
                    '${order.emptiesReturned > 0 ? ' · ${order.emptiesReturned} empties to collect' : ''}',
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.accent800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

          // ── Who can take it ─────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Your riders',
            style: AppTypography.body(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final rider in riders) ...[
            SelectableOption(
              title: rider.name,
              subtitle:
                  rider.id == bestFitId && rider.distanceFromCustomer != null
                  ? '${rider.stopsLeft} stops · closest, '
                        '${Formatters.distance(rider.distanceFromCustomer!)} away'
                  : rider.statusLine,
              enabled: rider.isAvailable,
              selected: _selectedRiderId == rider.id,
              onTap: () => setState(() => _selectedRiderId = rider.id),
              leading: AppAvatar(name: rider.name, size: 42),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rider.id == bestFitId)
                    const AppTag('Best fit', tone: TagTone.accent2),
                  if (rider.etaMinutes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '~${rider.etaMinutes} min',
                      style: AppTypography.body(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: AppColors.textMuted(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          const SizedBox(height: AppSpacing.md),
          SelectableOption(
            title: "I'll deliver it myself",
            subtitle: 'Adds it to your own run',
            icon: Icons.directions_walk_rounded,
            selected: _selectedRiderId == _selfId,
            onTap: () => setState(() => _selectedRiderId = _selfId),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _assigning
            ? 'Notifying…'
            : _selectedRiderId == null
            ? 'Pick a rider'
            : _selectedRiderId == _selfId
            ? 'Add to my run'
            : 'Assign to '
                  '${riders.firstWhere((r) => r.id == _selectedRiderId).name.split(' ').first}'
                  ' · notify them',
        enabled: _selectedRiderId != null && !_assigning,
        onPressed: _assign,
      ),
    );
  }
}
