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

    // The design calls out one tile at a time — the next required document
    // still missing — so the eye has a single obvious target.
    final nextRequired = KycDocument.values
        .where((d) => d.isRequired && !application.uploaded.contains(d))
        .firstOrNull;

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
              isNext: document == nextRequired,
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

/// One document row: a round badge, the document, and where it stands.
///
/// Three states, each carried by fill rather than by a trailing affordance —
/// done (mint), next up (dashed accent outline), and waiting (plain white).
class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.document,
    required this.uploaded,
    required this.isNext,
    required this.onTap,
  });

  final KycDocument document;
  final bool uploaded;

  /// The next required document still missing — the one tile called out.
  final bool isNext;
  final VoidCallback onTap;

  /// Uploaded tiles all read as a tick; the rest keep their own icon so the
  /// list is scannable before anything has been done.
  IconData get _icon => switch (document) {
    _ when uploaded => Icons.check_rounded,
    KycDocument.cnic || KycDocument.waterTest => Icons.photo_camera_rounded,
    KycDocument.licence => Icons.description_rounded,
    KycDocument.plantPhoto => Icons.storefront_rounded,
  };

  Color get _badgeColor => uploaded
      ? AppColors.accent2
      : isNext
      ? AppColors.accent200
      : AppColors.neutral200;

  Color get _iconColor => uploaded
      ? Colors.white
      : isNext
      ? AppColors.accent700
      : AppColors.textMuted(0.5);

  @override
  Widget build(BuildContext context) {
    final tile = AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      color: uploaded ? AppColors.accent2_100 : AppColors.surface,
      borderColor: uploaded ? AppColors.accent2_300 : null,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 24, color: _iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.label,
                  style: AppTypography.body(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  uploaded ? document.uploadedHint : document.hint,
                  style: AppTypography.body(
                    size: 13.5,
                    color: uploaded
                        ? AppColors.accent2Deep
                        : AppColors.textMuted(0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // The dashed outline is painted around the tile rather than being a
    // border on it, since Flutter's BoxBorder has no dashed stroke.
    return isNext
        ? CustomPaint(
            foregroundPainter: _DashedBorderPainter(
              color: AppColors.accent,
              radius: AppRadius.lg,
            ),
            child: tile,
          )
        : tile;
  }
}

/// Draws a dashed rounded-rectangle stroke just inside the given bounds.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 7.0;
  static const _gap = 5.0;
  static const _width = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = _width
      ..style = PaintingStyle.stroke;

    // Inset by half the stroke so the dashes sit inside the tile's bounds
    // instead of being clipped in half at the edge.
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(_width / 2),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dash),
          stroke,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
