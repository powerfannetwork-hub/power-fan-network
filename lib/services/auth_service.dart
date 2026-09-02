import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    final cleanUsername = username.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanReferral = referralCode?.trim();

    if (cleanUsername.isEmpty) {
      throw const AuthException('Username is required.');
    }

    if (cleanEmail.isEmpty) {
      throw const AuthException('Email is required.');
    }

    if (password.length < 6) {
      throw const AuthException(
        'Password must be at least 6 characters.',
      );
    }

    final response = await _supabase.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {
        'username': cleanUsername,
        'referral_code': cleanReferral ?? '',
      },
    );

    if (response.user == null) {
      throw const AuthException(
        'Registration failed. Please try again.',
      );
    }

    // Idan Supabase Confirm Email yana ON,
    // session zai kasance null.
    if (response.session == null) {
      throw const AuthException(
        'Email confirmation is enabled. Please disable Confirm email in Supabase Authentication settings.',
      );
    }

    return response;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw const AuthException('Email is required.');
    }

    if (password.isEmpty) {
      throw const AuthException('Password is required.');
    }

    final response = await _supabase.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );

    if (response.user == null || response.session == null) {
      throw const AuthException(
        'Login failed. Please check your email and password.',
      );
    }

    return response;
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw const AuthException('Email is required.');
    }

    await _supabase.auth.resetPasswordForEmail(cleanEmail);
  }
}
