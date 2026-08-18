@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:aqua_mart/core/network/api_client.dart';
import 'package:aqua_mart/core/network/api_environment.dart';
import 'package:aqua_mart/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:aqua_mart/features/auth/domain/entities/user_role.dart';
import 'package:aqua_mart/features/auth/domain/repositories/auth_repository.dart';
import 'package:dio/dio.dart';

/// Drives the REAL data sources against a running bench.
///
/// Excluded from `flutter test` by its tag, because it needs a live backend:
///     flutter test test/live --tags live
void main() {
  final client = ApiClient();

  // A fresh number per TEST: the code is single-use and re-requesting one for
  // the same number inside the resend window is (correctly) throttled.
  // The backend stores E.164 and accepts only `+92` + 10 digits starting
  // with 3, so the suffix is padded to exactly 9 digits after the leading 3.
  var seq = 0;
  String freshPhone() {
    final n = (DateTime.now().microsecondsSinceEpoch + seq++) % 1000000000;
    return '+923${n.toString().padLeft(9, '0')}';
  }

  test('requestOtp hits the live API and returns the resend window', () async {
    final auth = AuthApiDataSource(client);

    final seconds = await auth.requestOtp(freshPhone());

    // The value comes from under `data`, so a non-zero answer proves the
    // envelope was unwrapped rather than defaulted.
    expect(seconds, greaterThan(0));
  });

  test('verifyOtp returns top-level tokens and a parsed user', () async {
    final auth = AuthApiDataSource(client);
    final phone = freshPhone();
    await auth.requestOtp(phone);

    final result = await auth.verifyOtp(
      phone: phone,
      code: '472901', // Aqua Settings → fixed dev code
      draft: const SignUpDraft(fullName: 'Live Dart', role: UserRole.customer),
    );

    expect(result.accessToken, isNotEmpty);
    expect(result.refreshToken, isNotEmpty);
    expect(result.user.phone, phone);
    expect(result.user.role, 'customer');
  });

  test('a bad code surfaces the server sentence, not a crash', () async {
    final auth = AuthApiDataSource(client);
    final other = freshPhone();
    await auth.requestOtp(other);

    await expectLater(
      auth.verifyOtp(
        phone: other,
        code: '000000',
        draft: const SignUpDraft(role: UserRole.customer),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('the environment points at the bench', () {
    expect(ApiEnvironment.baseUrl, contains('/v1'));
    expect(ApiEnvironment.siteName, isNotEmpty);
  });

  test('the seller dashboard carries the store\'s own name', () async {
    final auth = AuthApiDataSource(client);
    final phone = freshPhone();
    await auth.requestOtp(phone);
    final session = await auth.verifyOtp(
      phone: phone,
      code: '472901',
      draft: const SignUpDraft(fullName: 'Owner', role: UserRole.seller),
    );

    // A client carrying this brand-new seller's token.
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiEnvironment.baseUrl,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'X-Frappe-Site-Name': ApiEnvironment.siteName,
        },
      ),
    );
    await dio.post<dynamic>(
      '/seller/register',
      data: {
        'business_name': 'Live Dart Water Co',
        'owner_name': 'Owner',
        'business_type': 'roPlant',
      },
    );

    // The dashboard requires an approved store. Unapproved, it must 403 —
    // the guarantee the waiting-room gate depends on.
    await expectLater(
      dio.get<dynamic>('/seller/dashboard'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          403,
        ),
      ),
    );
  });

  test('a customer with NO address still sees every seller', () async {
    final auth = AuthApiDataSource(client);
    final phone = freshPhone();
    await auth.requestOtp(phone);
    final session = await auth.verifyOtp(
      phone: phone,
      code: '472901',
      draft: const SignUpDraft(fullName: 'Fresh', role: UserRole.customer),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: ApiEnvironment.baseUrl,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'X-Frappe-Site-Name': ApiEnvironment.siteName,
        },
      ),
    );

    // Brand-new account: no addresses at all.
    final addresses = await dio.get<Map<String, dynamic>>('/addresses');
    expect(addresses.data!['data'], isEmpty);

    // The shelf must NOT be empty just because of that.
    final sellers = await dio.get<Map<String, dynamic>>('/sellers');
    final list = sellers.data!['data'] as List;
    expect(
      list,
      isNotEmpty,
      reason: 'an address-less customer must still see sellers',
    );

    // And they must be plottable, or the map stays blank.
    final plottable = list.where(
      (s) => (s as Map)['latitude'] != null && s['longitude'] != null,
    );
    expect(plottable, isNotEmpty, reason: 'sellers need coordinates to plot');
  });
}
