/// Which app the signed-in person sees. Chosen on the "Who are you?" screen
/// and switchable later from settings.
enum UserRole {
  customer,
  seller,
  rider;

  String get title => switch (this) {
    UserRole.customer => 'I need water',
    UserRole.seller => 'I sell water',
    UserRole.rider => 'I deliver',
  };

  String get subtitle => switch (this) {
    UserRole.customer =>
      'Order bottles from sellers near you, pay cash or wallet.',
    UserRole.seller =>
      'List your bottles, set prices and areas, run your orders.',
    UserRole.rider => 'Rider — invited by a seller',
  };
}
