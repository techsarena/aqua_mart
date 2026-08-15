import 'package:aqua_mart/core/utils/formatters.dart';
import 'package:aqua_mart/features/catalog/domain/entities/bottle.dart';
import 'package:aqua_mart/features/orders/domain/entities/order_line.dart';
import 'package:aqua_mart/features/orders/domain/entities/order_status.dart';
import 'package:aqua_mart/features/orders/presentation/providers/cart_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _bottle25 = Bottle(
  id: 'b-25',
  sellerId: 's-1',
  size: BottleSize.twentyFive,
  name: '25L Cooler Bottle',
  refillPrice: 110,
  newPrice: 420,
  filledStock: 60,
);

const _bottle10 = Bottle(
  id: 'b-10',
  sellerId: 's-1',
  size: BottleSize.ten,
  name: '10L Bottle',
  refillPrice: 70,
  newPrice: 190,
  filledStock: 40,
);

/// A bottle from a different seller — used to prove the cart resets.
const _otherSellerBottle = Bottle(
  id: 'rb-25',
  sellerId: 's-2',
  size: BottleSize.twentyFive,
  name: '25L Cooler Bottle',
  refillPrice: 95,
  newPrice: 400,
  filledStock: 30,
);

void main() {
  group('CartController', () {
    late ProviderContainer container;
    CartController notifier() => container.read(cartProvider.notifier);
    CartState state() => container.read(cartProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('starts empty', () {
      expect(state().isEmpty, isTrue);
      expect(state().subtotal, 0);
    });

    test('adding a bottle records quantity and price', () {
      notifier().adjust(
        bottle: _bottle25,
        kind: PurchaseKind.refill,
        sellerName: 'Chashma Pure Water',
        delta: 2,
      );

      expect(state().bottleCount, 2);
      expect(state().subtotal, 220);
      expect(state().sellerId, 's-1');
    });

    test('refill and buy-new of one size stay separate lines', () {
      notifier()
        ..adjust(
          bottle: _bottle25,
          kind: PurchaseKind.refill,
          sellerName: 'Chashma',
        )
        ..adjust(
          bottle: _bottle25,
          kind: PurchaseKind.buyNew,
          sellerName: 'Chashma',
        );

      expect(state().lines.length, 2);
      expect(state().subtotal, 110 + 420);
      expect(state().quantityOf('b-25'), 2);
    });

    test('only refills count as empties returned', () {
      notifier()
        ..adjust(
          bottle: _bottle25,
          kind: PurchaseKind.refill,
          sellerName: 'Chashma',
          delta: 2,
        )
        ..adjust(
          bottle: _bottle10,
          kind: PurchaseKind.buyNew,
          sellerName: 'Chashma',
        );

      expect(state().emptiesReturned, 2);
    });

    test('decrementing to zero removes the line', () {
      notifier()
        ..adjust(
          bottle: _bottle25,
          kind: PurchaseKind.refill,
          sellerName: 'Chashma',
        )
        ..adjust(
          bottle: _bottle25,
          kind: PurchaseKind.refill,
          sellerName: 'Chashma',
          delta: -1,
        );

      expect(state().isEmpty, isTrue);
    });

    test('adding from another seller starts a fresh cart', () {
      notifier().adjust(
        bottle: _bottle25,
        kind: PurchaseKind.refill,
        sellerName: 'Chashma',
        delta: 3,
      );
      notifier().adjust(
        bottle: _otherSellerBottle,
        kind: PurchaseKind.refill,
        sellerName: 'Ravi Aqua',
      );

      expect(state().sellerId, 's-2');
      expect(state().bottleCount, 1);
      expect(state().subtotal, 95);
    });

    test('loadLines replaces the cart for reorder', () {
      const lines = [
        OrderLine(
          bottleId: 'b-25',
          size: BottleSize.twentyFive,
          name: '25L Cooler Bottle',
          kind: PurchaseKind.refill,
          unitPrice: 110,
          quantity: 2,
        ),
      ];

      notifier().loadLines(
        sellerId: 's-1',
        sellerName: 'Chashma Pure Water',
        lines: lines,
      );

      expect(state().bottleCount, 2);
      expect(state().subtotal, 220);
    });
  });

  group('OrderStatus', () {
    test('advances through the seller pipeline', () {
      expect(OrderStatus.pending.nextForSeller, OrderStatus.accepted);
      expect(OrderStatus.accepted.nextForSeller, OrderStatus.packed);
      expect(OrderStatus.packed.nextForSeller, OrderStatus.onTheWay);
      expect(OrderStatus.onTheWay.nextForSeller, OrderStatus.delivered);
      expect(OrderStatus.delivered.nextForSeller, isNull);
    });

    test('terminal states are not active', () {
      expect(OrderStatus.delivered.isActive, isFalse);
      expect(OrderStatus.cancelledByCustomer.isTerminal, isTrue);
      expect(OrderStatus.onTheWay.isActive, isTrue);
    });

    test('groups into the four seller buckets', () {
      expect(OrderStatus.pending.sellerBucket, 'New');
      expect(OrderStatus.accepted.sellerBucket, 'Packing');
      expect(OrderStatus.packed.sellerBucket, 'Packing');
      expect(OrderStatus.onTheWay.sellerBucket, 'On route');
      expect(OrderStatus.delivered.sellerBucket, 'Done');
    });

    test('only cash is collected by the rider', () {
      expect(PaymentMethod.cash.isCollectedByRider, isTrue);
      expect(PaymentMethod.wallet.isCollectedByRider, isFalse);
      expect(PaymentMethod.khata.isCollectedByRider, isFalse);
    });
  });

  group('Formatters', () {
    test('formats rupees with thousands separators', () {
      expect(Formatters.rupees(220), 'Rs 220');
      expect(Formatters.rupees(1180), 'Rs 1,180');
      expect(Formatters.rupees(38400), 'Rs 38,400');
    });

    test('compacts large amounts for stat tiles', () {
      expect(Formatters.rupeesCompact(12400), '12.4k');
      expect(Formatters.rupeesCompact(500), '500');
    });

    test('formats distance in metres then kilometres', () {
      expect(Formatters.distance(400), '400 m');
      expect(Formatters.distance(1200), '1.2 km');
    });

    test('normalises Pakistani phone numbers', () {
      expect(Formatters.phone('03004412987'), '+92 300 4412987');
      expect(Formatters.phone('+923004412987'), '+92 300 4412987');
    });

    test('builds avatar initials', () {
      expect(Formatters.initials('Imran Ali'), 'IA');
      expect(Formatters.initials('Ayesha'), 'A');
    });
  });

  group('OrderLine', () {
    test('computes line total and empties', () {
      const refill = OrderLine(
        bottleId: 'b-25',
        size: BottleSize.twentyFive,
        name: '25L Cooler Bottle',
        kind: PurchaseKind.refill,
        unitPrice: 110,
        quantity: 2,
      );

      expect(refill.lineTotal, 220);
      expect(refill.emptiesReturned, 2);
      expect(refill.summary, '2 × 25L refill');
    });

    test('buying new returns no empties', () {
      const bought = OrderLine(
        bottleId: 'b-25',
        size: BottleSize.twentyFive,
        name: '25L Cooler Bottle',
        kind: PurchaseKind.buyNew,
        unitPrice: 420,
        quantity: 1,
      );

      expect(bought.emptiesReturned, 0);
      expect(bought.summary, '1 × 25L new');
    });
  });
}
