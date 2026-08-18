import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/wallet.dart';

abstract interface class WalletRemoteDataSource {
  Future<Wallet> fetchWallet();

  /// Starts a top-up. The returned [TopUp] is `pending` — the customer has to
  /// approve it in the provider's app.
  Future<TopUp> startTopUp({
    required int amount,
    required TopUpProvider provider,
  });

  /// Polled while the pending screen is open.
  Future<TopUp> checkTopUp(String id);

  Future<void> saveCard({
    required String number,
    required String holder,
    required String expiry,
    required String cvv,
    bool saveForNextTime = true,
  });
}

class WalletApiDataSource implements WalletRemoteDataSource {
  const WalletApiDataSource(this._client);

  final ApiClient _client;

  @override
  Future<Wallet> fetchWallet() async {
    final data = await _client.getObject(ApiEndpoints.wallet) ?? const {};
    return Wallet(
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      pendingDeposits: (data['pending_deposits'] as num?)?.toInt() ?? 0,
      transactions:
          (data['transactions'] as List?)
              ?.map(
                (e) => WalletTransaction(
                  id: '${e['id']}',
                  label: e['label'] as String? ?? '',
                  amount: (e['amount'] as num?)?.toInt() ?? 0,
                  at:
                      DateTime.tryParse(e['at'] as String? ?? '') ??
                      DateTime.now(),
                  isCredit: e['is_credit'] as bool? ?? true,
                ),
              )
              .toList() ??
          const [],
    );
  }

  @override
  Future<TopUp> startTopUp({
    required int amount,
    required TopUpProvider provider,
  }) async {
    final json = await _client.postObject(
      ApiEndpoints.walletTopUp,
      body: {'amount': amount, 'provider': provider.name},
    );
    return _topUpFrom(json ?? const {});
  }

  @override
  Future<TopUp> checkTopUp(String id) async {
    final json = await _client.getObject(ApiEndpoints.topUpStatus(id));
    return _topUpFrom(json ?? const {});
  }

  @override
  Future<void> saveCard({
    required String number,
    required String holder,
    required String expiry,
    required String cvv,
    bool saveForNextTime = true,
  }) => _client.post<void>(
    ApiEndpoints.cards,
    body: {
      'number': number,
      'holder': holder,
      'expiry': expiry,
      'cvv': cvv,
      'save': saveForNextTime,
    },
  );

  TopUp _topUpFrom(Map<String, dynamic> json) => TopUp(
    id: '${json['id']}',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    provider:
        TopUpProvider.values
            .where((p) => p.name == json['provider'])
            .firstOrNull ??
        TopUpProvider.jazzCash,
    status:
        TopUpStatus.values.where((s) => s.name == json['status']).firstOrNull ??
        TopUpStatus.pending,
    bonus: (json['bonus'] as num?)?.toInt() ?? 0,
    fee: (json['fee'] as num?)?.toInt() ?? 0,
    reference: json['reference'] as String?,
    completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
    failureReason: json['failure_reason'] as String?,
  );
}
