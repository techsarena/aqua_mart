import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/rider_run.dart';
import '../providers/rider_providers.dart';

/// The rider's run: the next stop large and actionable, the rest queued below.
class RiderRunScreen extends ConsumerWidget {
  const RiderRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderRunProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (async) {
          AsyncLoading() => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xl),
            child: SkeletonList(itemCount: 3, itemHeight: 130),
          ),
          AsyncError(:final error) => ErrorView(
            failure: asFailure(error),
            onRetry: () => ref.invalidate(riderRunProvider),
          ),
          AsyncValue(value: final run) when run != null => _RunView(run: run),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _RunView extends ConsumerWidget {
  const _RunView({required this.run});

  final RiderRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = run.nextStop;
    final upcoming = run.pending.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        // ── Run header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(run.label, style: AppTypography.heading(size: 26)),
                    const SizedBox(height: 2),
                    Text(
                      run.isComplete
                          ? 'All stops done'
                          : '${run.pending.length} stops left',
                      style: AppTypography.body(
                        size: 13.5,
                        color: AppColors.textMuted(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupees(run.cashOutstanding),
                    style: AppTypography.heading(size: 22),
                  ),
                  Text(
                    'cash to collect',
                    style: AppTypography.body(
                      size: 11.5,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── The next stop, in full ──────────────────────────────────────
        if (next != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: _NextStopCard(
              stop: next,
              onDelivered: () =>
                  ref.read(riderRunProvider.notifier).completeStop(next.id),
              onFailed: () => _reportProblem(context, ref, next.id),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: AppCard(
              color: AppColors.accent2_100,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 26,
                    color: AppColors.accent2_700,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Run finished',
                          style: AppTypography.heading(
                            size: 19,
                            color: AppColors.accent2_700,
                          ),
                        ),
                        Text(
                          '${run.delivered.length} delivered · hand in '
                          '${Formatters.rupees(run.cashCollected)}',
                          style: AppTypography.body(
                            size: 12.5,
                            color: AppColors.accent2_700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── The rest of the run ─────────────────────────────────────────
        if (upcoming.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xl,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Text('Then', style: AppTypography.heading(size: 20)),
          ),
          for (var i = 0; i < upcoming.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: _QueuedStopRow(stop: upcoming[i], position: i + 2),
            ),
        ],

        // ── Already done ────────────────────────────────────────────────
        if (run.delivered.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xl,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Text(
              'Delivered · ${run.delivered.length}',
              style: AppTypography.heading(size: 20),
            ),
          ),
          for (final stop in run.delivered)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: AppColors.accent2,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${stop.customerName} · ${stop.items}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 13.5,
                          color: AppColors.textMuted(0.7),
                        ),
                      ),
                    ),
                    if (stop.completedAt != null)
                      Text(
                        Formatters.time(stop.completedAt!),
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.textMuted(0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _reportProblem(
    BuildContext context,
    WidgetRef ref,
    String stopId,
  ) async {
    const reasons = [
      'Nobody answered',
      'Customer refused delivery',
      'Address not found',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('What happened?', style: AppTypography.heading(size: 20)),
            const SizedBox(height: AppSpacing.sm),
            for (final reason in reasons)
              ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (reason != null) {
      await ref.read(riderRunProvider.notifier).failStop(stopId, reason);
    }
  }
}

class _NextStopCard extends StatelessWidget {
  const _NextStopCard({
    required this.stop,
    required this.onDelivered,
    required this.onFailed,
  });

  final RunStop stop;
  final VoidCallback onDelivered;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) => AppCard(
    elevated: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppTag(
              'Next stop · ${Formatters.distance(stop.distanceMetres)}',
              tone: TagTone.accent,
              icon: Icons.navigation_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(stop.address, style: AppTypography.heading(size: 22)),
        const SizedBox(height: 3),
        Text(
          '${stop.customerName} · ${stop.items}',
          style: AppTypography.body(
            size: 13.5,
            color: AppColors.textMuted(0.6),
          ),
        ),

        // What to collect is the thing the rider must not get wrong.
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: stop.isCash ? AppColors.accent100 : AppColors.neutral100,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                stop.isCash
                    ? Icons.payments_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20,
                color: stop.isCash
                    ? AppColors.accent700
                    : AppColors.textMuted(0.5),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.isCash ? 'Collect' : 'Already paid',
                      style: AppTypography.body(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: stop.isCash
                            ? AppColors.accent700
                            : AppColors.textMuted(0.55),
                      ),
                    ),
                    Text(
                      stop.collectionLine,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: const Text('Navigate'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: () {},
              icon: const Icon(Icons.call_rounded, size: 19),
              style: IconButton.styleFrom(
                minimumSize: const Size(52, 52),
                backgroundColor: AppColors.accent100,
                foregroundColor: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: onDelivered,
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent2),
          child: Text(stop.isCash ? 'Delivered · cash taken' : 'Delivered'),
        ),
        TextButton(
          onPressed: onFailed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted(0.7),
          ),
          child: const Text("Couldn't deliver"),
        ),
      ],
    ),
  );
}

class _QueuedStopRow extends StatelessWidget {
  const _QueuedStopRow({required this.stop, required this.position});

  final RunStop stop;
  final int position;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.neutral200,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$position',
            style: AppTypography.body(
              size: 12.5,
              weight: FontWeight.w800,
              color: AppColors.textMuted(0.6),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stop.customerName} · ${stop.address}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${stop.items} · ${stop.collectionLine}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 12.5,
                  color: AppColors.textMuted(0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          Formatters.distance(stop.distanceMetres),
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.textMuted(0.5),
          ),
        ),
      ],
    ),
  );
}
