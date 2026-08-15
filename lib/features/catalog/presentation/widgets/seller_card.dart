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
    padding: const EdgeInsets.all(15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerAvatar(size: 64, isOpen: seller.isOpen),
        const SizedBox(width: 13),
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
                      style: AppTypography.body(
                        size: 16.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (seller.isRegular) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.accent,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
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
                  size: 13,
                  color: AppColors.textMuted(0.6),
                ),
              ),
              const SizedBox(height: 7),
              // Rating and ETA read as pills, not as an icon row.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppTag('★ ${seller.rating.toStringAsFixed(1)}',
                      tone: TagTone.accent),
                  if (seller.isOpen)
                    AppTag(
                      Formatters.eta(seller.etaMinutes),
                      tone: TagTone.neutral,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!seller.isOpen)
              const AppTag('Pre-order', tone: TagTone.neutral)
            else if (priceLabel != null)
              Text(
                priceLabel!,
                style: AppTypography.body(size: 13, weight: FontWeight.w700),
              )
            else if (seller.cheapestRefillPrice != null) ...[
              Text(
                Formatters.rupees(seller.cheapestRefillPrice!),
                style: AppTypography.body(size: 14.5, weight: FontWeight.w800),
              ),
              Text(
                'refill',
                style: AppTypography.body(
                  size: 11,
                  color: AppColors.textMuted(0.5),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
