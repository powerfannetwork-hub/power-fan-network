import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  User? get currentUser =>
      _supabase.auth.currentUser;

  Session? get currentSession =>
      _supabase.auth.currentSession;

  bool get isLoggedIn =>
      _supabase.auth.currentSession != null;

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
    final cleanReferral =
        referralCode?.trim().toUpperCase();

    if (cleanUsername.isEmpty) {
      throw const AuthException(
        'Username is required.',
      );
    }

    if (cleanEmail.isEmpty) {
      throw const AuthException(
        'Email is required.',
      );
    }

    if (password.length < 6) {
      throw const AuthException(
        'Password must be at least 6 characters.',
      );
    }

    try {
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

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        _cleanError(e),
      );
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail =
        email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw const AuthException(
        'Email is required.',
      );
    }

    if (password.isEmpty) {
      throw const AuthException(
        'Password is required.',
      );
    }

    try {
      final response =
          await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (response.user == null ||
          response.session == null) {
        throw const AuthException(
          'Login failed. Please check your email and password.',
        );
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        _cleanError(e),
      );
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<void> resetPassword(
    String email,
  ) async {
    final cleanEmail =
        email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      throw const AuthException(
        'Email is required.',
      );
    }

    await _supabase.auth.resetPasswordForEmail(
      cleanEmail,
    );
  }

  Future<void> refreshSession() async {
    if (_supabase.auth.currentSession == null) {
      return;
    }

    await _supabase.auth.refreshSession();
  }

  String _cleanError(Object error) {
    var message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    if (message.startsWith('AuthException: ')) {
      message = message.substring(14);
    }

    return message.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : message.trim();
  }
}
