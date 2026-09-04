// lib/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String username,
    String? referralCode,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanUsername = username.trim();
      final cleanReferral = referralCode?.trim();

      if (cleanEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      if (cleanUsername.isEmpty) {
        throw Exception('Username is required.');
      }

      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'username': cleanUsername,
          if (cleanReferral != null && cleanReferral.isNotEmpty)
            'referral_code': cleanReferral,
        },
      );

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      if (newPassword.length < 6) {
        throw Exception('Password must be at least 6 characters.');
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
