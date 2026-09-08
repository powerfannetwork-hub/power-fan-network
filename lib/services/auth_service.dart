// lib/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // AUTH STATE
  // ============================================================

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  bool get isLoggedIn => currentUser != null;

  // ============================================================
  // REGISTER
  // ============================================================

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

      // ----------------------------------------------------------
      // VALIDATION
      // ----------------------------------------------------------

      if (cleanEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      if (!_isValidEmail(cleanEmail)) {
        throw Exception('Please enter a valid email address.');
      }

      if (cleanUsername.isEmpty) {
        throw Exception('Username is required.');
      }

      if (cleanUsername.length < 3) {
        throw Exception(
          'Username must be at least 3 characters.',
        );
      }

      if (cleanUsername.length > 30) {
        throw Exception(
          'Username must not exceed 30 characters.',
        );
      }

      if (password.length < 6) {
        throw Exception(
          'Password must be at least 6 characters.',
        );
      }

      // ----------------------------------------------------------
      // SUPABASE SIGN UP
      // ----------------------------------------------------------

      final Map<String, dynamic> metadata =
          <String, dynamic>{
        'username': cleanUsername,
      };

      if (cleanReferral != null &&
          cleanReferral.isNotEmpty) {
        metadata['referral_code'] =
            cleanReferral.toUpperCase();
      }

      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: metadata,
      );

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail =
          email.trim().toLowerCase();

      if (cleanEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      if (!_isValidEmail(cleanEmail)) {
        throw Exception(
          'Please enter a valid email address.',
        );
      }

      if (password.isEmpty) {
        throw Exception('Password is required.');
      }

      final response =
          await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  Future<void> resetPassword(
    String email,
  ) async {
    try {
      final cleanEmail =
          email.trim().toLowerCase();

      if (cleanEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      if (!_isValidEmail(cleanEmail)) {
        throw Exception(
          'Please enter a valid email address.',
        );
      }

      await _supabase.auth.resetPasswordForEmail(
        cleanEmail,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // REFRESH SESSION
  // ============================================================

  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<void> updatePassword(
    String newPassword,
  ) async {
    try {
      if (newPassword.length < 6) {
        throw Exception(
          'Password must be at least 6 characters.',
        );
      }

      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // AUTH STATE CHANGES
  // ============================================================

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return emailRegex.hasMatch(email);
  }
}
