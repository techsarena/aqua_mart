/// The lifecycle of an order, as all three roles see it.
enum OrderStatus {
  /// Placed, waiting for the seller to accept. Sellers see this as "New".
  pending('Waiting for the seller'),

  /// Seller accepted; bottles are being loaded. Sellers see "Packing".
  accepted('Order confirmed'),
  packed('Bottles loaded'),

  /// A rider is carrying it. Sellers see "On route".
  onTheWay('On the way'),
  delivered('Delivered'),

  /// Terminal unhappy paths.
  cancelledByCustomer('You cancelled this order'),
  rejectedBySeller('Seller could not take this order');

  const OrderStatus(this.customerLabel);

  final String customerLabel;

  bool get isTerminal =>
      this == OrderStatus.delivered ||
      this == OrderStatus.cancelledByCustomer ||
      this == OrderStatus.rejectedBySeller;

  bool get isActive => !isTerminal;

  /// Ended without a delivery — cancelled or rejected.
  bool get isTerminalUnhappy =>
      this == OrderStatus.cancelledByCustomer ||
      this == OrderStatus.rejectedBySeller;

  /// The seller queue is grouped by these four buckets.
  String get sellerBucket => switch (this) {
    OrderStatus.pending => 'New',
    OrderStatus.accepted || OrderStatus.packed => 'Packing',
    OrderStatus.onTheWay => 'On route',
    _ => 'Done',
  };

  /// The action label on the seller's queue row — tapping advances the order.
  String get sellerActionLabel => switch (this) {
    OrderStatus.pending => 'Accept',
    OrderStatus.accepted => 'Packed',
    OrderStatus.packed => 'Sent',
    _ => 'Done',
  };

  /// The next status when a seller taps the action button.
  OrderStatus? get nextForSeller => switch (this) {
    OrderStatus.pending => OrderStatus.accepted,
    OrderStatus.accepted => OrderStatus.packed,
    OrderStatus.packed => OrderStatus.onTheWay,
    OrderStatus.onTheWay => OrderStatus.delivered,
    _ => null,
  };
}

/// How the customer chose to pay.
enum PaymentMethod {
  cash('Cash on delivery', 'Pay the rider at your door'),
  wallet('Aqua Mart Wallet', 'Balance held in the app'),
  jazzCash('JazzCash / Easypaisa', 'Confirm on your phone'),
  card('Debit / credit card', 'Add a card · takes a minute'),
  khata('Monthly account', 'Add to khata');

  const PaymentMethod(this.label, this.subtitle);

  final String label;
  final String subtitle;

  /// Cash is the only method the rider collects at the door.
  bool get isCollectedByRider => this == PaymentMethod.cash;

  /// Short label for dense rows (seller queue, rider run).
  String get shortLabel => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.wallet => 'Wallet',
    PaymentMethod.jazzCash => 'JazzCash',
    PaymentMethod.card => 'Card',
    PaymentMethod.khata => 'Khata',
  };
}
