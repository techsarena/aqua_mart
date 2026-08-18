import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/catalog_remote_data_source.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/entities/bottle.dart';
import '../../domain/entities/seller.dart';
import '../../domain/repositories/catalog_repository.dart';

/// The one line to change when the REST API goes live.
final catalogDataSourceProvider = Provider<CatalogRemoteDataSource>((ref) {
  return CatalogApiDataSource(ref.watch(apiClientProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(ref.watch(catalogDataSourceProvider)),
);

/// Sellers that deliver to the given address, or every approved seller when
/// the customer has no address saved yet.
final nearbySellersProvider = FutureProvider.family<List<Seller>, String?>((
  ref,
  addressId,
) async {
  final result = await ref
      .watch(catalogRepositoryProvider)
      .nearbySellers(addressId: addressId);
  return result.when(success: (sellers) => sellers, failure: (f) => throw f);
});

final sellerProvider = FutureProvider.family<Seller, String>((
  ref,
  sellerId,
) async {
  final result = await ref
      .watch(catalogRepositoryProvider)
      .sellerById(sellerId);
  return result.when(success: (s) => s, failure: (f) => throw f);
});

final sellerBottlesProvider = FutureProvider.family<List<Bottle>, String>((
  ref,
  sellerId,
) async {
  final result = await ref
      .watch(catalogRepositoryProvider)
      .bottlesFor(sellerId);
  return result.when(success: (b) => b, failure: (f) => throw f);
});

/// Query + sort state for the search results screen.
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.sort = SellerSort.relevance,
    this.openOnly = false,
  });

  final String text;
  final SellerSort sort;
  final bool openOnly;

  SearchQuery copyWith({String? text, SellerSort? sort, bool? openOnly}) =>
      SearchQuery(
        text: text ?? this.text,
        sort: sort ?? this.sort,
        openOnly: openOnly ?? this.openOnly,
      );
}

class SearchController extends Notifier<SearchQuery> {
  @override
  SearchQuery build() => const SearchQuery();

  void setText(String text) => state = state.copyWith(text: text);
  void setSort(SellerSort sort) => state = state.copyWith(sort: sort);
  void toggleOpenOnly() => state = state.copyWith(openOnly: !state.openOnly);
}

final searchQueryProvider = NotifierProvider<SearchController, SearchQuery>(
  SearchController.new,
);

final searchResultsProvider = FutureProvider<List<Seller>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final result = await ref
      .watch(catalogRepositoryProvider)
      .search(query: query.text, sort: query.sort, openOnly: query.openOnly);
  return result.when(success: (s) => s, failure: (f) => throw f);
});
