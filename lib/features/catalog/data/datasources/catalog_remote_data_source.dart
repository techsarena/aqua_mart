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
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sellersNearby,
      query: {'address_id': addressId, if (query != null) 'q': query},
    );
    return _sellerList(json);
  }

  @override
  Future<SellerDto> fetchSeller(String sellerId) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.seller(sellerId),
    );
    return SellerDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<List<BottleDto>> fetchSellerBottles(String sellerId) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sellerBottles(sellerId),
    );
    final items = (json['data'] ?? json['bottles']) as List? ?? const [];
    return items
        .map((e) => BottleDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SellerDto>> searchSellers({
    required String query,
    String? addressId,
    String? sort,
    bool openOnly = false,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.searchSellers,
      query: {
        'q': query,
        if (addressId != null) 'address_id': addressId,
        if (sort != null) 'sort': sort,
        if (openOnly) 'open_now': true,
      },
    );
    return _sellerList(json);
  }

  List<SellerDto> _sellerList(Map<String, dynamic> json) {
    final items = (json['data'] ?? json['sellers']) as List? ?? const [];
    return items
        .map((e) => SellerDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
