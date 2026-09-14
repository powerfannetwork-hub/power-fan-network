// lib/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import 'referral_service.dart';

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
        'registration_notice_presented': true,
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

      // ----------------------------------------------------------
      // ACCEPT REGISTRATION NOTICE
      // ----------------------------------------------------------

      if (response.session != null) {
        await acceptRegistrationNotice();

        // --------------------------------------------------------
        // APPLY REGISTRATION REFERRAL
        // --------------------------------------------------------
        //
        // When a session is available immediately, apply the
        // referral code directly after registration.
        //
        // The referral code is already stored in the user's
        // Supabase auth metadata by signUp().
        // --------------------------------------------------------

        await _applyPendingReferral(response.user);
      }

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

      // ----------------------------------------------------------
      // REGISTRATION NOTICE
      // ----------------------------------------------------------

      if (response.session != null) {
        try {
          await acceptRegistrationNotice();
        } catch (_) {
          // Do not block a valid login if saving the notice
          // temporarily fails.
        }
      }

      // ----------------------------------------------------------
      // PENDING REGISTRATION REFERRAL
      // ----------------------------------------------------------
      //
      // If email confirmation was enabled during registration,
      // signUp() may have returned no session.
      //
      // The referral code remains in auth metadata.
      //
      // After the user confirms the email and logs in, apply
      // the referral automatically here.
      // ----------------------------------------------------------

      if (response.session != null) {
        await _applyPendingReferral(response.user);
      }

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
  // APPLY PENDING REGISTRATION REFERRAL
  // ============================================================

  Future<void> _applyPendingReferral(
    User? user,
  ) async {
    if (user == null) {
      return;
    }

    try {
      final metadata = user.userMetadata;

      if (metadata == null) {
        return;
      }

      final rawReferralCode =
          metadata['referral_code'];

      if (rawReferralCode == null) {
        return;
      }

      final referralCode =
          rawReferralCode.toString().trim().toUpperCase();

      if (referralCode.isEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // CHECK CURRENT PROFILE
      // ----------------------------------------------------------
      //
      // If referred_by is already set, the referral has already
      // been applied. Never try to apply another referral.
      // ----------------------------------------------------------

      final profile =
          await _supabase
              .from('profiles')
              .select('referred_by')
              .eq('id', user.id)
              .maybeSingle();

      if (profile == null) {
        return;
      }

      final existingReferredBy =
          profile['referred_by'];

      if (existingReferredBy != null &&
          existingReferredBy.toString().trim().isNotEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // APPLY REFERRAL
      // ----------------------------------------------------------

      final result =
          await ReferralService.instance
              .applyReferralCode(referralCode);

      // ----------------------------------------------------------
      // SUCCESS
      // ----------------------------------------------------------
      //
      // No UI is required here.
      //
      // The referral service is responsible for:
      // - validating the referral code
      // - setting referred_by
      // - creating referral relationship/reward data
      // - updating referral statistics
      //
      // The user simply continues into the app.
      // ----------------------------------------------------------

      if (!result.success) {
        return;
      }
    } catch (_) {
      // Referral failure must not destroy a valid account login.
      //
      // The registration/login itself remains successful.
      // The referral is only applied when the server accepts it.
    }
  }

  // ============================================================
  // ACCEPT REGISTRATION NOTICE
  // ============================================================

  Future<Map<String, dynamic>>
      acceptRegistrationNotice() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        return <String, dynamic>{
          'success': false,
          'message': 'Authentication required',
        };
      }

      final result = await _supabase.rpc(
        'accept_registration_notice',
      );

      if (result is Map<String, dynamic>) {
        return result;
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      throw Exception(
        'Invalid response from accept_registration_notice.',
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(e.toString());
    }
  }

  // ============================================================
  // ACCOUNT SECURITY STATUS
  // ============================================================

  Future<Map<String, dynamic>>
      getAccountSecurityStatus() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        return <String, dynamic>{
          'success': false,
          'message': 'Authentication required',
        };
      }

      final result = await _supabase.rpc(
        'get_account_security_status',
      );

      if (result is Map<String, dynamic>) {
        return result;
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      throw Exception(
        'Invalid response from get_account_security_status.',
      );
    } on PostgrestException catch (e) {
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
