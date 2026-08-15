import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../providers/seller_onboarding_providers.dart';

/// The waiting room. Deliberately not a dead end: the seller can set up their
/// area and stock now so orders arrive the minute approval lands.
class SellerVerificationScreen extends ConsumerWidget {
  const SellerVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(sellerApplicationProvider);

    final steps = <({String title, String subtitle, bool done, bool active})>[
      (
        title: 'Business details received',
        subtitle: application.businessName.isEmpty
            ? 'Your business'
            : '${application.businessName} · '
                  '${application.businessType?.label ?? ''}',
        done: true,
        active: false,
      ),
      (
        title: 'Documents uploaded',
        subtitle: application.uploaded
            .map((d) => d.label.split(' — ').first)
            .join(', '),
        done: true,
        active: false,
      ),
      (
        title: 'Verification in progress',
        subtitle: 'Our team is reviewing · started just now',
        done: false,
        active: true,
      ),
      (
        title: 'Live in the app',
        subtitle: 'Customers in your area can order',
        done: false,
        active: false,
      ),
    ];

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "We're checking your papers",
            style: AppTypography.heading(size: 27),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Usually done within a day. We'll send a notification the moment "
            "you're live — no need to wait here.",
            style: AppTypography.body(
              size: 14,
              color: AppColors.textMuted(0.65),
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _ProgressStep(
                    title: steps[i].title,
                    subtitle: steps[i].subtitle,
                    done: steps[i].done,
                    active: steps[i].active,
                    isLast: i == steps.length - 1,
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppNote(
            icon: Icons.rocket_launch_outlined,
            text: '',
            richText: const TextSpan(
              children: [
                TextSpan(
                  text: 'Get a head start: ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text:
                      'set your delivery area and stock now so orders arrive '
                      'the minute you\'re approved.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: 'Set up my delivery area',
        // Straight into the seller app, where area and stock live.
        onPressed: () => context.goNamed(AppRoutes.sellerServiceArea),
        secondaryLabel: 'Call support · 0800-AQUAMART',
        onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calling 0800-AQUAMART…')),
        ),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.isLast,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.accent2
                    : active
                    ? AppColors.accent100
                    : AppColors.neutral200,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: AppColors.accent, width: 2)
                    : null,
              ),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: done ? AppColors.accent2_200 : AppColors.neutral200,
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: done || active
                        ? AppColors.text
                        : AppColors.textMuted(0.45),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTypography.body(
                      size: 12.5,
                      color: AppColors.textMuted(0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
