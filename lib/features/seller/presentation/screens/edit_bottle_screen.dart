import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/back_disc_button.dart';
import '../../../../shared/widgets/photo_placeholder.dart';
import '../../../../shared/widgets/quantity_stepper.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../../shared/widgets/toggle_panel.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../providers/seller_providers.dart';

/// Edit one bottle: its name, size, both prices, the deposit, and stock.
///
/// The same screen adds a bottle: routing here with [newBottleId] seeds a
/// blank draft rather than loading one off the shelf.
class EditBottleScreen extends ConsumerStatefulWidget {
  const EditBottleScreen({super.key, required this.bottleId});

  /// The `bottleId` that means "this one doesn't exist yet".
  static const newBottleId = 'new';

  final String bottleId;

  bool get isNew => bottleId == newBottleId;

  @override
  ConsumerState<EditBottleScreen> createState() => _EditBottleScreenState();
}

class _EditBottleScreenState extends ConsumerState<EditBottleScreen> {
  final _nameController = TextEditingController();
  final _refillController = TextEditingController();
  final _newController = TextEditingController();
  final _depositController = TextEditingController();

  BottleSize _size = BottleSize.twentyFive;
  int _stock = 0;
  bool _isVisible = true;
  bool _seeded = false;
  bool _saving = false;

  /// A size outside the three we trade in. Not on [Bottle], which only models
  /// the sizes we price — so it stays local until the team sets one up.
  bool _isOtherSize = false;

  /// Held across rebuilds in add mode so the generated id stays stable.
  Bottle? _draft;

  @override
  void dispose() {
    _nameController.dispose();
    _refillController.dispose();
    _newController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  void _seed(Bottle bottle) {
    if (_seeded) return;
    _nameController.text = bottle.name;
    _refillController.text = '${bottle.refillPrice}';
    _newController.text = '${bottle.newPrice}';
    _depositController.text = '${bottle.deposit}';
    _size = bottle.size;
    _stock = bottle.filledStock;
    _isVisible = bottle.isVisible;
    _seeded = true;
  }

  Future<void> _save(Bottle original) async {
    setState(() => _saving = true);

    final result = await ref
        .read(sellerInventoryProvider.notifier)
        .save(
          original.copyWith(
            name: _nameController.text.trim(),
            size: _size,
            refillPrice: int.tryParse(_refillController.text) ?? 0,
            newPrice: int.tryParse(_newController.text) ?? 0,
            deposit: int.tryParse(_depositController.text) ?? 0,
            filledStock: _stock,
            isVisible: _isVisible,
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isNew ? 'Bottle added.' : 'Bottle updated.'),
          ),
        );
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _confirmDelete(Bottle bottle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this bottle?'),
        content: Text(
          '${bottle.name} will be removed from your shelf. Hiding it instead '
          'keeps the prices and stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(sellerInventoryProvider.notifier)
        .delete(bottle.id);
    if (!mounted) return;

    result.when(
      success: (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bottle deleted.')));
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  /// The draft a new bottle starts from — no prices, hidden until the seller
  /// has filled it in and saved.
  Bottle _blankDraft() => Bottle(
    id: 'b-${DateTime.now().millisecondsSinceEpoch}',
    sellerId:
        ref.read(sellerInventoryProvider).value?.firstOrNull?.sellerId ?? '',
    size: BottleSize.twentyFive,
    name: '',
    refillPrice: 0,
    newPrice: 0,
    isVisible: false,
  );

  @override
  Widget build(BuildContext context) {
    final bottle = widget.isNew
        ? (_draft ??= _blankDraft())
        : ref.watch(bottleByIdProvider(widget.bottleId));

    if (bottle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _seed(bottle);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        titleSpacing: AppSpacing.gutter,
        title: Row(
          children: [
            const BackDiscButton(),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                widget.isNew ? 'Add bottle' : 'Edit bottle',
                style: AppTypography.heading(size: 26),
              ),
            ),
          ],
        ),
        actions: [
          // Nothing to delete until the bottle has been saved once.
          if (!widget.isNew)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.gutter),
              child: _CircleIconButton(
                icon: Icons.delete_outline_rounded,
                background: AppColors.dangerBg,
                foreground: AppColors.danger,
                onTap: () => _confirmDelete(bottle),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          // ── Photo and name ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PhotoPlaceholder(
                label: 'bottle\nphoto',
                width: 110,
                height: 140,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Bottle name'),
                    TextField(
                      controller: _nameController,
                      style: AppTypography.body(
                        size: 16.5,
                        weight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '25L Cooler Bottle',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.lg,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.8,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.neutral300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                      ),
                      child: const Text('Replace photo'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('Size'),
          Row(
            children: [
              for (final size in BottleSize.values) ...[
                Expanded(
                  child: _SizePill(
                    label: size.label,
                    selected: !_isOtherSize && _size == size,
                    onTap: () => setState(() {
                      _size = size;
                      _isOtherSize = false;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              // A size outside the three we trade in — priced with the team,
              // so it only records intent here.
              Expanded(
                child: _SizePill(
                  label: 'Other',
                  selected: _isOtherSize,
                  onTap: () => setState(() => _isOtherSize = true),
                ),
              ),
            ],
          ),
          if (_isOtherSize) ...[
            const SizedBox(height: AppSpacing.md),
            const AppNote(
              text: 'Our team will call to agree pricing for other sizes.',
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('Prices'),
          Row(
            children: [
              Expanded(
                child: _MoneyField(
                  label: 'Refill',
                  controller: _refillController,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MoneyField(
                  label: 'New bottle',
                  controller: _newController,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MoneyField(
                  label: 'Deposit',
                  controller: _depositController,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Customers see both prices side by side and pick one.',
            style: AppTypography.body(
              size: 15,
              color: AppColors.textMuted(0.55),
            ),
          ),

          // ── Stock ───────────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filled in stock',
                        style: AppTypography.heading(size: 16),
                      ),
                      if (bottle.emptiesInYard > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${bottle.emptiesInYard} empties waiting in the yard',
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.textMuted(0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                QuantityStepper(
                  quantity: _stock,
                  large: true,
                  onIncrement: () => setState(() => _stock++),
                  onDecrement: () => setState(() => _stock--),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          // Tinted, with the switch leading — this is a state the seller reads
          // at a glance rather than a field they fill in.
          TogglePanel(
            title: 'Showing to customers',
            subtitle: 'Turn off to hide without deleting',
            value: _isVisible,
            onChanged: (v) => setState(() => _isVisible = v),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _saving
            ? 'Saving…'
            : widget.isNew
            ? 'Add bottle'
            : 'Save changes',
        enabled: !_saving,
        onPressed: () => _save(bottle),
      ),
    );
  }
}

/// The round delete bin in the header, matching [BackDiscButton]'s disc.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.background = AppColors.surface,
    this.foreground = AppColors.text,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: foreground, size: 20),
      ),
    ),
  );
}

/// One of the four size choices — bigger than [ChoiceTag], which is sized for
/// dense filter rows.
class _SizePill extends StatelessWidget {
  const _SizePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.accent : AppColors.surface,
    shape: const StadiumBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body(
            size: 16,
            weight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted(0.75),
          ),
        ),
      ),
    ),
  );
}

/// A price on a white card: small `Rs`, large value, tap anywhere to edit.
class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body(size: 12, color: AppColors.textMuted(0.55)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Rs',
              style: AppTypography.body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.textMuted(0.55),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.heading(size: 23),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
