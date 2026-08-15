import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  if (useMockData) return MockAuthDataSource(ref.watch(tokenStorageProvider));
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
    this.isLoading = true,
  });

  final AppUser? user;

  /// Null until the language screen is answered.
  final AppLanguage? language;

  /// The role picked on the "Who are you?" screen, before an account exists.
  final UserRole? pendingRole;

  /// Collected across the three sign-up steps.
  final SignUpDraft draft;
  final bool isLoading;

  bool get isSignedIn => user != null;
  bool get hasLanguage => language != null;

  /// The role that decides which shell to show.
  UserRole get activeRole => user?.role ?? pendingRole ?? UserRole.customer;

  SessionState copyWith({
    AppUser? user,
    AppLanguage? language,
    UserRole? pendingRole,
    SignUpDraft? draft,
    bool? isLoading,
    bool clearUser = false,
  }) => SessionState(
    user: clearUser ? null : (user ?? this.user),
    language: language ?? this.language,
    pendingRole: pendingRole ?? this.pendingRole,
    draft: draft ?? this.draft,
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
      isLoading: true,
    );
  }

  Future<void> _restore() async {
    final result = await ref.read(authRepositoryProvider).currentUser();
    state = result.when(
      success: (user) => state.copyWith(user: user, isLoading: false),
      failure: (_) => state.copyWith(isLoading: false),
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    await ref.read(appPreferencesProvider).setLanguage(language);
    state = state.copyWith(language: language);
  }

  Future<void> setRole(UserRole role) async {
    await ref.read(appPreferencesProvider).setRole(role);
    state = state.copyWith(
      pendingRole: role,
      draft: state.draft.copyWith(role: role),
    );
  }

  void updateDraft(SignUpDraft Function(SignUpDraft) update) =>
      state = state.copyWith(draft: update(state.draft));

  void signIn(AppUser user) =>
      state = state.copyWith(user: user, isLoading: false);

  Future<void> signOut() async {
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
