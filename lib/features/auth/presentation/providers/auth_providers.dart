import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthApiDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  ),
);

/// Everything the router needs to decide where a person belongs.
class SessionState {
  const SessionState({
    this.user,
    this.language,
    this.pendingRole,
    this.draft = const SignUpDraft(),
    this.registrationRoute,
    this.isLoading = true,
  });

  final AppUser? user;

  /// Null until the language screen is answered.
  final AppLanguage? language;

  /// The role picked on the "Who are you?" screen, before an account exists.
  final UserRole? pendingRole;

  /// Collected across the three sign-up steps.
  final SignUpDraft draft;
  final String? registrationRoute;
  final bool isLoading;

  bool get isSignedIn => user != null;
  bool get hasLanguage => language != null;

  /// The role that decides which shell to show.
  UserRole get activeRole => user?.isProfileComplete == false
      ? pendingRole ?? user!.role
      : user?.role ?? pendingRole ?? UserRole.customer;

  SessionState copyWith({
    AppUser? user,
    AppLanguage? language,
    UserRole? pendingRole,
    SignUpDraft? draft,
    String? registrationRoute,
    bool? isLoading,
    bool clearUser = false,
    bool clearRegistrationRoute = false,
  }) => SessionState(
    user: clearUser ? null : (user ?? this.user),
    language: language ?? this.language,
    pendingRole: pendingRole ?? this.pendingRole,
    draft: draft ?? this.draft,
    registrationRoute: clearRegistrationRoute
        ? null
        : (registrationRoute ?? this.registrationRoute),
    isLoading: isLoading ?? this.isLoading,
  );
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    _restore();
    final prefs = ref.read(appPreferencesProvider);
    return SessionState(
      language: prefs.language,
      pendingRole: prefs.role,
      draft: _readDraft(prefs.signUpDraft),
      registrationRoute: prefs.registrationRoute,
      isLoading: true,
    );
  }

  SignUpDraft _readDraft(String? value) {
    if (value == null || value.isEmpty) return const SignUpDraft();
    try {
      return SignUpDraft.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return const SignUpDraft();
    }
  }

  Future<void> _restore() async {
    final result = await ref.read(authRepositoryProvider).currentUser();
    state = result.when(
      success: (user) {
        _openSocket();
        return state.copyWith(user: user, isLoading: false);
      },
      failure: (_) => state.copyWith(isLoading: false),
    );
  }

  /// The socket carries a token, so it can only open once one exists — on
  /// restore and on sign-in, never at app start (API_SPEC 8.2).
  void _openSocket() {
    // Fire-and-forget: a socket that fails to open must never block sign-in,
    // because every screen still works without it (8.6).
    unawaited(ref.read(socketClientProvider).connect());
  }

  Future<void> setLanguage(AppLanguage language) async {
    await ref.read(appPreferencesProvider).setLanguage(language);
    state = state.copyWith(language: language);
  }

  Future<void> setRole(UserRole role) async {
    final prefs = ref.read(appPreferencesProvider);
    await prefs.setRole(role);
    final draft = state.draft.copyWith(role: role);
    state = state.copyWith(pendingRole: role, draft: draft);
    await prefs.setSignUpDraft(jsonEncode(draft.toJson()));
  }

  void updateDraft(SignUpDraft Function(SignUpDraft) update) {
    final draft = update(state.draft);
    state = state.copyWith(draft: draft);
    unawaited(
      ref
          .read(appPreferencesProvider)
          .setSignUpDraft(jsonEncode(draft.toJson())),
    );
  }

  /// Marks the OTP-created session as resumable before leaving the OTP screen.
  void beginRegistration(AppUser user, String route) {
    state = state.copyWith(
      user: user,
      registrationRoute: route,
      isLoading: false,
    );
    unawaited(ref.read(appPreferencesProvider).setRegistrationRoute(route));
    _openSocket();
  }

  /// Called by each registration route, including after a back navigation.
  void checkpointRegistration(String route) {
    if (state.registrationRoute == route) return;
    state = state.copyWith(registrationRoute: route);
    unawaited(ref.read(appPreferencesProvider).setRegistrationRoute(route));
  }

  Future<void> completeRegistration() async {
    await ref.read(appPreferencesProvider).clearRegistrationProgress();
    state = state.copyWith(clearRegistrationRoute: true);
  }

  void signIn(AppUser user) {
    state = state.copyWith(user: user, isLoading: false);
    _openSocket();
  }

  Future<void> signOut() async {
    // Drop the socket before the tokens go, so the server sees a clean
    // disconnect rather than an auth failure on the next emit.
    ref.read(socketClientProvider).disconnect();
    await ref.read(authRepositoryProvider).signOut();
    await ref.read(appPreferencesProvider).clear();
    state = const SessionState(isLoading: false);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Convenience selector — the signed-in user, or the fixture customer while
/// the mock backend is in play.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(sessionProvider).user,
);
