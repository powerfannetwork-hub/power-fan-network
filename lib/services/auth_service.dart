import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String username,
    String? referralCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();

    if (cleanEmail.isEmpty) {
      throw const AuthException('Please enter your email address.');
    }

    if (cleanUsername.isEmpty) {
      throw const AuthException('Please enter a username.');
    }

    if (password.length < 6) {
      throw const AuthException(
        'Password must be at least 6 characters.',
      );
    }

    // Check username before creating the account.
    final existing = await _supabase
        .from('profiles')
        .select('id')
        .ilike('username', cleanUsername)
        .limit(1);

    if (existing.isNotEmpty) {
      throw const AuthException('This username is already taken.');
    }

    final response = await _supabase.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {
        'username': cleanUsername,
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referral_code': referralCode.trim().toUpperCase(),
      },
    );

    // If email confirmation is disabled in Supabase,
    // a session is returned immediately.
    if (response.user == null) {
      throw const AuthException(
        'Account could not be created. Please try again.',
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
      throw const AuthException('Please enter your email address.');
    }

    if (password.isEmpty) {
      throw const AuthException('Please enter your password.');
    }

    return await _supabase.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
