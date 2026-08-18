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
    final items = await _client.getList(ApiEndpoints.addresses);
    return items.map(AddressDto.fromJson).toList();
  }

  @override
  Future<AddressDto> saveAddress(AddressDto address) async {
    final isNew = address.id.isEmpty;
    final json = isNew
        ? await _client.postObject(
            ApiEndpoints.addresses,
            body: address.toJson(),
          )
        : await _client.putObject(
            ApiEndpoints.address(address.id),
            body: address.toJson(),
          );
    return AddressDto.fromJson(json ?? const {});
  }

  @override
  Future<void> deleteAddress(String id) =>
      _client.delete<void>(ApiEndpoints.address(id));

  @override
  Future<void> setDefault(String id) =>
      _client.post<void>(ApiEndpoints.defaultAddress(id));
}
