import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/wallet_data_source.dart';
import '../../domain/entities/wallet.dart';

final walletDataSourceProvider = Provider<WalletRemoteDataSource>((ref) {
  if (useMockData) return MockWalletDataSource();
  return WalletApiDataSource(ref.watch(apiClientProvider));
});

class WalletNotifier extends AsyncNotifier<Wallet> {
  @override
  Future<Wallet> build() => ref.watch(walletDataSourceProvider).fetchWallet();

  Future<Result<TopUp>> startTopUp({
    required int amount,
    required TopUpProvider provider,
  }) => Result.guard(
    () => ref
        .read(walletDataSourceProvider)
        .startTopUp(amount: amount, provider: provider),
  );

  Future<Result<TopUp>> checkTopUp(String id) async {
    final result = await Result.guard(
      () => ref.read(walletDataSourceProvider).checkTopUp(id),
    );
    // A settled top-up changes the balance, so the wallet is refetched.
    if (result.valueOrNull?.status == TopUpStatus.succeeded) {
      ref.invalidateSelf();
    }
    return result;
  }

  Future<Result<void>> saveCard({
    required String number,
    required String holder,
    required String expiry,
    required String cvv,
    bool saveForNextTime = true,
  }) => Result.guard(
    () => ref
        .read(walletDataSourceProvider)
        .saveCard(
          number: number,
          holder: holder,
          expiry: expiry,
          cvv: cvv,
          saveForNextTime: saveForNextTime,
        ),
  );
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, Wallet>(
  WalletNotifier.new,
);
