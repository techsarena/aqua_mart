import '../../../../core/utils/result.dart';
import '../../domain/entities/bottle.dart';
import '../../domain/entities/seller.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_remote_data_source.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._remote);

  final CatalogRemoteDataSource _remote;

  @override
  Future<Result<List<Seller>>> nearbySellers({
    required String addressId,
    String? query,
  }) => Result.guard(() async {
    final dtos = await _remote.fetchNearbySellers(
      addressId: addressId,
      query: query,
    );
    return dtos.map((d) => d.toDomain()).toList();
  });

  @override
  Future<Result<Seller>> sellerById(String sellerId) =>
      Result.guard(() async => (await _remote.fetchSeller(sellerId)).toDomain());

  @override
  Future<Result<List<Bottle>>> bottlesFor(String sellerId) =>
      Result.guard(() async {
        final dtos = await _remote.fetchSellerBottles(sellerId);
        return dtos.map((d) => d.toDomain()).toList();
      });

  @override
  Future<Result<List<Seller>>> search({
    required String query,
    String? addressId,
    SellerSort sort = SellerSort.relevance,
    bool openOnly = false,
  }) => Result.guard(() async {
    final dtos = await _remote.searchSellers(
      query: query,
      addressId: addressId,
      sort: sort.wireValue,
      openOnly: openOnly,
    );
    return dtos.map((d) => d.toDomain()).toList();
  });
}
