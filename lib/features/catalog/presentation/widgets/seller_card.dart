import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tag.dart';
import '../../domain/entities/seller.dart';

/// One seller in the "Sellers near you" list.
///
/// Closed sellers stay visible but read as pre-order only — the design keeps
/// them in the list rather than hiding supply.
class SellerCard extends StatelessWidget {
  const SellerCard({
    super.key,
    required this.seller,
    required this.onTap,
    this.highlight,
    this.priceLabel,
  });

  final Seller seller;
  final VoidCallback onTap;

  /// "Your regular", "Cheapest here", "Free delivery".
  final String? highlight;

  /// Overrides the default `Refill Rs 110` price line.
  final String? priceLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    radius: 24,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerAvatar(size: 72, isOpen: seller.isOpen),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      seller.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading(size: 19),
                    ),
                  ),
                  if (seller.isRegular) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 17,
                      color: AppColors.accent,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                seller.isOpen
                    ? [
                        if (highlight != null) highlight!,
                        seller.subtitle,
                      ].join(' · ')
                    : 'Closed · opens ${seller.opensAt ?? 'later'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.textMuted(0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Rating, ETA and price all read as pills on one line — the
              // price is the decision, so it carries the positive tone.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppTag(
                    '★ ${seller.rating.toStringAsFixed(1)}',
                    tone: TagTone.accent,
                  ),
                  if (seller.isOpen)
                    AppTag(
                      Formatters.eta(seller.etaMinutes),
                      tone: TagTone.neutral,
                    )
                  else
                    const AppTag('Pre-order', tone: TagTone.neutral),
                  if (priceLabel != null)
                    AppTag(priceLabel!, tone: TagTone.accent2)
                  else if (seller.cheapestRefillPrice != null)
                    AppTag(
                      'Refill ${Formatters.rupees(seller.cheapestRefillPrice!)}',
                      tone: TagTone.accent2,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
