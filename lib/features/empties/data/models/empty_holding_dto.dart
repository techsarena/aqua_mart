import '../../domain/entities/empty_holding.dart';

class EmptyHoldingDto {
  const EmptyHoldingDto({
    required this.id,
    required this.litres,
    required this.count,
    required this.sellerId,
    required this.sellerName,
    required this.deposit,
  });

  final String id;
  final int litres;
  final int count;
  final String sellerId;
  final String sellerName;
  final int deposit;

  factory EmptyHoldingDto.fromJson(Map<String, dynamic> json) =>
      EmptyHoldingDto(
        id: '${json['id']}',
        litres: (json['litres'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
        sellerId: '${json['seller_id']}',
        sellerName: json['seller_name'] as String? ?? '',
        deposit: (json['deposit'] as num?)?.toInt() ?? 0,
      );

  EmptyHolding toDomain() => EmptyHolding(
    id: id,
    litres: litres,
    count: count,
    sellerId: sellerId,
    sellerName: sellerName,
    deposit: deposit,
  );
}

class EmptiesSummaryDto {
  const EmptiesSummaryDto({
    required this.holdings,
    required this.totalDeposit,
    required this.refillPricePerBottle,
  });

  final List<EmptyHoldingDto> holdings;
  final int totalDeposit;
  final int refillPricePerBottle;

  factory EmptiesSummaryDto.fromJson(Map<String, dynamic> json) =>
      EmptiesSummaryDto(
        holdings:
            (json['holdings'] as List?)
                ?.map((e) => EmptyHoldingDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        totalDeposit: (json['total_deposit'] as num?)?.toInt() ?? 0,
        refillPricePerBottle:
            (json['refill_price_per_bottle'] as num?)?.toInt() ?? 0,
      );

  EmptiesSummary toDomain() => EmptiesSummary(
    holdings: holdings.map((h) => h.toDomain()).toList(),
    totalDeposit: totalDeposit,
    refillPricePerBottle: refillPricePerBottle,
  );
}
