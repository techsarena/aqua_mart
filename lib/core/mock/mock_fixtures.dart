import '../../features/addresses/domain/entities/address.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/catalog/domain/entities/bottle.dart';
import '../../features/catalog/domain/entities/seller.dart';
import '../../features/orders/domain/entities/order.dart';
import '../../features/orders/domain/entities/order_line.dart';
import '../../features/orders/domain/entities/order_status.dart';

/// Every value that appears in the design, in one place.
///
/// This is the seed data the mock data sources serve. Deleting this file and
/// pointing the providers at the `*ApiDataSource` implementations is the whole
/// job of going live.
abstract final class MockFixtures {
  // ── People ──────────────────────────────────────────────────────────────
  static final customer = AppUser(
    id: 'u-1',
    fullName: 'Ayesha Khan',
    phone: '+92 300 4412987',
    role: UserRole.customer,
    gender: Gender.female,
    walletBalance: 340,
    khataDue: 1180,
    khataSellerName: 'Chashma Pure Water',
    khataDueDate: DateTime(2026, 8, 30),
  );

  static const sellerUser = AppUser(
    id: 'u-2',
    fullName: 'Kamran Sahib',
    phone: '+92 301 5528841',
    role: UserRole.seller,
    isVerified: true,
  );

  static const riderUser = AppUser(
    id: 'u-3',
    fullName: 'Imran Ali',
    phone: '+92 301 5528841',
    role: UserRole.rider,
  );

  // ── Addresses ───────────────────────────────────────────────────────────
  static const homeAddress = Address(
    id: 'a-1',
    label: AddressLabel.home,
    title: 'Home',
    area: 'Gulberg III',
    houseNumber: '42-B',
    riderNote: 'Near Hafeez Centre. Ring the bell twice.',
    latitude: 31.5204,
    longitude: 74.3587,
    isDefault: true,
  );

  static const addresses = <Address>[
    homeAddress,
    Address(
      id: 'a-2',
      label: AddressLabel.office,
      title: 'Office',
      area: 'Ferozepur Road',
      houseNumber: '3rd floor, Arfa Tower',
      riderNote: 'Leave at reception',
      latitude: 31.4697,
      longitude: 74.2728,
    ),
    Address(
      id: 'a-3',
      label: AddressLabel.other,
      title: "Ammi's house",
      area: 'Johar Town',
      riderNote: 'No seller delivers here yet',
      latitude: 31.4697,
      longitude: 74.2728,
      isServiceable: false,
    ),
  ];

  // ── Sellers ─────────────────────────────────────────────────────────────
  static const chashma = Seller(
    id: 's-1',
    name: 'Chashma Pure Water',
    rating: 4.8,
    ratingCount: 1240,
    etaMinutes: 25,
    purificationLabel: 'RO + UV',
    sizes: [BottleSize.six, BottleSize.ten, BottleSize.twentyFive],
    cheapestRefillPrice: 110,
    freeDeliveryOver: 300,
    isRegular: true,
    distanceMetres: 1200,
    latitude: 31.5204,
    longitude: 74.3587,
  );

  static const ravi = Seller(
    id: 's-2',
    name: 'Ravi Aqua Supply',
    rating: 4.6,
    ratingCount: 610,
    etaMinutes: 35,
    purificationLabel: 'Mineral',
    sizes: [BottleSize.ten, BottleSize.twentyFive],
    cheapestRefillPrice: 95,
    distanceMetres: 2400,
    latitude: 31.5100,
    longitude: 74.3400,
  );

  static const shahzad = Seller(
    id: 's-3',
    name: 'Shahzad Water Point',
    rating: 4.4,
    ratingCount: 380,
    etaMinutes: 40,
    purificationLabel: 'RO',
    sizes: [BottleSize.ten, BottleSize.twentyFive],
    cheapestRefillPrice: 105,
    freeDeliveryOver: 0,
    distanceMetres: 3100,
    latitude: 31.5300,
    longitude: 74.3700,
  );

  static const nadeem = Seller(
    id: 's-4',
    name: 'Nadeem Water Point',
    rating: 4.3,
    ratingCount: 210,
    etaMinutes: 45,
    purificationLabel: 'RO',
    sizes: [BottleSize.twentyFive],
    cheapestRefillPrice: 100,
    isOpen: false,
    opensAt: '8:00 AM',
    distanceMetres: 3600,
    latitude: 31.5000,
    longitude: 74.3800,
  );

  static const sellers = <Seller>[chashma, ravi, shahzad, nadeem];

  // ── Bottles ─────────────────────────────────────────────────────────────
  static const chashmaBottles = <Bottle>[
    Bottle(
      id: 'b-25',
      sellerId: 's-1',
      size: BottleSize.twentyFive,
      name: '25L Cooler Bottle',
      refillPrice: 110,
      newPrice: 420,
      description: 'Standard dispenser size · in stock',
      filledStock: 62,
      emptiesInYard: 18,
    ),
    Bottle(
      id: 'b-10',
      sellerId: 's-1',
      size: BottleSize.ten,
      name: '10L Bottle',
      refillPrice: 70,
      newPrice: 190,
      description: 'Handy for small homes',
      filledStock: 40,
    ),
    Bottle(
      id: 'b-6',
      sellerId: 's-1',
      size: BottleSize.six,
      name: '6L Bottle',
      refillPrice: 45,
      newPrice: 120,
      description: 'Easy to carry',
      filledStock: 3,
    ),
  ];

  static const raviBottles = <Bottle>[
    Bottle(
      id: 'rb-25',
      sellerId: 's-2',
      size: BottleSize.twentyFive,
      name: '25L Cooler Bottle',
      refillPrice: 95,
      newPrice: 400,
      filledStock: 48,
    ),
    Bottle(
      id: 'rb-10',
      sellerId: 's-2',
      size: BottleSize.ten,
      name: '10L Bottle',
      refillPrice: 65,
      newPrice: 180,
      filledStock: 30,
    ),
  ];

  static Map<String, List<Bottle>> get bottlesBySeller => {
    's-1': chashmaBottles,
    's-2': raviBottles,
    's-3': const [
      Bottle(
        id: 'sb-25',
        sellerId: 's-3',
        size: BottleSize.twentyFive,
        name: '25L Cooler Bottle',
        refillPrice: 105,
        newPrice: 410,
        filledStock: 25,
      ),
    ],
    's-4': const [
      Bottle(
        id: 'nb-25',
        sellerId: 's-4',
        size: BottleSize.twentyFive,
        name: '25L Cooler Bottle',
        refillPrice: 100,
        newPrice: 400,
        filledStock: 12,
      ),
    ],
  };

  // ── Orders ──────────────────────────────────────────────────────────────
  static const usualLines = <OrderLine>[
    OrderLine(
      bottleId: 'b-25',
      size: BottleSize.twentyFive,
      name: '25L Cooler Bottle',
      kind: PurchaseKind.refill,
      unitPrice: 110,
      quantity: 2,
    ),
  ];

  static final activeOrder = Order(
    id: 'o-1',
    reference: 'SO-2418',
    sellerId: 's-1',
    sellerName: 'Chashma Pure Water',
    customerName: 'Ayesha Khan',
    lines: usualLines,
    address: homeAddress,
    paymentMethod: PaymentMethod.cash,
    status: OrderStatus.onTheWay,
    placedAt: DateTime(2026, 8, 15, 8, 12),
    etaMinutes: 14,
    rider: const RiderSummary(
      id: 'r-1',
      name: 'Imran Ali',
      sellerName: 'Chashma Pure Water',
      rating: 4.9,
      stopsBefore: 2,
    ),
    // No `timeline` here on purpose: the tracking steps are derived from the
    // order's status (`Order.trackingSteps`), so there is nothing to keep in
    // sync — and the DTO never carried this field across anyway.
  );

  static final pastOrders = <Order>[
    Order(
      id: 'o-2',
      reference: 'SO-2390',
      sellerId: 's-1',
      sellerName: 'Chashma Pure Water',
      customerName: 'Ayesha Khan',
      lines: usualLines,
      address: homeAddress,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.delivered,
      placedAt: DateTime(2026, 7, 28, 9, 5),
    ),
    Order(
      id: 'o-3',
      reference: 'SO-2361',
      sellerId: 's-1',
      sellerName: 'Chashma Pure Water',
      customerName: 'Ayesha Khan',
      lines: const [
        OrderLine(
          bottleId: 'b-25',
          size: BottleSize.twentyFive,
          name: '25L Cooler Bottle',
          kind: PurchaseKind.refill,
          unitPrice: 110,
          quantity: 1,
        ),
        OrderLine(
          bottleId: 'b-6',
          size: BottleSize.six,
          name: '6L Bottle',
          kind: PurchaseKind.refill,
          unitPrice: 45,
          quantity: 2,
        ),
      ],
      address: homeAddress,
      paymentMethod: PaymentMethod.wallet,
      status: OrderStatus.delivered,
      placedAt: DateTime(2026, 7, 21, 10, 30),
    ),
    Order(
      id: 'o-4',
      reference: 'SO-2333',
      sellerId: 's-2',
      sellerName: 'Ravi Aqua Supply',
      customerName: 'Ayesha Khan',
      lines: const [
        OrderLine(
          bottleId: 'rb-25',
          size: BottleSize.twentyFive,
          name: '25L Cooler Bottle',
          kind: PurchaseKind.refill,
          unitPrice: 110,
          quantity: 2,
        ),
      ],
      address: homeAddress,
      paymentMethod: PaymentMethod.cash,
      status: OrderStatus.delivered,
      placedAt: DateTime(2026, 7, 14, 8, 45),
    ),
  ];
}
