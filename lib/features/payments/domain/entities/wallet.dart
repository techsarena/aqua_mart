import 'package:equatable/equatable.dart';

/// The mobile-money rails the app tops up through.
enum TopUpProvider {
  jazzCash('JazzCash', 'JC'),
  easypaisa('Easypaisa', 'EP');

  const TopUpProvider(this.label, this.initials);

  final String label;
  final String initials;
}

/// Where a top-up sits. The customer approves it in the provider's own app, so
/// the request is pending until that happens or it times out.
enum TopUpStatus { pending, succeeded, failed }

class TopUp extends Equatable {
  const TopUp({
    required this.id,
    required this.amount,
    required this.provider,
    required this.status,
    this.bonus = 0,
    this.fee = 0,
    this.reference,
    this.completedAt,
    this.failureReason,
  });

  final String id;
  final int amount;
  final TopUpProvider provider;
  final TopUpStatus status;

  /// Promotional credit — "Top up Rs 1,000 and get Rs 60 free".
  final int bonus;
  final int fee;

  /// The provider's own reference, shown on the receipt.
  final String? reference;
  final DateTime? completedAt;
  final String? failureReason;

  int get credited => amount + bonus;

  @override
  List<Object?> get props => [id, amount, provider, status];
}

class WalletTransaction extends Equatable {
  const WalletTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.at,
    this.isCredit = true,
  });

  final String id;
  final String label;
  final int amount;
  final DateTime at;
  final bool isCredit;

  @override
  List<Object?> get props => [id, amount, at];
}

class Wallet extends Equatable {
  const Wallet({
    required this.balance,
    this.pendingDeposits = 0,
    this.transactions = const [],
  });

  final int balance;

  /// Deposits released once empties are collected.
  final int pendingDeposits;
  final List<WalletTransaction> transactions;

  @override
  List<Object?> get props => [balance, pendingDeposits, transactions];
}
