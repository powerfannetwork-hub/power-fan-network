// lib/services/auth_service.dart

import 'dart:convert';

import 'package:http/http.dart' as http;
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
      // COUNTRY DETECTION
      // ----------------------------------------------------------
      //
      // This uses the user's public IP.
      //
      // IMPORTANT:
      // - No GPS is used.
      // - No location permission is requested.
      // - If detection fails, registration continues normally.
      //
      // The detected country is stored in Supabase Auth metadata
      // and then synced to public.profiles.country.
      // ----------------------------------------------------------

      final String? country = await _detectCountry();

      // ----------------------------------------------------------
      // SUPABASE SIGN UP
      // ----------------------------------------------------------

      final Map<String, dynamic> metadata =
          <String, dynamic>{
        'username': cleanUsername,
        'registration_notice_presented': true,
      };

      if (country != null && country.isNotEmpty) {
        metadata['country'] = country;
      }

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
      // IF SESSION EXISTS IMMEDIATELY
      // ----------------------------------------------------------

      if (response.session != null) {
        await acceptRegistrationNotice();

        await _syncCountryToProfile(
          response.user,
          country,
        );

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
      // COUNTRY SYNC
      // ----------------------------------------------------------
      //
      // If registration happened with email confirmation enabled,
      // there may have been no session during signUp().
      //
      // When the user logs in later, we try to make sure the
      // country is present in public.profiles.
      // ----------------------------------------------------------

      if (response.session != null) {
        await _syncCountryAfterLogin(response.user);

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
  // COUNTRY DETECTION
  // ============================================================

  Future<String?> _detectCountry() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://ipapi.co/json/'),
          )
          .timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final dynamic countryCode =
          decoded['country_code'];

      if (countryCode == null) {
        return null;
      }

      final country =
          countryCode.toString().trim().toUpperCase();

      // Country codes should be exactly two letters.
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
        return null;
      }

      return country;
    } catch (_) {
      // Country detection must NEVER prevent registration.
      return null;
    }
  }

  // ============================================================
  // SYNC COUNTRY TO PROFILE
  // ============================================================

  Future<void> _syncCountryToProfile(
    User? user,
    String? detectedCountry,
  ) async {
    if (user == null) {
      return;
    }

    try {
      String? country = detectedCountry;

      // --------------------------------------------------------
      // FIRST: use country detected during registration/login.
      // --------------------------------------------------------

      if (country == null || country.isEmpty) {
        final metadata = user.userMetadata;

        final metadataCountry =
            metadata?['country'];

        if (metadataCountry != null) {
          country = metadataCountry
              .toString()
              .trim()
              .toUpperCase();
        }
      }

      // --------------------------------------------------------
      // SECOND: if still unavailable, detect again.
      // --------------------------------------------------------

      if (country == null || country.isEmpty) {
        country = await _detectCountry();
      }

      if (country == null || country.isEmpty) {
        return;
      }

      // --------------------------------------------------------
      // CHECK PROFILE
      // --------------------------------------------------------

      final profile = await _supabase
          .from('profiles')
          .select('country')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Do not create a profile here.
        //
        // The existing profile creation system remains
        // responsible for creating profiles.
        return;
      }

      final existingCountry =
          profile['country'];

      // --------------------------------------------------------
      // DO NOT OVERWRITE A VALID COUNTRY.
      // --------------------------------------------------------

      if (existingCountry != null &&
          existingCountry
              .toString()
              .trim()
              .isNotEmpty) {
        return;
      }

      // --------------------------------------------------------
      // SAVE COUNTRY
      // --------------------------------------------------------

      await _supabase
          .from('profiles')
          .update(<String, dynamic>{
        'country': country,
      }).eq('id', user.id);
    } catch (_) {
      // Country syncing must NEVER break registration/login.
    }
  }

  // ============================================================
  // COUNTRY SYNC AFTER LOGIN
  // ============================================================

  Future<void> _syncCountryAfterLogin(
    User? user,
  ) async {
    if (user == null) {
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('country')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return;
      }

      final existingCountry =
          profile['country'];

      // Country already exists.
      if (existingCountry != null &&
          existingCountry
              .toString()
              .trim()
              .isNotEmpty) {
        return;
      }

      await _syncCountryToProfile(
        user,
        null,
      );
    } catch (_) {
      // Never block login.
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
          rawReferralCode
              .toString()
              .trim()
              .toUpperCase();

      if (referralCode.isEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // CHECK CURRENT PROFILE
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
          existingReferredBy
              .toString()
              .trim()
              .isNotEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // APPLY REFERRAL
      // ----------------------------------------------------------

      final result =
          await ReferralService.instance
              .applyReferralCode(
        referralCode,
      );

      // ----------------------------------------------------------
      // SUCCESS
      // ----------------------------------------------------------

      if (!result.success) {
        return;
      }
    } catch (_) {
      // Referral failure must not destroy a valid account login.
    }
  }

  // ============================================================
  // ACCEPT REGISTRATION NOTICE
  // ============================================================

  Future<Map<String, dynamic>>
      acceptRegistrationNotice() async {
    try {
      final user =
          _supabase.auth.currentUser;

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
      final user =
          _supabase.auth.currentUser;

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
        redirectTo: 'powerfan://reset-password',
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
