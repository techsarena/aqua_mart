import 'dart:convert';

import 'package:aqua_mart/app.dart';
import 'package:aqua_mart/core/localization/app_language.dart';
import 'package:aqua_mart/core/providers/core_providers.dart';
import 'package:aqua_mart/core/router/app_routes.dart';
import 'package:aqua_mart/core/utils/result.dart';
import 'package:aqua_mart/features/auth/domain/entities/app_user.dart';
import 'package:aqua_mart/features/auth/domain/entities/user_role.dart';
import 'package:aqua_mart/features/auth/domain/repositories/auth_repository.dart';
import 'package:aqua_mart/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RestoredAuthRepository implements AuthRepository {
  const _RestoredAuthRepository(this.user);

  final AppUser user;

  @override
  Future<Result<AppUser?>> currentUser() async => Result.success(user);

  @override
  Future<Result<AppUser>> completeProfile(SignUpDraft draft) async =>
      Result.success(user);

  @override
  Future<Result<int>> requestOtp(String phone) async =>
      const Result.success(60);

  @override
  Future<Result<void>> signOut() async => const Result.success(null);

  @override
  Future<Result<OtpVerification>> verifyOtp({
    required String phone,
    required String code,
    required SignUpDraft draft,
  }) async => Result.success(OtpVerification(user: user, isNewUser: false));
}

void main() {
  testWidgets(
    'cold start restores the exact seller registration step and draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app.language': AppLanguage.english.code,
        'app.role': UserRole.seller.name,
        'registration.route': AppRoutes.sellerOnboardingPath,
        'registration.seller_draft': jsonEncode({
          'business_name': 'Chashma Pure Water',
          'owner_name': 'Ali Raza',
          'business_type': 'roPlant',
          'uploaded': <String>[],
          'bottles': <Object>[],
          'sells_other_sizes': false,
          'status': 'detailsReceived',
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      const user = AppUser(
        id: 'new-seller',
        fullName: '',
        phone: '+923001234567',
        role: UserRole.seller,
        isProfileComplete: false,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(
            const _RestoredAuthRepository(user),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AquaMartApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your water business'), findsOneWidget);
      final restoredValues = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .map((field) => field.controller.text);
      expect(restoredValues, containsAll(['Chashma Pure Water', 'Ali Raza']));
      expect(
        container.read(sessionProvider).registrationRoute,
        AppRoutes.sellerOnboardingPath,
      );
    },
  );
}
