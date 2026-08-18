import 'package:aqua_mart/features/auth/domain/entities/app_user.dart';
import 'package:aqua_mart/features/auth/domain/entities/user_role.dart';
import 'package:aqua_mart/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// After OTP, where a person lands is decided by `activeRole`, and a returning
/// account's role must come from the SERVER — not from a role they tapped in
/// some earlier, abandoned sign-up.
void main() {
  const seller = AppUser(
    id: 'u-1',
    fullName: 'Returning Seller',
    phone: '+923001234567',
    role: UserRole.seller,
  );

  test('a returning account uses its server role, not a stale local one', () {
    // Someone tapped "I sell water" before, then signed in as a customer.
    const stale = SessionState(
      pendingRole: UserRole.seller,
      isLoading: false,
    );

    const customer = AppUser(
      id: 'u-2',
      fullName: 'Returning Customer',
      phone: '+923009999999',
      role: UserRole.customer,
    );

    final signedIn = stale.copyWith(
      user: customer,
      pendingRole: customer.role,
    );

    expect(signedIn.activeRole, UserRole.customer);
  });

  test('each role resolves to its own shell', () {
    for (final role in UserRole.values) {
      final user = AppUser(
        id: 'u',
        fullName: 'X',
        phone: '+923000000000',
        role: role,
      );
      final state = SessionState(isLoading: false).copyWith(
        user: user,
        pendingRole: user.role,
      );
      expect(state.activeRole, role, reason: '$role must keep its own shell');
    }
  });

  test('an unfinished account still follows the role it is registering as',
      () {
    // is_profile_complete == false: the person is mid-sign-up, so the role
    // they picked drives the remaining steps.
    const partial = AppUser(
      id: 'u-3',
      fullName: '',
      phone: '+923001111111',
      role: UserRole.customer,
      isProfileComplete: false,
    );
    const state = SessionState(
      user: partial,
      pendingRole: UserRole.rider,
      isLoading: false,
    );
    expect(state.activeRole, UserRole.rider);
  });

  test('clearPendingRole drops a stale choice outright', () {
    const state = SessionState(
      pendingRole: UserRole.seller,
      isLoading: false,
    );
    expect(state.copyWith(clearPendingRole: true).pendingRole, isNull);
    // Sanity: without the flag, null does NOT clear it.
    expect(state.copyWith().pendingRole, UserRole.seller);
  });

  test('a signed-in seller reports the seller shell', () {
    final state = SessionState(isLoading: false).copyWith(
      user: seller,
      pendingRole: seller.role,
    );
    expect(state.isSignedIn, isTrue);
    expect(state.activeRole, UserRole.seller);
  });
}
