import '../../../../core/mock/mock_fixtures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/address_dto.dart';

abstract interface class AddressRemoteDataSource {
  Future<List<AddressDto>> fetchAddresses();
  Future<AddressDto> saveAddress(AddressDto address);
  Future<void> deleteAddress(String id);
  Future<void> setDefault(String id);
}

class AddressApiDataSource implements AddressRemoteDataSource {
  const AddressApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<AddressDto>> fetchAddresses() async {
    final json = await _client.get<Map<String, dynamic>>(ApiEndpoints.addresses);
    final items = (json['data'] ?? json['addresses']) as List? ?? const [];
    return items
        .map((e) => AddressDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AddressDto> saveAddress(AddressDto address) async {
    final isNew = address.id.isEmpty;
    final json = isNew
        ? await _client.post<Map<String, dynamic>>(
            ApiEndpoints.addresses,
            body: address.toJson(),
          )
        : await _client.put<Map<String, dynamic>>(
            ApiEndpoints.address(address.id),
            body: address.toJson(),
          );
    return AddressDto.fromJson(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<void> deleteAddress(String id) =>
      _client.delete<void>(ApiEndpoints.address(id));

  @override
  Future<void> setDefault(String id) =>
      _client.post<void>(ApiEndpoints.defaultAddress(id));
}

/// In-memory address book seeded from the design.
class MockAddressDataSource implements AddressRemoteDataSource {
  MockAddressDataSource()
    : _addresses = MockFixtures.addresses.map(AddressDto.fromDomain).toList();

  final List<AddressDto> _addresses;
  int _nextId = 100;

  static const _latency = Duration(milliseconds: 350);

  @override
  Future<List<AddressDto>> fetchAddresses() async {
    await Future<void>.delayed(_latency);
    return List<AddressDto>.unmodifiable(_addresses);
  }

  @override
  Future<AddressDto> saveAddress(AddressDto address) async {
    await Future<void>.delayed(_latency);

    final saved = address.id.isEmpty
        ? address.copyWith(id: 'a-${_nextId++}')
        : address;

    final index = _addresses.indexWhere((a) => a.id == saved.id);
    if (index >= 0) {
      _addresses[index] = saved;
    } else {
      _addresses.add(saved);
    }

    if (saved.isDefault) _applyDefault(saved.id);
    return saved;
  }

  @override
  Future<void> deleteAddress(String id) async {
    await Future<void>.delayed(_latency);
    _addresses.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> setDefault(String id) async {
    await Future<void>.delayed(_latency);
    _applyDefault(id);
  }

  /// Exactly one address carries the default flag.
  void _applyDefault(String id) {
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(
        isDefault: _addresses[i].id == id,
      );
    }
  }
}
