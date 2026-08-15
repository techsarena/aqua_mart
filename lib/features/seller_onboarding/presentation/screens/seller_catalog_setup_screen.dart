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
      onPrimary: () {
        notifier.submit();
        context.goNamed(AppRoutes.sellerVerification);
      },
      footer: application.bottles.isEmpty
          ? null
          : Text(
              '${application.bottles.length} '
              '${application.bottles.length == 1 ? 'size' : 'sizes'} selected · '
              'next: your delivery area',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 12.5,
                color: AppColors.textMuted(0.55),
              ),
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
              onRefillChanged: (v) =>
                  notifier.setPrice(size, refillPrice: v),
              onNewChanged: (v) => notifier.setPrice(size, newPrice: v),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
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
    borderColor: _selected ? AppColors.accent : null,
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selected
                      ? AppColors.accent100
                      : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  size.label,
                  style: AppTypography.body(
                    size: 12.5,
                    weight: FontWeight.w800,
                    color: _selected
                        ? AppColors.accent700
                        : AppColors.textMuted(0.55),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '${size.litres} L ${size == BottleSize.twentyFive ? 'cooler bottle' : 'bottle'}',
                  style: AppTypography.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Checkbox.adaptive(
                value: _selected,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),

        // Prices only appear once the size is taken — the form stays short.
        if (_selected) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(
                child: _PriceField(
                  label: 'Refill',
                  value: draft!.refillPrice,
                  onChanged: onRefillChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _PriceField(
                  label: 'New bottle',
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: AppTypography.body(
          size: 11.5,
          weight: FontWeight.w600,
          color: AppColors.textMuted(0.6),
        ),
      ),
      const SizedBox(height: 5),
      TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0),
        decoration: const InputDecoration(
          prefixText: 'Rs ',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
        ),
      ),
    ],
  );
}
