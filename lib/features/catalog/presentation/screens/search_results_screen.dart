import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/selectable_option.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../domain/entities/seller.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../providers/catalog_providers.dart';
import '../widgets/seller_card.dart';

/// Search across sellers, with the filters the design calls for:
/// cheapest, fastest, top rated, open now.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late final _controller = TextEditingController(
    text: widget.initialQuery ?? '',
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery;
    if (initial != null && initial.isNotEmpty) {
      // Seed the shared query after the first frame so the provider exists.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(searchQueryProvider.notifier).setText(initial),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final async = ref.watch(searchResultsProvider);
    final area = ref.watch(selectedAddressProvider)?.area ?? 'your area';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.gutter),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialQuery == null,
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).setText(value),
            decoration: const InputDecoration(
              hintText: 'Search sellers or bottle size',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 10,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          // Sort chips, plus "Open now" as an independent toggle.
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              children: [
                for (final sort in SellerSort.values.skip(1)) ...[
                  ChoiceTag(
                    label: sort.label,
                    selected: query.sort == sort,
                    onTap: () =>
                        ref.read(searchQueryProvider.notifier).setSort(sort),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                ChoiceTag(
                  label: 'Open now',
                  selected: query.openOnly,
                  onTap: () =>
                      ref.read(searchQueryProvider.notifier).toggleOpenOnly(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: switch (async) {
              AsyncLoading() => const SkeletonList(
                itemCount: 4,
                itemHeight: 90,
              ),
              AsyncError(:final error) => ErrorView(
                failure: asFailure(error),
                onRetry: () => ref.invalidate(searchResultsProvider),
              ),
              AsyncValue(value: final sellers) =>
                (sellers?.isEmpty ?? true)
                    ? const Center(
                        child: EmptyView(
                          icon: Icons.search_off_rounded,
                          title: 'No sellers matched',
                          message: 'Try a different size or clear the filters.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          0,
                          AppSpacing.gutter,
                          AppSpacing.xxl,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                              left: 4,
                            ),
                            child: Text(
                              '${sellers!.length} sellers deliver to $area',
                              style: AppTypography.body(
                                size: 12.5,
                                color: AppColors.textMuted(0.55),
                              ),
                            ),
                          ),
                          for (final seller in sellers) ...[
                            SellerCard(
                              seller: seller,
                              highlight: _highlightFor(
                                seller,
                                sellers,
                                query.sort,
                              ),
                              onTap: () => context.pushNamed(
                                AppRoutes.sellerStore,
                                pathParameters: {'sellerId': seller.id},
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      ),
            },
          ),
        ],
      ),
    );
  }

  /// Labels the standout result for whichever sort is active.
  static String? _highlightFor(
    Seller seller,
    List<Seller> all,
    SellerSort sort,
  ) {
    if (seller.isRegular) return 'Your regular';
    if (all.isEmpty) return null;

    return switch (sort) {
      SellerSort.cheapest when seller.id == all.first.id => 'Cheapest here',
      SellerSort.fastest when seller.id == all.first.id => 'Fastest here',
      SellerSort.topRated when seller.id == all.first.id => 'Top rated',
      _ => seller.freeDeliveryOver == 0 ? 'Free delivery' : null,
    };
  }
}
