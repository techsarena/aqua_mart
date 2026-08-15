import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/map_placeholder.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
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

    final saved = await ref
        .read(addressBookProvider.notifier)
        .save(address);

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
      appBar: AppBar(
        title: Text(widget.addressId == null ? 'Drag to your gate' : 'Edit address'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: MapPlaceholder(
              height: 220,
              showCentrePin: true,
              caption: 'drag the map to move the pin',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  area,
                  style: AppTypography.body(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),

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
                const FieldLabel('Save as'),
                Row(
                  children: [
                    for (final label in AddressLabel.values) ...[
                      Expanded(
                        child: ChoiceTag(
                          label: label.text,
                          selected: _label == label,
                          onTap: () => setState(() => _label = label),
                        ),
                      ),
                      if (label != AddressLabel.values.last)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),
                const FieldLabel('House / flat number'),
                TextField(
                  controller: _houseController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '42-B'),
                ),

                const SizedBox(height: AppSpacing.xl),
                const FieldLabel('Note for the rider — optional'),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Near Hafeez Centre. Ring the bell twice — gate is on '
                        'the side street.',
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                SwitchListTile.adaptive(
                  value: _makeDefault,
                  onChanged: (v) => setState(() => _makeDefault = v),
                  title: Text(
                    'Make this my default',
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.accent2,
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
}
