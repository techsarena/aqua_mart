import '../../../../core/error/failure.dart';
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
    final json = await _client.get<Map<String, dynamic>>(ApiEndpoints.wallet);
    final data = json['data'] as Map<String, dynamic>? ?? json;
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
    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.walletTopUp,
      body: {'amount': amount, 'provider': provider.name},
    );
    return _topUpFrom(json['data'] as Map<String, dynamic>? ?? json);
  }

  @override
  Future<TopUp> checkTopUp(String id) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.topUpStatus(id),
    );
    return _topUpFrom(json['data'] as Map<String, dynamic>? ?? json);
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

/// Simulates the JazzCash handoff, including the timeout ending.
class MockWalletDataSource implements WalletRemoteDataSource {
  MockWalletDataSource();

  int _balance = 340;
  final _pending = <String, TopUp>{};
  int _nextId = 1;

  /// Flip to make the next top-up fail — used to demo the unhappy path.
  bool failNextTopUp = false;

  @override
  Future<Wallet> fetchWallet() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Wallet(
      balance: _balance,
      pendingDeposits: 900,
      transactions: [
        WalletTransaction(
          id: 't-1',
          label: 'Refund · broken seal',
          amount: 110,
          at: DateTime.now().subtract(const Duration(days: 2)),
        ),
        WalletTransaction(
          id: 't-2',
          label: 'Order #SO-2361',
          amount: 200,
          at: DateTime.now().subtract(const Duration(days: 25)),
          isCredit: false,
        ),
        WalletTransaction(
          id: 't-3',
          label: 'JazzCash top-up',
          amount: 500,
          at: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ],
    );
  }

  @override
  Future<TopUp> startTopUp({
    required int amount,
    required TopUpProvider provider,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final id = 'tu-${_nextId++}';
    // Rs 1,000 carries the Rs 60 bonus from the design.
    final bonus = amount >= 1000 ? 60 : 0;

    final topUp = TopUp(
      id: id,
      amount: amount,
      provider: provider,
      status: TopUpStatus.pending,
      bonus: bonus,
    );
    _pending[id] = topUp;
    return topUp;
  }

  @override
  Future<TopUp> checkTopUp(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final topUp = _pending[id];
    if (topUp == null) throw const ServerFailure('That top-up has expired.');

    if (failNextTopUp) {
      final failed = TopUp(
        id: topUp.id,
        amount: topUp.amount,
        provider: topUp.provider,
        status: TopUpStatus.failed,
        failureReason: 'JazzCash said the request timed out.',
      );
      _pending[id] = failed;
      return failed;
    }

    final succeeded = TopUp(
      id: topUp.id,
      amount: topUp.amount,
      provider: topUp.provider,
      status: TopUpStatus.succeeded,
      bonus: topUp.bonus,
      reference: 'JC-84120397',
      completedAt: DateTime.now(),
    );
    _balance += succeeded.credited;
    _pending[id] = succeeded;
    return succeeded;
  }

  @override
  Future<void> saveCard({
    required String number,
    required String holder,
    required String expiry,
    required String cvv,
    bool saveForNextTime = true,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
