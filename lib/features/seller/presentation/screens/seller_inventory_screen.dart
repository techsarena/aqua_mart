import 'package:aqua_mart/shared/widgets/app_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../../../notifications/presentation/widgets/alerts_bell_button.dart';
import '../providers/seller_providers.dart';
import 'edit_bottle_screen.dart';

/// The seller's bottles: what they charge and what is on the shelf.
class SellerInventoryScreen extends ConsumerWidget {
  const SellerInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sellerInventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bottles', style: AppTypography.heading(size: 30)),
        toolbarHeight: 72,
        actions: const [
          AlertsBellButton(routeName: AppRoutes.sellerAlerts),
          SizedBox(width: AppSpacing.gutter),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap a price to change it. Stock syncs with your ERP.',
                style: AppTypography.body(
                  size: 14.5,
                  color: AppColors.textMuted(0.55),
                ),
              ),
            ),
          ),
        ),
      ),
      body: switch (async) {
        AsyncLoading() => const SkeletonList(itemCount: 3, itemHeight: 128),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(sellerInventoryProvider),
        ),
        AsyncValue(value: final bottles) =>
          (bottles?.isEmpty ?? true)
              ? const Center(
                  child: EmptyView(
                    icon: Icons.water_drop_outlined,
                    title: 'No bottles listed',
                    message: 'Add the sizes you sell so customers can order.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.xxl,
                  ),
                  itemCount: bottles!.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => _InventoryCard(
                    bottle: bottles[i],
                    onTap: () => context.pushNamed(
                      AppRoutes.sellerEditBottle,
                      pathParameters: {'bottleId': bottles[i].id},
                    ),
                    onHide: () => ref
                        .read(sellerInventoryProvider.notifier)
                        .save(bottles[i].copyWith(isVisible: false)),
                    onVisibilityChanged: (visible) => ref
                        .read(sellerInventoryProvider.notifier)
                        .save(bottles[i].copyWith(isVisible: visible)),
                  ),
                ),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(
          AppRoutes.sellerEditBottle,
          pathParameters: {'bottleId': EditBottleScreen.newBottleId},
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Add a bottle',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

/// The bottle-shaped size chip — rounded shoulders, litres at the foot.
class _SizeSwatch extends StatelessWidget {
  const _SizeSwatch({required this.size, required this.tone});

  final BottleSize size;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 58,
    alignment: Alignment.bottomCenter,
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    decoration: BoxDecoration(
      color: tone,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.md),
        bottom: Radius.circular(AppSpacing.sm),
      ),
    ),
    child: Text(
      size.label,
      style: AppTypography.body(
        size: 11,
        weight: FontWeight.w800,
        color: AppColors.shelfFullLabel,
      ),
    ),
  );
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.bottle,
    required this.onTap,
    required this.onHide,
    required this.onVisibilityChanged,
  });

  final Bottle bottle;
  final VoidCallback onTap;
  final VoidCallback onHide;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    // Low stock turns the whole card into an alert panel: tinted ground,
    // accent outline, and the two actions that resolve it.
    final isLow = bottle.isLowStock;

    return AppCard(
      onTap: onTap,
      color: isLow ? AppColors.accent100 : null,
      borderColor: isLow ? AppColors.accent300 : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SizeSwatch(
                size: bottle.size,
                tone: isLow ? AppColors.accent200 : AppColors.accent2_200,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bottle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading(size: 18),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isLow
                          ? 'Only ${bottle.filledStock} left — customers still '
                                'see it'
                          : '${bottle.filledStock} filled'
                                '${bottle.emptiesInYard > 0 ? ' · ${bottle.emptiesInYard} empties in yard' : ''}',
                      style: AppTypography.body(
                        size: 13,
                        weight: isLow ? FontWeight.w700 : FontWeight.w400,
                        color: isLow
                            ? AppColors.accent700
                            : AppColors.textMuted(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              // The alert panel carries Hide as a button instead, so the
              // switch would be a second control for the same thing.
              if (!isLow) ...[
                const SizedBox(width: AppSpacing.sm),
                Switch(
                  value: bottle.isVisible,
                  onChanged: onVisibilityChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.accent2,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppColors.neutral300,
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
              ],
            ],
          ),

          if (isLow) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Add stock'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onHide,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.neutral300),
                    ),
                    child: const Text('Hide for now'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _PriceChip(
                    label: 'Refill price',
                    value: Formatters.rupees(bottle.refillPrice),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _PriceChip(
                    label: 'New bottle',
                    value: Formatters.rupees(bottle.newPrice),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A price the seller can tap to change — drawn as a dashed "slot" so it
/// reads as editable rather than as a fixed label.
class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(
      color: AppColors.neutral300,
      radius: AppRadius.md,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Text(value, style: AppTypography.heading(size: 20)),
        ],
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
