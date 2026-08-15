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

    // The map runs full-bleed under the status bar; the sheet rides over its
    // bottom edge. Both need to know where the notch is.
    final topInset = MediaQuery.paddingOf(context).top;
    const mapHeight = 330.0;
    const sheetOverlap = 26.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MapPlaceholder(
              height: mapHeight,
              radius: 0,
              caption: 'live rider position · maps sdk',
              route: const (
                MapPin(x: -0.55, y: -0.45),
                MapPin(x: 0.62, y: 0.3),
              ),
              pins: const [
                MapPin(
                  x: -0.55,
                  y: -0.45,
                  isPrimary: true,
                  icon: Icons.two_wheeler_rounded,
                ),
                MapPin(x: 0.62, y: 0.3, isDestination: true),
              ],
            ),
          ),

          // ── The sheet ───────────────────────────────────────────────────
          Positioned.fill(
            top: mapHeight - sheetOverlap,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: _sheet(context, rider),
            ),
          ),

          // ── Floating map controls ───────────────────────────────────────
          Positioned(
            top: topInset + AppSpacing.sm,
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
            child: Row(
              children: [
                if (!isTab)
                  _MapPillButton(
                    onTap: () => context.pop(),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 17,
                      color: AppColors.text,
                    ),
                  ),
                const Spacer(),
                _MapPillButton(
                  child: Text(
                    'Order #${order.reference}',
                    style: AppTypography.body(
                      size: 15.5,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheet(BuildContext context, RiderSummary? rider) => ListView(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xxl),
    children: [
      // The grab handle — decorative; the sheet does not drag.
      Center(
        child: Container(
          width: 88,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.neutral300,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),

      // ── Headline ────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xl,
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              rider != null
                  ? '${rider.name} is on the way with ${order.itemsSummary}.'
                  : '${order.itemsSummary} from ${order.sellerName}.',
              style: AppTypography.body(
                size: 16,
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
            AppSpacing.xl,
            AppSpacing.gutter,
            0,
          ),
          child: AppCard(
            child: Row(
              children: [
                AppAvatar(
                  name: rider.name,
                  size: 52,
                  background: AppColors.accent2_300,
                  foreground: AppColors.accent2_700,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider.name,
                        style: AppTypography.body(
                          size: 17,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${rider.sellerName} · ★ ${rider.rating}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.textMuted(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _CircleAction(
                  icon: Icons.call_rounded,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connecting you through the app…'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

      // ── The timeline ────────────────────────────────────────────────
      //
      // Sits directly on the sheet, not in a card — the design keeps the
      // rail flush with the headline above it.
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xl,
          AppSpacing.gutter,
          0,
        ),
        child: Builder(
          builder: (context) {
            final steps = order.trackingSteps;
            final current = _currentStepIndex(steps);

            return Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _TimelineStep(
                    event: steps[i],
                    isLast: i == steps.length - 1,
                    isCurrent: i == current,
                  ),
              ],
            );
          },
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
          AppSpacing.xl,
          AppSpacing.gutter,
          0,
        ),
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          child: const Text('Share live location with rider'),
        ),
      ),

      if (order.isCancellable)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            0,
          ),
          child: TextButton(
            onPressed: () => context.pushNamed(
              AppRoutes.cancelOrder,
              pathParameters: {'orderId': order.id},
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Cancel this order'),
          ),
        ),
    ],
  );
}

/// The step the order is on now — the last one reached, so long as something
/// still lies ahead. A finished rail has no "current" step: every marker on it
/// is a tick, including the last.
int _currentStepIndex(List<OrderEvent> steps) {
  final index = steps.lastIndexWhere((e) => e.isComplete);
  if (index < 0) return 0;
  return index == steps.length - 1 ? -1 : index;
}

/// A white pill floating over the map — the back button and the order number.
class _MapPillButton extends StatelessWidget {
  const _MapPillButton({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    elevation: 2,
    shadowColor: AppColors.text.withValues(alpha: 0.25),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        child: child,
      ),
    ),
  );
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
  const _TimelineStep({
    required this.event,
    required this.isLast,
    this.isCurrent = false,
  });

  final OrderEvent event;
  final bool isLast;

  /// The step the order sits on right now — drawn as a hollow accent ring
  /// rather than a filled tick, so "reached" and "finished" stay distinct.
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final done = event.isComplete;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _StepMarker(done: done, isCurrent: isCurrent),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: done && !isCurrent
                        ? AppColors.accent
                        : AppColors.neutral300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.body(
                      size: 17,
                      weight: FontWeight.w700,
                      color: done ? AppColors.text : AppColors.textMuted(0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.at != null
                        ? '${Formatters.time(event.at!)} · ${event.subtitle}'
                        : event.subtitle,
                    style: AppTypography.body(
                      size: 14.5,
                      color: AppColors.textMuted(done ? 0.55 : 0.4),
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

/// The dot on the timeline rail: filled tick when finished, hollow accent ring
/// for the step in progress, hollow grey ring for steps still ahead.
class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.done, required this.isCurrent});

  final bool done;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    if (done && !isCurrent) {
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent ? AppColors.accent : AppColors.neutral300,
          width: 3,
        ),
      ),
    );
  }
}
