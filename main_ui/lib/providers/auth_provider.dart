import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'user_provider.dart';

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier(this.ref) : super(null);

  final Ref ref;

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> loginWithEmail(String email, String password) async {
    await AuthService.passwordLogin(email, password);
    await _fetchAndSetUser();
  }

  Future<void> loginWithOtp(String phoneNumber, String otp) async {
    await AuthService.verifyOtp(phoneNumber, otp);
    await _fetchAndSetUser();
  }

  Future<void> requestOtp(String phoneNumber) =>
      AuthService.requestOtp(phoneNumber);

  // ── Register ──────────────────────────────────────────────────────────────

  Future<void> register(
    String name,
    String email,
    String password, {
    String? address,
    String? phoneNumber,
    String? voterId,
  }) async {
    await AuthService.register(name, email, password,
        address: address, phoneNumber: phoneNumber, voterId: voterId);
    await _fetchAndSetUser();
  }

  // ── Password Reset ────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) =>
      ApiService.post('/auth/forgot-password', {'email': email});

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await AuthService.clearToken();
      ApiService.clearAuthToken();
    } finally {
      state = null;
      ref.read(userNotifierProvider.notifier).setUser(null);
      ref.invalidate(userNotifierProvider);
      ref.invalidateSelf();
    }
  }

  // ── Session check ─────────────────────────────────────────────────────────

  Future<void> checkAuth() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        state = user;
        ref.read(userNotifierProvider.notifier).setUser(user);
      } else {
        await logout();
      }
    } catch (_) {
      await logout();
    }
  }

  Future<void> processNewToken(String token) async {
    try {
      await AuthService.storeToken(token);
      await _fetchAndSetUser();
    } catch (_) {
      await logout();
      rethrow;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _fetchAndSetUser() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      await logout();
      return;
    }
    state = user;
    ref.read(userNotifierProvider.notifier).setUser(user);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, User?>((ref) => AuthNotifier(ref));
