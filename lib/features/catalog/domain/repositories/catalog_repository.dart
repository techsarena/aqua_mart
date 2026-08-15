import '../../../../core/utils/result.dart';
import '../entities/bottle.dart';
import '../entities/seller.dart';

/// Domain-facing contract. The presentation layer only ever sees this.
abstract interface class CatalogRepository {
  Future<Result<List<Seller>>> nearbySellers({
    required String addressId,
    String? query,
  });

  Future<Result<Seller>> sellerById(String sellerId);

  Future<Result<List<Bottle>>> bottlesFor(String sellerId);

  Future<Result<List<Seller>>> search({
    required String query,
    String? addressId,
    SellerSort sort = SellerSort.relevance,
    bool openOnly = false,
  });
}

/// The filter chips on the search results screen.
enum SellerSort {
  relevance(null, 'Relevant'),
  cheapest('cheapest', 'Cheapest'),
  fastest('fastest', 'Fastest'),
  topRated('top_rated', 'Top rated');

  const SellerSort(this.wireValue, this.label);

  final String? wireValue;
  final String label;
}
