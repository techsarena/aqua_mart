import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/segmented_switch.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/rider_run.dart';
import '../providers/rider_providers.dart';
import '../widgets/run_map_view.dart';

/// The rider's run, as a list or as a map.
///
/// The list is the working view — the next stop large and actionable, the
/// rest queued below. The map answers the other question a rider has: where
/// the whole run goes, and in what order.
class RiderRunScreen extends ConsumerStatefulWidget {
  const RiderRunScreen({super.key});

  @override
  ConsumerState<RiderRunScreen> createState() => _RiderRunScreenState();
}

class _RiderRunScreenState extends ConsumerState<RiderRunScreen> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
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
          AsyncValue(value: final run) when run != null =>
            _showMap
                ? _MapTab(
                    run: run,
                    onShowList: () => setState(() => _showMap = false),
                  )
                : _RunView(
                    run: run,
                    onShowMap: () => setState(() => _showMap = true),
                  ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// The map view, with the switch floating over it.
class _MapTab extends StatelessWidget {
  const _MapTab({required this.run, required this.onShowList});

  final RiderRun run;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // The switch is 50 high plus its own top margin, so the map's summary
      // starts below it.
      RunMapView(
        run: run,
        onNavigate: () {},
        onCall: () {},
        topInset: 58,
      ),
      // The switch sits above the map's own summary pill, which is why the
      // map insets its content from the top.
      Positioned(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.sm,
        child: Row(
          children: [
            Expanded(
              child: SegmentedSwitch(
                labels: const ['List', 'Map'],
                icons: const [
                  Icons.format_list_bulleted_rounded,
                  Icons.place_rounded,
                ],
                selectedIndex: 1,
                onSelected: (i) {
                  if (i == 0) onShowList();
                },
                onDark: true,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Recentre — inert until the Maps SDK is wired in.
            Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: AppColors.text.withValues(alpha: 0.2),
              child: InkWell(
                onTap: () {},
                customBorder: const CircleBorder(),
                child: const SizedBox.square(
                  dimension: 50,
                  child: Icon(Icons.my_location_rounded, size: 21),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RunView extends ConsumerWidget {
  const _RunView({required this.run, required this.onShowMap});

  final RiderRun run;
  final VoidCallback onShowMap;

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

        // ── List / Map ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.lg,
          ),
          child: SegmentedSwitch(
            labels: const ['List', 'Map'],
            icons: const [
              Icons.format_list_bulleted_rounded,
              Icons.place_rounded,
            ],
            selectedIndex: 0,
            onSelected: (i) {
              if (i == 1) onShowMap();
            },
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

  /// "Collect Rs 220 cash · take back 2 empties", with the amount picked out
  /// of the line — it is the one part that must be read exactly right.
  InlineSpan get _collectionSpan {
    final bold = AppTypography.body(
      size: 15,
      weight: FontWeight.w800,
      color: Colors.white,
    );
    final plain = AppTypography.body(
      size: 15,
      color: Colors.white.withValues(alpha: 0.9),
    );

    if (!stop.isCash) {
      return TextSpan(text: stop.collectionLine, style: plain);
    }

    return TextSpan(
      style: plain,
      children: [
        const TextSpan(text: 'Collect '),
        TextSpan(text: 'Rs ${stop.amountToCollect} cash', style: bold),
        if (stop.emptiesToCollect > 0)
          TextSpan(text: ' · take back ${stop.emptiesToCollect} empties'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEXT STOP · ${Formatters.distance(stop.distanceMetres)}'
              .toUpperCase(),
          style: AppTypography.body(
            size: 12,
            weight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.75),
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          stop.address,
          style: AppTypography.heading(size: 24, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '${stop.customerName} · ${stop.items}',
          style: AppTypography.body(
            size: 14.5,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),

        // What to collect is the thing the rider must not get wrong, so it
        // sits in the card's own body rather than in a panel of its own.
        const SizedBox(height: AppSpacing.md),
        Text.rich(_collectionSpan),

        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accent,
                ),
                child: const Text('Navigate'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Outlined rather than filled, so the call sits under the
            // primary action without competing with it.
            SizedBox.square(
              dimension: 56,
              child: Material(
                color: Colors.transparent,
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: () {},
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.call_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
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
            foregroundColor: Colors.white.withValues(alpha: 0.85),
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
