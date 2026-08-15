import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/sticky_action_bar.dart';
import '../providers/order_providers.dart';

/// "Delivered. How was it?" — stars, then what specifically was good.
///
/// The escape hatch to "Something was wrong" sits below, never competing with
/// the positive path.
class RateOrderScreen extends ConsumerStatefulWidget {
  const RateOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends ConsumerState<RateOrderScreen> {
  static const _positives = [
    'On time',
    'Seal was intact',
    'Polite rider',
    'Clean bottles',
    'Fair price',
  ];

  int _stars = 0;
  final _selectedTags = <String>{};
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await ref
        .read(orderListProvider.notifier)
        .rate(
          widget.orderId,
          stars: _stars,
          tags: _selectedTags.toList(),
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks — your rating helps.')),
        );
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId)).value;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Delivered. How was it?',
            style: AppTypography.heading(size: 27),
          ),
          if (order != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${order.itemsSummary} from ${order.sellerName} · '
              '${Formatters.rupees(order.total)} paid in '
              '${order.paymentMethod.shortLabel.toLowerCase()}',
              style: AppTypography.body(
                size: 13.5,
                color: AppColors.textMuted(0.6),
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final value = i + 1;
              final filled = value <= _stars;
              return IconButton(
                onPressed: () => setState(() => _stars = value),
                iconSize: 42,
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled
                      ? const Color(0xFFE8A33D)
                      : AppColors.neutral400,
                ),
              );
            }),
          ),

          if (_stars > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'What was good?',
              style: AppTypography.body(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in _positives)
                  ChoiceTag(
                    label: tag,
                    selected: _selectedTags.contains(tag),
                    onTap: () => setState(() {
                      _selectedTags.contains(tag)
                          ? _selectedTags.remove(tag)
                          : _selectedTags.add(tag);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Say something about this seller — optional',
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton(
              onPressed: () => context.pushReplacementNamed(
                AppRoutes.reportOrder,
                pathParameters: {'orderId': widget.orderId},
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted(0.7),
              ),
              child: const Text('Something was wrong →'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        label: _submitting ? 'Sending…' : 'Submit rating',
        enabled: _stars > 0 && !_submitting,
        onPressed: _submit,
      ),
    );
  }
}
