import '../../../../core/utils/result.dart';
import '../entities/address.dart';

abstract interface class AddressRepository {
  Future<Result<List<Address>>> addresses();

  /// Creates when [address] has an empty id, updates otherwise.
  Future<Result<Address>> save(Address address);

  Future<Result<void>> delete(String id);

  Future<Result<void>> setDefault(String id);
}
