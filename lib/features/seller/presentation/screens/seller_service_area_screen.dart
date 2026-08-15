import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/map_placeholder.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';

/// Where the seller delivers: a radius on the map plus named areas.
class SellerServiceAreaScreen extends ConsumerStatefulWidget {
  const SellerServiceAreaScreen({super.key});

  @override
  ConsumerState<SellerServiceAreaScreen> createState() =>
      _SellerServiceAreaScreenState();
}

class _SellerServiceAreaScreenState
    extends ConsumerState<SellerServiceAreaScreen> {
  double _radiusKm = 4;
  final _areas = <String>['Gulberg III', 'Model Town', 'Garden Town'];

  /// Rough households covered, so the radius means something concrete.
  int get _homesCovered => (_radiusKm * _radiusKm * 120).round();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Where you deliver')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        MapPlaceholder(
          height: 240,
          caption: 'drag to move · pinch to resize radius',
          overlay: Center(
            child: Container(
              width: 40 + _radiusKm * 26,
              height: 40 + _radiusKm * 26,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_radiusKm.toStringAsFixed(0)} km radius',
                    style: AppTypography.heading(size: 20),
                  ),
                  const Spacer(),
                  Text(
                    '~${_homesCovered.toString()} homes',
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.textMuted(0.6),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radiusKm,
                min: 1,
                max: 12,
                divisions: 11,
                activeColor: AppColors.accent,
                onChanged: (v) => setState(() => _radiusKm = v),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        const FieldLabel('Areas you cover'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final area in _areas)
              Chip(
                label: Text(area),
                onDeleted: () => setState(() => _areas.remove(area)),
                deleteIcon: const Icon(Icons.close_rounded, size: 15),
                backgroundColor: AppColors.accent100,
                side: BorderSide.none,
                labelStyle: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.accent700,
                ),
              ),
            ActionChip(
              label: const Text('+ Add area'),
              onPressed: () => _addArea(context),
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: AppColors.divider),
              labelStyle: AppTypography.body(
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
    bottomNavigationBar: StickyActionBar(
      label: 'Save service area',
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service area saved.')),
      ),
    ),
  );

  Future<void> _addArea(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Johar Town'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null && name.isNotEmpty && !_areas.contains(name)) {
      setState(() => _areas.add(name));
    }
  }
}
