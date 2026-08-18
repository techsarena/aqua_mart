import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/bottle_dto.dart';
import '../models/seller_dto.dart';

/// The contract every catalogue backend must satisfy.
///
/// [CatalogApiDataSource] is the live REST implementation; the mock in
/// `mock_catalog_data_source.dart` serves the designed data until the API is
/// ready. Repositories depend on this interface, so switching is a one-line
/// change in the provider.
abstract interface class CatalogRemoteDataSource {
  Future<List<SellerDto>> fetchNearbySellers({
    required String addressId,
    String? query,
  });

  /// Every approved seller, unfiltered by address.
  ///
  /// A customer who has not saved an address yet still needs to see who is
  /// out there — otherwise the app looks empty at the exact moment it should
  /// be selling.
  Future<List<SellerDto>> fetchAllSellers({String? query});

  Future<SellerDto> fetchSeller(String sellerId);

  Future<List<BottleDto>> fetchSellerBottles(String sellerId);

  Future<List<SellerDto>> searchSellers({
    required String query,
    String? addressId,
    String? sort,
    bool openOnly = false,
  });
}

class CatalogApiDataSource implements CatalogRemoteDataSource {
  const CatalogApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<SellerDto>> fetchNearbySellers({
    required String addressId,
    String? query,
  }) async {
    final items = await _client.getList(
      ApiEndpoints.sellersNearby,
      query: {'address_id': addressId, if (query != null) 'q': query},
    );
    return items.map(SellerDto.fromJson).toList();
  }

  @override
  Future<List<SellerDto>> fetchAllSellers({String? query}) async {
    final items = await _client.getList(
      ApiEndpoints.sellers,
      query: {if (query != null && query.isNotEmpty) 'q': query},
    );
    return items.map(SellerDto.fromJson).toList();
  }

  @override
  Future<SellerDto> fetchSeller(String sellerId) async {
    final json = await _client.getObject(ApiEndpoints.seller(sellerId));
    return SellerDto.fromJson(json ?? const {});
  }

  @override
  Future<List<BottleDto>> fetchSellerBottles(String sellerId) async {
    final items = await _client.getList(ApiEndpoints.sellerBottles(sellerId));
    return items.map(BottleDto.fromJson).toList();
  }

  @override
  Future<List<SellerDto>> searchSellers({
    required String query,
    String? addressId,
    String? sort,
    bool openOnly = false,
  }) async {
    final items = await _client.getList(
      ApiEndpoints.searchSellers,
      query: {
        'q': query,
        if (addressId != null) 'address_id': addressId,
        if (sort != null) 'sort': sort,
        if (openOnly) 'open_now': true,
      },
    );
    return items.map(SellerDto.fromJson).toList();
  }
}
