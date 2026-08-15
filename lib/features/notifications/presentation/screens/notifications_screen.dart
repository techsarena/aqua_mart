import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

/// The alerts feed. Shared by all three roles — only the content differs.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.title = 'Notifications'});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: switch (async) {
        AsyncLoading() => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          child: SkeletonList(itemCount: 5, itemHeight: 76),
        ),
        AsyncError(:final error) => ErrorView(
          failure: asFailure(error),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        AsyncValue(value: final items) => (items?.isEmpty ?? true)
            ? const Center(
                child: EmptyView(
                  icon: Icons.notifications_none_rounded,
                  title: 'Nothing new',
                  message: 'Order updates and reminders will show up here.',
                ),
              )
            : _Feed(items: items!),
      },
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = items
        .where((n) => n.createdAt.difference(now).inDays == 0)
        .toList();
    final earlier = items.where((n) => !today.contains(n)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          'Order updates, price changes and reorder reminders.',
          style: AppTypography.body(size: 12.5, color: AppColors.textMuted(0.55)),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (today.isNotEmpty) ...[
          const _GroupHeader('Today'),
          for (final item in today) _NotificationTile(item: item),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _GroupHeader('Earlier'),
          for (final item in earlier) _NotificationTile(item: item),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.body(
        size: 10.5,
        weight: FontWeight.w800,
        letterSpacing: 0.9,
        color: AppColors.textMuted(0.45),
      ),
    ),
  );
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, tint) = _visualsFor(item.kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: item.isRead ? AppColors.surface : AppColors.accent100,
        onTap: () {
          ref.read(notificationsProvider.notifier).markRead(item.id);
          final link = item.deepLink;
          if (link != null) context.push(link);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 19, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.65),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.relative(item.createdAt),
                    style: AppTypography.body(
                      size: 11,
                      color: AppColors.textMuted(0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 4),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color) _visualsFor(NotificationKind kind) => switch (kind) {
    NotificationKind.riderOnTheWay => (
      Icons.two_wheeler_rounded,
      AppColors.accent,
    ),
    NotificationKind.orderUpdate => (
      Icons.check_circle_outline_rounded,
      AppColors.accent2,
    ),
    NotificationKind.priceChange => (
      Icons.trending_down_rounded,
      AppColors.accent2_600,
    ),
    NotificationKind.reorderReminder => (
      Icons.replay_rounded,
      AppColors.accent400,
    ),
    NotificationKind.khataDue => (
      Icons.account_balance_wallet_outlined,
      AppColors.warning,
    ),
    NotificationKind.stockLow => (
      Icons.inventory_2_outlined,
      AppColors.warning,
    ),
    NotificationKind.complaint => (
      Icons.report_gmailerrorred_rounded,
      AppColors.danger,
    ),
    NotificationKind.payout => (Icons.payments_outlined, AppColors.accent2),
    NotificationKind.review => (Icons.star_rounded, Color(0xFFE8A33D)),
    NotificationKind.riderRun => (
      Icons.local_shipping_outlined,
      AppColors.accent,
    ),
  };
}
