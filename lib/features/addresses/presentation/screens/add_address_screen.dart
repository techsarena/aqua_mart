import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/map_placeholder.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../../shared/widgets/toggle_panel.dart';
import '../../domain/entities/address.dart';
import '../providers/address_providers.dart';

/// Drop a pin, label it, and note anything the rider needs to find the gate.
///
/// Doubles as the edit screen when an [addressId] is passed.
class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key, this.addressId});

  final String? addressId;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _houseController = TextEditingController();
  final _noteController = TextEditingController();
  AddressLabel _label = AddressLabel.home;
  bool _makeDefault = false;
  bool _saving = false;
  bool _seeded = false;

  Address? get _editing {
    final id = widget.addressId;
    if (id == null) return null;
    final addresses = ref.read(addressBookProvider).value ?? const [];
    return addresses.where((a) => a.id == id).firstOrNull;
  }

  @override
  void dispose() {
    _houseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Fills the form from the address being edited, once its data has loaded.
  void _seedIfNeeded() {
    if (_seeded) return;
    final existing = _editing;
    if (existing == null) return;

    _houseController.text = existing.houseNumber;
    _noteController.text = existing.riderNote;
    _label = existing.label;
    _makeDefault = existing.isDefault;
    _seeded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final existing = _editing;

    final address = Address(
      id: existing?.id ?? '',
      label: _label,
      title: _label.text,
      area: existing?.area ?? 'Gulberg III, Lahore',
      houseNumber: _houseController.text.trim(),
      riderNote: _noteController.text.trim(),
      latitude: existing?.latitude ?? 31.5204,
      longitude: existing?.longitude ?? 74.3587,
      isDefault: _makeDefault,
    );

    final saved = await ref.read(addressBookProvider.notifier).save(address);

    if (!mounted) return;
    setState(() => _saving = false);

    if (saved != null) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That address couldn't be saved.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the seed runs once the address book resolves.
    ref.watch(addressBookProvider);
    _seedIfNeeded();

    final area = _editing?.area ?? 'Gulberg III, Lahore';

    return Scaffold(
      // The map runs to the edges with the controls floating on it, so the
      // pin has as much room as the screen can give.
      body: Column(
        children: [
          _MapPane(
            area: area,
            hint: widget.addressId == null
                ? 'Drag to your gate'
                : 'Edit address',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                const FieldLabel('SAVE AS'),
                Row(
                  children: [
                    for (final label in AddressLabel.values) ...[
                      Expanded(
                        child: _LabelChoice(
                          label: label,
                          selected: _label == label,
                          onTap: () => setState(() => _label = label),
                        ),
                      ),
                      if (label != AddressLabel.values.last)
                        const SizedBox(width: AppSpacing.md),
                    ],
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),
                const FieldLabel('HOUSE / FLAT NUMBER'),
                TextField(
                  controller: _houseController,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.body(size: 19, weight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: '42-B'),
                ),

                const SizedBox(height: AppSpacing.xl),
                const FieldLabel('NOTE FOR THE RIDER — OPTIONAL'),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: AppTypography.body(size: 17),
                  decoration: InputDecoration(
                    // Square-ish rather than pill: a three-line box cannot
                    // carry a full pill without the text fouling the curve.
                    border: _noteBorder(AppColors.divider),
                    enabledBorder: _noteBorder(AppColors.divider),
                    focusedBorder: _noteBorder(AppColors.accent, width: 1.5),
                    hintText:
                        'Near Hafeez Centre. Ring the bell twice — gate is on '
                        'the side street.',
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                TogglePanel(
                  title: 'Make this my default',
                  value: _makeDefault,
                  onChanged: (v) => setState(() => _makeDefault = v),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _saving ? 'Saving…' : 'Save address',
        enabled: !_saving && _houseController.text.trim().isNotEmpty,
        onPressed: _save,
      ),
    );
  }

  /// The rider note is the one multi-line field in the app, so it gets its
  /// own softer-cornered box instead of the themed pill.
  OutlineInputBorder _noteBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// The map, with the back button and the area search floating over it.
class _MapPane extends StatelessWidget {
  const _MapPane({required this.area, required this.hint});

  final String area;

  /// What the pin is for — "Drag to your gate" while placing a new address.
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.34,
    child: Stack(
      children: [
        Positioned.fill(
          child: MapPlaceholder(radius: 0, showCentrePin: true, height: null),
        ),
        Positioned(
          left: AppSpacing.gutter,
          right: AppSpacing.gutter,
          top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
          child: Row(
            children: [
              const BackDiscButton(),
              const SizedBox(width: AppSpacing.md),
              // The area, presented as a search field — the pin is placed by
              // dragging, but the area is how you get to the right part of town.
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: AppColors.textMuted(0.5),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          area,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(size: 17),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Sits just above the pin, telling you what the drag is for.
        Align(
          alignment: const Alignment(0, -0.16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.text.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              hint,
              style: AppTypography.body(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// One of Home / Office / Other — an icon over its name, in a card that
/// tints and outlines when chosen.
class _LabelChoice extends StatelessWidget {
  const _LabelChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
    AddressLabel.home => Icons.home_outlined,
    AddressLabel.office => Icons.business_outlined,
    AddressLabel.other => Icons.location_on_outlined,
  };

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.onTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 22,
              color: selected ? AppColors.accent : AppColors.textMuted(0.7),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label.text,
              style: AppTypography.heading(
                size: 14,
                color: selected ? AppColors.text : AppColors.textMuted(0.8),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
