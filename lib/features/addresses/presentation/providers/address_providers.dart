import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/address_data_source.dart';
import '../../data/repositories/address_repository_impl.dart';
import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';

final addressDataSourceProvider = Provider<AddressRemoteDataSource>((ref) {
  return AddressApiDataSource(ref.watch(apiClientProvider));
});

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepositoryImpl(ref.watch(addressDataSourceProvider)),
);

/// The customer's saved addresses. Invalidated after any write so every screen
/// showing an address refreshes together.
class AddressBookNotifier extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    final result = await ref.watch(addressRepositoryProvider).addresses();
    return result.when(success: (list) => list, failure: (f) => throw f);
  }

  Future<Address?> save(Address address) async {
    final result = await ref.read(addressRepositoryProvider).save(address);
    return result.when(
      success: (saved) {
        ref.invalidateSelf();
        return saved;
      },
      failure: (_) => null,
    );
  }

  Future<void> setDefault(String id) async {
    await ref.read(addressRepositoryProvider).setDefault(id);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(addressRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final addressBookProvider =
    AsyncNotifierProvider<AddressBookNotifier, List<Address>>(
      AddressBookNotifier.new,
    );

/// A per-session delivery choice. Null means "use current location" on the
/// home screen and fall back to the persisted default wherever an API needs a
/// saved address id.
class DeliveryAddressSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? addressId) => state = addressId;
}

final deliveryAddressSelectionProvider =
    NotifierProvider<DeliveryAddressSelectionNotifier, String?>(
      DeliveryAddressSelectionNotifier.new,
    );

/// The address the app is currently delivering to — the default, unless the
/// customer picked another for this order.
final selectedAddressProvider = Provider<Address?>((ref) {
  final addresses = ref.watch(addressBookProvider).value ?? const [];
  if (addresses.isEmpty) return null;
  final selectedId = ref.watch(deliveryAddressSelectionProvider);
  if (selectedId != null) {
    final selected = addresses.where((a) => a.id == selectedId).firstOrNull;
    if (selected != null) return selected;
  }
  return addresses.firstWhere(
    (a) => a.isDefault,
    orElse: () => addresses.first,
  );
});
