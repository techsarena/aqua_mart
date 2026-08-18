import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../../../catalog/domain/entities/bottle.dart';
import '../providers/seller_onboarding_providers.dart';

/// Seller sign-up 3 of 4 — pick sizes and set two prices each.
class SellerCatalogSetupScreen extends ConsumerWidget {
  const SellerCatalogSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(sellerApplicationProvider);
    final notifier = ref.read(sellerApplicationProvider.notifier);

    return OnboardingScaffold(
      step: 3,
      totalSteps: 4,
      title: 'What do you sell?',
      subtitle:
          'Pick your sizes and set two prices each. Change them any time.',
      primaryLabel: 'Continue',
      primaryEnabled: application.catalogComplete,
      onPrimary: () async {
        // The waiting room reflects a real server status, so navigation waits
        // for the submission rather than assuming it worked.
        final result = await notifier.submit();
        if (!context.mounted) return;

        result.when(
          success: (_) => context.goNamed(AppRoutes.sellerVerification),
          failure: (f) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(f.message))),
        );
      },
      // The count on the left, what comes next on the right — the design
      // uses the width rather than stacking the two.
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${application.bottles.length} '
            '${application.bottles.length == 1 ? 'size' : 'sizes'} selected',
            style: AppTypography.body(
              size: 13.5,
              color: AppColors.textMuted(0.55),
            ),
          ),
          Text(
            'Next: your delivery area',
            style: AppTypography.body(
              size: 13.5,
              color: AppColors.textMuted(0.55),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          for (final size in BottleSize.values.reversed) ...[
            _SizeCard(
              size: size,
              draft: application.bottles
                  .where((b) => b.size == size)
                  .firstOrNull,
              onToggle: () => notifier.toggleSize(size),
              onRefillChanged: (v) => notifier.setPrice(size, refillPrice: v),
              onNewChanged: (v) => notifier.setPrice(size, newPrice: v),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Not a size we trade in — recorded for the verification team to
          // follow up, so it carries no prices.
          _OtherSizesCard(
            selected: application.sellsOtherSizes,
            onToggle: notifier.toggleOtherSizes,
          ),
        ],
      ),
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.size,
    required this.draft,
    required this.onToggle,
    required this.onRefillChanged,
    required this.onNewChanged,
  });

  final BottleSize size;
  final DraftBottle? draft;
  final VoidCallback onToggle;
  final ValueChanged<int> onRefillChanged;
  final ValueChanged<int> onNewChanged;

  bool get _selected => draft != null;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onToggle,
    padding: const EdgeInsets.all(AppSpacing.md),
    color: _selected ? AppColors.accent100 : AppColors.surface,
    borderColor: _selected ? AppColors.accent : null,
    child: Column(
      children: [
        Row(
          children: [
            _SelectionTick(selected: _selected),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '${size.litres} L '
                '${size == BottleSize.twentyFive ? 'cooler bottle' : 'bottle'}',
                style: AppTypography.body(
                  size: 16,
                  weight: FontWeight.w700,
                  color: _selected ? AppColors.text : AppColors.textMuted(0.75),
                ),
              ),
            ),
          ],
        ),

        // Prices only appear once the size is taken — the form stays short.
        if (_selected) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PriceField(
                  label: 'Refill',
                  value: draft!.refillPrice,
                  onChanged: onRefillChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PriceField(
                  label: 'New',
                  value: draft!.newPrice,
                  onChanged: onNewChanged,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// The round tick that carries selection on every card in this step.
class _SelectionTick extends StatelessWidget {
  const _SelectionTick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected ? AppColors.accent : Colors.transparent,
      shape: BoxShape.circle,
      border: selected
          ? null
          : Border.all(color: AppColors.textMuted(0.25), width: 1.8),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
        : null,
  );
}

/// "Something else" — selectable, but priced later with our team.
class _OtherSizesCard extends StatelessWidget {
  const _OtherSizesCard({required this.selected, required this.onToggle});

  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onToggle,
    padding: const EdgeInsets.all(AppSpacing.md),
    color: selected ? AppColors.accent100 : AppColors.surface,
    borderColor: selected ? AppColors.accent : null,
    child: Row(
      children: [
        _SelectionTick(selected: selected),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Something else',
            style: AppTypography.body(
              size: 16,
              weight: FontWeight.w700,
              color: selected ? AppColors.text : AppColors.textMuted(0.75),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PriceField extends StatefulWidget {
  const _PriceField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late final _controller = TextEditingController(
    text: widget.value > 0 ? '${widget.value}' : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.body(
            size: 13,
            color: AppColors.textMuted(0.55),
          ),
        ),
        const SizedBox(height: 2),
        // The panel is the field's frame, so the input itself is bare —
        // a bordered box inside a white card would read as a second edge.
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
          style: AppTypography.heading(size: 21),
          decoration: InputDecoration(
            prefixText: 'Rs ',
            prefixStyle: AppTypography.heading(size: 21),
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ],
    ),
  );
}
