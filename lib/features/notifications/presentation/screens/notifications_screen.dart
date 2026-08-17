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
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notification_providers.dart';

/// The alerts feed. Shared by all three roles — only the content differs.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    this.title = 'Notifications',
    this.subtitle = 'Order updates, price changes and reorder reminders.',
  });

  final String title;

  /// The line under the title — each role summarises its own feed.
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        titleSpacing: AppSpacing.gutter,
        title: Row(
          children: [
            if (context.canPop()) ...[
              const BackDiscButton(),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(title, style: AppTypography.heading(size: 30)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            style: TextButton.styleFrom(
              textStyle: AppTypography.body(
                size: 13.5,
                weight: FontWeight.w700,
              ),
            ),
            child: const Text('Mark all read'),
          ),
          const SizedBox(width: AppSpacing.md),
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
        AsyncValue(value: final items) =>
          (items?.isEmpty ?? true)
              ? const Center(
                  child: EmptyView(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing new',
                    message: 'Order updates and reminders will show up here.',
                  ),
                )
              : _Feed(items: items!, subtitle: subtitle),
      },
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({required this.items, required this.subtitle});

  final List<AppNotification> items;
  final String subtitle;

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
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          subtitle,
          style: AppTypography.body(
            size: 14.5,
            color: AppColors.textMuted(0.55),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
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
    padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 2),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.body(
        size: 12,
        weight: FontWeight.w800,
        letterSpacing: 1.2,
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
    // An unread alert that still needs a decision gets the full treatment —
    // solid glyph, tinted ground, matching outline. Once read it settles back
    // to a plain white card like everything else.
    final isUrgent = !item.isRead && item.kind.needsAction;
    final isLive = !item.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: switch ((isLive, isUrgent)) {
          (_, true) => tint.withValues(alpha: 0.10),
          (true, _) => AppColors.accent100,
          _ => AppColors.surface,
        },
        borderColor: isLive ? tint.withValues(alpha: 0.45) : null,
        onTap: () {
          ref.read(notificationsProvider.notifier).markRead(item.id);
          final link = item.deepLink;
          if (link == null) return;
          // A tab root is switched to, not stacked on top of this screen.
          if (AppRoutes.isShellTab(link)) {
            context.go(link);
          } else {
            context.push(link);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Solid while it is live, so the urgent ones read from across
                // the room; pale once handled.
                color: isLive ? tint : tint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 27, color: isLive ? Colors.white : tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.heading(size: 16, height: 1.25),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.body,
                    style: AppTypography.body(
                      size: 13.5,
                      color: AppColors.textMuted(0.65),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    Formatters.relative(item.createdAt),
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.textMuted(0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (isLive)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 8, left: 6),
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
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
      Icons.receipt_long_rounded,
      AppColors.accent,
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
      Icons.warning_amber_rounded,
      AppColors.warning,
    ),
    NotificationKind.complaint => (
      Icons.error_outline_rounded,
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
