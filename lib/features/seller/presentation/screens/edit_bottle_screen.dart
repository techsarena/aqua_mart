import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/quantity_stepper.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../providers/seller_providers.dart';

/// Edit one bottle: its name, size, both prices, the deposit, and stock.
class EditBottleScreen extends ConsumerStatefulWidget {
  const EditBottleScreen({super.key, required this.bottleId});

  final String bottleId;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bottle updated.')));
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottle = ref.watch(bottleByIdProvider(widget.bottleId));

    if (bottle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _seed(bottle);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit bottle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          // ── Photo ───────────────────────────────────────────────────────
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 30,
                    color: AppColors.accent300,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bottle photo',
                        style: AppTypography.body(
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shown to customers on your store page',
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.textMuted(0.55),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                        ),
                        child: const Text('Replace photo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('Bottle name'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: '25L Cooler Bottle'),
          ),

          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('Size'),
          Row(
            children: [
              for (final size in BottleSize.values) ...[
                Expanded(
                  child: ChoiceTag(
                    label: size.label,
                    selected: _size == size,
                    onTap: () => setState(() => _size = size),
                  ),
                ),
                if (size != BottleSize.values.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),

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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MoneyField(
                  label: 'New bottle',
                  controller: _newController,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MoneyField(
                  label: 'Deposit',
                  controller: _depositController,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Customers see both prices side by side and pick one.',
            style: AppTypography.body(
              size: 12,
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
                        style: AppTypography.body(
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (bottle.emptiesInYard > 0)
                        Text(
                          '${bottle.emptiesInYard} empties waiting in the yard',
                          style: AppTypography.body(
                            size: 12,
                            color: AppColors.textMuted(0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                QuantityStepper(
                  quantity: _stock,
                  onIncrement: () => setState(() => _stock++),
                  onDecrement: () => setState(() => _stock--),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showing to customers',
                        style: AppTypography.body(
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Turn off to hide without deleting',
                        style: AppTypography.body(
                          size: 12,
                          color: AppColors.textMuted(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isVisible,
                  onChanged: (v) => setState(() => _isVisible = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete this bottle'),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _saving ? 'Saving…' : 'Save changes',
        enabled: !_saving,
        onPressed: () => _save(bottle),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.body(
          size: 11.5,
          weight: FontWeight.w600,
          color: AppColors.textMuted(0.6),
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          prefixText: 'Rs ',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
        ),
      ),
    ],
  );
}
