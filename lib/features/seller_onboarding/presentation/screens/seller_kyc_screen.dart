import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/widgets/onboarding_scaffold.dart';
import '../providers/seller_onboarding_providers.dart';

/// Seller sign-up 2 of 4 — proof of identity and water quality.
///
/// Photos are enough; no scanner needed. The privacy promise sits right under
/// the uploads because that is where the hesitation is.
class SellerKycScreen extends ConsumerWidget {
  const SellerKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(sellerApplicationProvider);

    return OnboardingScaffold(
      step: 2,
      totalSteps: 4,
      title: "Prove it's you",
      subtitle: 'Photos are fine — no scanner needed. We check within a day.',
      primaryLabel: 'Continue',
      primaryEnabled: application.documentsComplete,
      onPrimary: () => context.pushNamed(AppRoutes.sellerCatalogSetup),
      footer: const AppNote(
        icon: Icons.lock_outline_rounded,
        text:
            'Documents are seen only by our verification team. Customers '
            'never see them.',
      ),
      child: Column(
        children: [
          for (final document in KycDocument.values) ...[
            _UploadTile(
              document: document,
              uploaded: application.uploaded.contains(document),
              onTap: () => ref
                  .read(sellerApplicationProvider.notifier)
                  .toggleDocument(document),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.document,
    required this.uploaded,
    required this.onTap,
  });

  final KycDocument document;
  final bool uploaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.md),
    borderColor: uploaded ? AppColors.accent2 : null,
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: uploaded ? AppColors.accent2_100 : AppColors.neutral100,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            uploaded ? Icons.check_rounded : Icons.photo_camera_outlined,
            size: 20,
            color: uploaded ? AppColors.accent2_700 : AppColors.textMuted(0.5),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      document.label,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (document.isRequired && !uploaded) ...[
                    const SizedBox(width: 5),
                    Text(
                      '*',
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                uploaded ? 'Uploaded' : document.hint,
                style: AppTypography.body(
                  size: 12.5,
                  color: uploaded
                      ? AppColors.accent2_700
                      : AppColors.textMuted(0.55),
                ),
              ),
            ],
          ),
        ),
        Icon(
          uploaded ? Icons.edit_outlined : Icons.add_rounded,
          size: 19,
          color: AppColors.textMuted(0.45),
        ),
      ],
    ),
  );
}
