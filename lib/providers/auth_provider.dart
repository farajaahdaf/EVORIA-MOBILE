import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final loggedIn = await _repo.isLoggedIn();
      if (!loggedIn) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      // Validate token against server — detects expired/revoked tokens
      final user = await _repo.getProfile();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Token invalid or server unreachable → force logout
      await _repo.logout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(email, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.register(name, email, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _repo.getProfile();
      if (user != null) state = state.copyWith(user: user);
    } catch (_) {}
  }

  /// Update profile info (name, email) + optional avatar photo.
  /// Throws on failure so the caller can surface validation messages.
  Future<void> updateProfile({
    required String name,
    required String email,
    String? photoPath,
    bool removePhoto = false,
  }) async {
    final user = await _repo.updateProfile(
      name: name,
      email: email,
      photoPath: photoPath,
      removePhoto: removePhoto,
    );
    state = state.copyWith(user: user);
  }

  /// Change the account password. Throws on failure.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _repo.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  /// Permanently delete the account, then drop to unauthenticated.
  /// Throws on failure (e.g. wrong password) so the caller can surface it.
  Future<void> deleteAccount({required String password}) async {
    await _repo.deleteAccount(password: password);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
