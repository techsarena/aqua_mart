import '../../../../core/utils/result.dart';
import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_data_source.dart';
import '../models/address_dto.dart';

class AddressRepositoryImpl implements AddressRepository {
  const AddressRepositoryImpl(this._remote);

  final AddressRemoteDataSource _remote;

  @override
  Future<Result<List<Address>>> addresses() => Result.guard(() async {
    final dtos = await _remote.fetchAddresses();
    return dtos.map((d) => d.toDomain()).toList();
  });

  @override
  Future<Result<Address>> save(Address address) => Result.guard(() async {
    final saved = await _remote.saveAddress(AddressDto.fromDomain(address));
    return saved.toDomain();
  });

  @override
  Future<Result<void>> delete(String id) =>
      Result.guard(() => _remote.deleteAddress(id));

  @override
  Future<Result<void>> setDefault(String id) =>
      Result.guard(() => _remote.setDefault(id));
}
