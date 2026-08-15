import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

enum TagTone { accent, accent2, neutral, outline, warning, danger }

/// Small pill label — "Best fit", "Your regular", "Cheapest here".
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.tone = TagTone.neutral, this.icon});

  final String label;
  final TagTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TagTone.accent => (AppColors.accent100, AppColors.accent800),
      TagTone.accent2 => (AppColors.accent2_100, AppColors.accent2_700),
      TagTone.neutral => (AppColors.neutral200, AppColors.neutral700),
      TagTone.outline => (Colors.transparent, AppColors.accent),
      TagTone.warning => (AppColors.warningBg, AppColors.warning),
      TagTone.danger => (AppColors.dangerBg, AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: tone == TagTone.outline
            ? Border.all(color: AppColors.accent)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.body(
              size: 11,
              weight: FontWeight.w700,
              color: fg,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// `★ 4.8` — the rating chip used on every seller row.
class RatingChip extends StatelessWidget {
  const RatingChip(this.rating, {super.key, this.count, this.compact = true});

  final double rating;
  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFE8A33D)),
      const SizedBox(width: 3),
      Text(
        count != null && !compact
            ? '${rating.toStringAsFixed(1)} ($count)'
            : rating.toStringAsFixed(1),
        style: AppTypography.body(
          size: 12.5,
          weight: FontWeight.w700,
          color: AppColors.textMuted(0.75),
        ),
      ),
    ],
  );
}

/// A labelled number in a row of three — "14 orders today · 9 delivered".
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.prefix,
  });

  final String value;
  final String label;
  final Color? valueColor;

  /// Rendered small before the value — the `Rs` in `Rs 12.4k`.
  final String? prefix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (prefix != null) ...[
            Text(
              prefix!,
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w700,
                color: valueColor ?? AppColors.text,
              ),
            ),
            const SizedBox(width: 2),
          ],
          Text(
            value,
            style: AppTypography.heading(
              size: 24,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: AppTypography.body(size: 11.5, color: AppColors.textMuted(0.6)),
      ),
    ],
  );
}
