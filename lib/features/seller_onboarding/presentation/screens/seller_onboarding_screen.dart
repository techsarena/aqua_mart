import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../../../catalog/domain/entities/seller.dart';
import '../providers/seller_onboarding_providers.dart';

/// Seller sign-up 1 of 4 — the business, as customers will see it.
class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() =>
      _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState
    extends ConsumerState<SellerOnboardingScreen> {
  late final _businessController = TextEditingController(
    text: ref.read(sellerApplicationProvider).businessName,
  );
  late final _ownerController = TextEditingController(
    text: ref.read(sellerApplicationProvider).ownerName,
  );

  @override
  void dispose() {
    _businessController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = ref.watch(sellerApplicationProvider);

    return OnboardingScaffold(
      step: 1,
      totalSteps: 4,
      title: 'Your water business',
      subtitle: 'This is the name customers will see.',
      primaryLabel: 'Continue',
      primaryEnabled: application.detailsComplete,
      // Registering here (rather than at the end) is what creates the seller
      // profile every later step needs: /seller/documents and
      // /seller/verification both 403 without one.
      onPrimary: () async {
        final result = await ref
            .read(sellerApplicationProvider.notifier)
            .register();
        if (!context.mounted) return;

        result.when(
          success: (_) => context.pushNamed(AppRoutes.sellerKyc),
          failure: (f) => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(f.message))),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Business name'),
          TextField(
            controller: _businessController,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => ref
                .read(sellerApplicationProvider.notifier)
                .setDetails(businessName: v),
            decoration: const InputDecoration(hintText: 'Chashma Pure Water'),
          ),

          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('Owner name'),
          TextField(
            controller: _ownerController,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => ref
                .read(sellerApplicationProvider.notifier)
                .setDetails(ownerName: v),
            decoration: const InputDecoration(hintText: 'Full name as on CNIC'),
          ),

          const SizedBox(height: AppSpacing.xl),
          const FieldLabel('What do you run?'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final type in SellerBusinessType.values)
                ChoiceTag(
                  label: type.label,
                  selected: application.businessType == type,
                  onTap: () => ref
                      .read(sellerApplicationProvider.notifier)
                      .setDetails(businessType: type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
