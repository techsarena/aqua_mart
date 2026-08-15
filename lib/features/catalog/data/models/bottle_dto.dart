import '../../domain/entities/bottle.dart';

class BottleDto {
  const BottleDto({
    required this.id,
    required this.sellerId,
    required this.litres,
    required this.name,
    required this.refillPrice,
    required this.newPrice,
    this.deposit = 300,
    this.description,
    this.filledStock = 0,
    this.emptiesInYard = 0,
    this.photoUrl,
    this.isVisible = true,
  });

  final String id;
  final String sellerId;
  final int litres;
  final String name;
  final int refillPrice;
  final int newPrice;
  final int deposit;
  final String? description;
  final int filledStock;
  final int emptiesInYard;
  final String? photoUrl;
  final bool isVisible;

  factory BottleDto.fromJson(Map<String, dynamic> json) => BottleDto(
    id: '${json['id']}',
    sellerId: '${json['seller_id']}',
    litres: (json['litres'] as num?)?.toInt() ?? 25,
    name: json['name'] as String? ?? '',
    refillPrice: (json['refill_price'] as num?)?.toInt() ?? 0,
    newPrice: (json['new_price'] as num?)?.toInt() ?? 0,
    deposit: (json['deposit'] as num?)?.toInt() ?? 300,
    description: json['description'] as String?,
    filledStock: (json['filled_stock'] as num?)?.toInt() ?? 0,
    emptiesInYard: (json['empties_in_yard'] as num?)?.toInt() ?? 0,
    photoUrl: json['photo_url'] as String?,
    isVisible: json['is_visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'seller_id': sellerId,
    'litres': litres,
    'name': name,
    'refill_price': refillPrice,
    'new_price': newPrice,
    'deposit': deposit,
    'description': description,
    'filled_stock': filledStock,
    'empties_in_yard': emptiesInYard,
    'photo_url': photoUrl,
    'is_visible': isVisible,
  };

  Bottle toDomain() => Bottle(
    id: id,
    sellerId: sellerId,
    size: BottleSize.fromLitres(litres),
    name: name,
    refillPrice: refillPrice,
    newPrice: newPrice,
    deposit: deposit,
    description: description ?? '',
    filledStock: filledStock,
    emptiesInYard: emptiesInYard,
    photoUrl: photoUrl,
    isVisible: isVisible,
  );

  static BottleDto fromDomain(Bottle bottle) => BottleDto(
    id: bottle.id,
    sellerId: bottle.sellerId,
    litres: bottle.size.litres,
    name: bottle.name,
    refillPrice: bottle.refillPrice,
    newPrice: bottle.newPrice,
    deposit: bottle.deposit,
    description: bottle.description,
    filledStock: bottle.filledStock,
    emptiesInYard: bottle.emptiesInYard,
    photoUrl: bottle.photoUrl,
    isVisible: bottle.isVisible,
  );
}
