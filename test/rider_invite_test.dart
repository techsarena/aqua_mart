import 'package:aqua_mart/features/seller/data/datasources/seller_data_source.dart';
import 'package:aqua_mart/features/seller/domain/entities/rider_invite.dart';
import 'package:aqua_mart/features/seller/presentation/providers/seller_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Only the invite calls are exercised; everything else throws so an
/// unexpected fetch fails loudly rather than returning a silent empty list.
class _FakeSellerDataSource implements SellerRemoteDataSource {
  _FakeSellerDataSource({List<RiderInvite>? invites})
    : invites = invites ?? <RiderInvite>[];

  List<RiderInvite> invites;
  final sent = <String>[];
  final resent = <String>[];
  final cancelled = <String>[];

  @override
  Future<String> fetchRiderCode() async => 'CHS42K';

  @override
  Future<List<RiderInvite>> fetchRiderInvites() async => invites;

  @override
  Future<RiderInvite> inviteRider(String phone) async {
    sent.add(phone);
    final invite = RiderInvite(
      id: 'INV-${sent.length}',
      // The server normalises what the seller typed — the fake must too, or
      // the test would prove a round-trip the real API does not do.
      phone: '+92${phone.replaceFirst(RegExp('^0'), '')}',
      sentAt: DateTime.now(),
      daysLeft: 7,
    );
    invites = [invite, ...invites];
    return invite;
  }

  @override
  Future<RiderInvite> resendInvite(String inviteId) async {
    resent.add(inviteId);
    return invites.firstWhere((i) => i.id == inviteId);
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    cancelled.add(inviteId);
    invites = invites.where((i) => i.id != inviteId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  group('RiderInvite', () {
    final sentAt = DateTime(2026, 8, 19, 9);

    test('prints the phone in the local 0300 form the design shows', () {
      final invite = RiderInvite(
        id: 'INV-1',
        phone: '+923015528841',
        sentAt: sentAt,
      );
      expect(invite.phoneLabel, '0301 552 8841');
    });

    test('leaves a number it cannot parse exactly as it arrived', () {
      final invite = RiderInvite(
        id: 'INV-1',
        phone: 'not-a-number',
        sentAt: sentAt,
      );
      expect(invite.phoneLabel, 'not-a-number');
    });

    test('a fresh invite reads "just now" and hides the expiry', () {
      final invite = RiderInvite(id: 'INV-1', phone: '+923015528841',
          sentAt: sentAt, daysLeft: 7);
      expect(invite.subtitle(now: sentAt), 'Sent just now');
    });

    test('an aged invite reads in days and shows what is left', () {
      final invite = RiderInvite(id: 'INV-1', phone: '+923334197702',
          sentAt: sentAt, daysLeft: 5);
      expect(
        invite.subtitle(now: sentAt.add(const Duration(days: 2))),
        'Sent 2 days ago · expires in 5',
      );
    });

    test('singular day, so it never reads "1 days ago"', () {
      final invite = RiderInvite(id: 'INV-1', phone: '+923334197702',
          sentAt: sentAt, daysLeft: 6);
      expect(
        invite.subtitle(now: sentAt.add(const Duration(days: 1))),
        'Sent 1 day ago · expires in 6',
      );
    });
  });

  group('RiderInvitesNotifier', () {
    ProviderContainer containerWith(_FakeSellerDataSource fake) {
      final container = ProviderContainer(
        overrides: [sellerDataSourceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('sending an invite refreshes the waiting list', () async {
      final fake = _FakeSellerDataSource();
      final container = containerWith(fake);

      await container.read(riderInvitesProvider.future);
      final result = await container
          .read(riderInvitesProvider.notifier)
          .invite('03015528841');

      expect(result.isSuccess, isTrue);
      expect(fake.sent, ['03015528841']);
      expect(await container.read(riderInvitesProvider.future), hasLength(1));
    });

    test('cancelling drops the row from the list', () async {
      final fake = _FakeSellerDataSource(
        invites: [
          RiderInvite(
            id: 'INV-9',
            phone: '+923334197702',
            sentAt: DateTime(2026, 8, 17),
            daysLeft: 5,
          ),
        ],
      );
      final container = containerWith(fake);

      await container.read(riderInvitesProvider.future);
      await container.read(riderInvitesProvider.notifier).cancel('INV-9');

      expect(fake.cancelled, ['INV-9']);
      expect(await container.read(riderInvitesProvider.future), isEmpty);
    });

    test('a failing send surfaces the failure instead of swallowing it',
        () async {
      final fake = _ThrowingDataSource();
      final container = containerWith(fake);

      final result =
          await container.read(riderInvitesProvider.notifier).invite('0301');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.message, isNotEmpty);
    });
  });
}

class _ThrowingDataSource extends _FakeSellerDataSource {
  @override
  Future<RiderInvite> inviteRider(String phone) async =>
      throw Exception('network is down');
}
