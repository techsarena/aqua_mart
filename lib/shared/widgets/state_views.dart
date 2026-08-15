import 'package:flutter/material.dart';

import '../../core/error/failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Shimmerless skeleton block — a calm placeholder while data loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppRadius.sm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_controller),
    child: Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Card-shaped skeleton used in every list while the first page loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 3, this.itemHeight = 84});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    child: Column(
      children: List.generate(
        itemCount,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: SkeletonBox(height: itemHeight, radius: AppRadius.lg),
        ),
      ),
    ),
  );
}

/// Full-screen (or in-list) failure state with a retry affordance.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      AuthFailure() => Icons.lock_outline_rounded,
      _ => Icons.error_outline_rounded,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.neutral400),
            const SizedBox(height: AppSpacing.lg),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 14,
                color: AppColors.textMuted(0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(140, 44),
                ),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state with an illustration slot, title, body and up to two actions.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.footer,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.heading(size: 22),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            size: 14,
            color: AppColors.textMuted(0.65),
            height: 1.5,
          ),
        ),
        if (primaryLabel != null) ...[
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
        ],
        if (secondaryLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
        if (footer != null) ...[const SizedBox(height: AppSpacing.xl), footer!],
      ],
    ),
  );
}
