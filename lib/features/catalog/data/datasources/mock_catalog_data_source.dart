import '../../../../core/mock/mock_fixtures.dart';
import '../models/bottle_dto.dart';
import '../models/seller_dto.dart';
import 'catalog_remote_data_source.dart';

/// Serves the designed data with a short delay so loading states are real.
///
/// Swap for [CatalogApiDataSource] in `catalog_providers.dart` when the API is
/// ready — no other file changes.
class MockCatalogDataSource implements CatalogRemoteDataSource {
  const MockCatalogDataSource();

  static const _latency = Duration(milliseconds: 450);

  @override
  Future<List<SellerDto>> fetchNearbySellers({
    required String addressId,
    String? query,
  }) async {
    await Future<void>.delayed(_latency);

    // "Ammi's house" in Johar Town has no coverage — drives the empty state.
    final address = MockFixtures.addresses
        .where((a) => a.id == addressId)
        .firstOrNull;
    if (address != null && !address.isServiceable) return const [];

    var sellers = MockFixtures.sellers;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      sellers = sellers
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.purificationLabel.toLowerCase().contains(q),
          )
          .toList();
    }
    return sellers.map(SellerDto.fromDomain).toList();
  }

  @override
  Future<SellerDto> fetchSeller(String sellerId) async {
    await Future<void>.delayed(_latency);
    final seller = MockFixtures.sellers.firstWhere((s) => s.id == sellerId);
    return SellerDto.fromDomain(seller);
  }

  @override
  Future<List<BottleDto>> fetchSellerBottles(String sellerId) async {
    await Future<void>.delayed(_latency);
    final bottles = MockFixtures.bottlesBySeller[sellerId] ?? const [];
    return bottles.map(BottleDto.fromDomain).toList();
  }

  @override
  Future<List<SellerDto>> searchSellers({
    required String query,
    String? addressId,
    String? sort,
    bool openOnly = false,
  }) async {
    await Future<void>.delayed(_latency);
    var sellers = [...MockFixtures.sellers];

    if (openOnly) sellers = sellers.where((s) => s.isOpen).toList();

    switch (sort) {
      case 'cheapest':
        sellers.sort(
          (a, b) => (a.cheapestRefillPrice ?? 9999).compareTo(
            b.cheapestRefillPrice ?? 9999,
          ),
        );
      case 'fastest':
        sellers.sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
      case 'top_rated':
        sellers.sort((a, b) => b.rating.compareTo(a.rating));
    }

    return sellers.map(SellerDto.fromDomain).toList();
  }
}
