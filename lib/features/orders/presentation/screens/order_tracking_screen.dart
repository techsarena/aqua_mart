import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/map_placeholder.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/order_providers.dart';

/// Live order tracking. Doubles as the Track tab, which shows whatever order
/// is currently in flight.
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, this.orderId});

  /// Null when reached from the Track tab — the active order is used instead.
  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = orderId;

    if (id == null) {
      final active = ref.watch(activeOrderProvider);
      if (active == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Track')),
          body: Center(
            child: EmptyView(
              icon: Icons.local_shipping_outlined,
              title: 'Nothing on the way',
              message: 'When you place an order you can follow it here.',
              primaryLabel: 'Order water',
              onPrimary: () => context.goNamed(AppRoutes.customerHome),
            ),
          ),
        );
      }
      return _TrackingView(order: active, isTab: true);
    }

    final async = ref.watch(orderByIdProvider(id));
    return switch (async) {
      AsyncLoading() => Scaffold(
        appBar: AppBar(),
        body: const SkeletonList(itemCount: 3, itemHeight: 120),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(orderByIdProvider(id)),
        ),
      ),
      AsyncValue(value: final order) when order != null => _TrackingView(
        order: order,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TrackingView extends ConsumerWidget {
  const _TrackingView({required this.order, this.isTab = false});

  final Order order;
  final bool isTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = order.rider;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isTab,
        title: Text('Order #${order.reference}'),
        actions: [
          if (order.isCancellable)
            TextButton(
              onPressed: () => context.pushNamed(
                AppRoutes.cancelOrder,
                pathParameters: {'orderId': order.id},
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancel'),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: MapPlaceholder(
              height: 210,
              caption: 'live rider position · maps sdk',
              pins: const [
                MapPin(x: -0.3, y: -0.2, isPrimary: true, icon: Icons.two_wheeler_rounded),
                MapPin(x: 0.45, y: 0.4, icon: Icons.home_rounded),
              ],
            ),
          ),

          // ── Headline ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.status == OrderStatus.onTheWay)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${order.etaMinutes}',
                        style: AppTypography.heading(size: 42),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'min away',
                        style: AppTypography.body(
                          size: 15,
                          color: AppColors.textMuted(0.6),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    order.status.customerLabel,
                    style: AppTypography.heading(size: 26),
                  ),
                const SizedBox(height: 4),
                Text(
                  rider != null
                      ? '${rider.name} is on the way with ${order.itemsSummary}.'
                      : '${order.itemsSummary} from ${order.sellerName}.',
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.textMuted(0.65),
                  ),
                ),
              ],
            ),
          ),

          // ── The rider ───────────────────────────────────────────────────
          if (rider != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.gutter,
                0,
              ),
              child: AppCard(
                child: Row(
                  children: [
                    AppAvatar(name: rider.name, size: 46),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rider.name,
                            style: AppTypography.body(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${rider.sellerName} · ★ ${rider.rating}',
                            style: AppTypography.body(
                              size: 12.5,
                              color: AppColors.textMuted(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CircleAction(
                      icon: Icons.call_rounded,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connecting you through the app…'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _CircleAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),

          // ── The timeline ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              0,
            ),
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < order.timeline.length; i++)
                    _TimelineStep(
                      event: order.timeline[i],
                      isLast: i == order.timeline.length - 1,
                    ),
                ],
              ),
            ),
          ),

          // ── Delivered → rate it ─────────────────────────────────────────
          if (order.status == OrderStatus.delivered && order.rating == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.gutter,
                0,
              ),
              child: FilledButton(
                onPressed: () => context.pushNamed(
                  AppRoutes.rateOrder,
                  pathParameters: {'orderId': order.id},
                ),
                child: const Text('Rate this delivery'),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              0,
            ),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share_location_rounded, size: 18),
              label: const Text('Share live location with rider'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.accent100,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, size: 19, color: AppColors.accent),
      ),
    ),
  );
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.event, required this.isLast});

  final OrderEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = event.isComplete;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.accent : AppColors.neutral200,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: done ? AppColors.accent200 : AppColors.neutral200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: done ? AppColors.text : AppColors.textMuted(0.45),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    event.at != null
                        ? '${Formatters.time(event.at!)} · ${event.subtitle}'
                        : event.subtitle,
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
