// lib/services/auth_service.dart
// ============================================================
// POWER FAN NETWORK
// SUPABASE AUTH SERVICE
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _user;

  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;

  User? get authUser => _supabase.auth.currentUser;

  bool get isAuthenticated =>
      _supabase.auth.currentSession != null;

  String get userId => authUser?.id ?? '';

  String get name =>
      (_user?['name'] ?? authUser?.userMetadata?['name'] ?? '')
          .toString();

  String get email =>
      authUser?.email ?? (_user?['email'] ?? '').toString();

  String get referralCode =>
      (_user?['referral_code'] ?? '').toString();

  String? get referredBy =>
      _user?['referred_by']?.toString();

  double get fanBalance =>
      _toDouble(_user?['fan_balance']);

  double get afamBalance =>
      _toDouble(_user?['afam_balance']);

  double get miningRate =>
      _toDouble(
        _user?['mining_rate'],
        fallback: 0.2,
      );

  int get activeReferrals =>
      _toInt(_user?['active_referrals']);

  int get dailyAdsWatched =>
      _toInt(_user?['daily_ads_watched']);

  double get adBoost =>
      _toDouble(_user?['ad_boost']);

  bool get miningActive =>
      _user?['mining_active'] == true;

  int get consecutiveCheckIns =>
      _toInt(_user?['consecutive_check_ins']);

  bool get kyc1Eligible =>
      _user?['kyc1_eligible'] == true;

  bool get kyc1Verified =>
      _user?['kyc1_verified'] == true;

  bool get kyc2Eligible =>
      _user?['kyc2_eligible'] == true;

  bool get kyc2Verified =>
      _user?['kyc2_verified'] == true;

  bool get kyc3Verified =>
      _user?['kyc3_verified'] == true;

  // ==========================================================
  // HELPERS
  // ==========================================================

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value == null) return fallback;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        fallback;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    _setLoading(true);
    _setError(null);

    try {
      final session =
          _supabase.auth.currentSession;

      if (session == null) {
        _user = null;
        return;
      }

      await refreshUser();
    } catch (error) {
      debugPrint(
        'AUTH INITIALIZE ERROR: $error',
      );
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final cleanName = name.trim();
      final cleanEmail =
          email.trim().toLowerCase();
      final cleanReferral =
          referralCode?.trim().toUpperCase();

      if (cleanName.length < 2) {
        _setError(
          'Name must contain at least 2 characters.',
        );
        return false;
      }

      if (password.length < 6) {
        _setError(
          'Password must contain at least 6 characters.',
        );
        return false;
      }

      final response =
          await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'name': cleanName,
          if (cleanReferral != null &&
              cleanReferral.isNotEmpty)
            'referral_code': cleanReferral,
        },
      );

      if (response.user == null) {
        _setError(
          'Registration failed.',
        );
        return false;
      }

      if (response.session != null) {
        await refreshUser();
      }

      _setError(null);
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (error) {
      debugPrint(
        'REGISTER ERROR: $error',
      );

      _setError(
        'Connection error. Please try again.',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final response =
          await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null ||
          response.session == null) {
        _setError(
          'Login failed.',
        );
        return false;
      }

      await refreshUser();

      _setError(null);
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (error) {
      debugPrint(
        'LOGIN ERROR: $error',
      );

      _setError(
        'Connection error. Please try again.',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // REFRESH USER
  // ==========================================================

  Future<bool> refreshUser() async {
    final currentUser =
        _supabase.auth.currentUser;

    if (currentUser == null) {
      _user = null;
      notifyListeners();
      return false;
    }

    try {
      final response =
          await _supabase
              .from('profiles')
              .select()
              .eq(
                'id',
                currentUser.id,
              )
              .maybeSingle();

      if (response != null) {
        _user =
            Map<String, dynamic>.from(
          response,
        );
      } else {
        _user = {
          'id': currentUser.id,
          'email': currentUser.email,
          'name':
              currentUser.userMetadata?['name'] ??
                  '',
        };
      }

      _setError(null);
      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'REFRESH USER ERROR: $error',
      );

      return false;
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (error) {
      debugPrint(
        'LOGOUT ERROR: $error',
      );
    }

    _user = null;
    _error = null;

    notifyListeners();
  }

  // ==========================================================
  // CHANGE PASSWORD
  // ==========================================================

  Future<bool> changePassword({
    required String newPassword,
  }) async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return false;
    }

    if (newPassword.length < 6) {
      _setError(
        'New password must contain at least 6 characters.',
      );
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      _setError(null);
      return true;
    } on AuthException catch (error) {
      _setError(error.message);
      return false;
    } catch (error) {
      debugPrint(
        'CHANGE PASSWORD ERROR: $error',
      );

      _setError(
        'Could not change password.',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================

  Future<bool> updateProfile({
    required String name,
  }) async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return false;
    }

    final cleanName = name.trim();

    if (cleanName.length < 2) {
      _setError(
        'Name is too short.',
      );
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'name': cleanName,
          },
        ),
      );

      await _supabase
          .from('profiles')
          .update({
        'name': cleanName,
        'updated_at':
            DateTime.now().toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await refreshUser();

      _setError(null);
      return true;
    } catch (error) {
      debugPrint(
        'UPDATE PROFILE ERROR: $error',
      );

      _setError(
        'Could not update profile.',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  Future<Map<String, dynamic>?> getDashboard() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final response =
          await _supabase
              .from('profiles')
              .select()
              .eq(
                'id',
                userId,
              )
              .maybeSingle();

      if (response == null) {
        return null;
      }

      _user =
          Map<String, dynamic>.from(
        response,
      );

      notifyListeners();

      return {
        'success': true,
        'user': _user,
        'rules': {
          'baseMiningRate': 0.2,
          'adBoostPerAd': 0.1,
          'maxDailyAds': 7,
          'maxAdBoost': 0.7,
          'referralMiningBoost': 0.02,
          'newUserReferralReward': 20,
          'inviterReferralReward': 5,
          'dailySocialReward': 10,
        },
      };
    } catch (error) {
      debugPrint(
        'DASHBOARD ERROR: $error',
      );
      return null;
    }
  }

  // ==========================================================
  // START MINING
  // ==========================================================

  Future<Map<String, dynamic>?> startMining() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return null;
    }

    try {
      final now = DateTime.now();
      final endsAt =
          now.add(
        const Duration(
          hours: 24,
        ),
      );

      await _supabase
          .from('profiles')
          .update({
        'mining_active': true,
        'mining_started_at':
            now.toIso8601String(),
        'mining_ends_at':
            endsAt.toIso8601String(),
        'updated_at':
            now.toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await refreshUser();

      _setError(null);

      return {
        'success': true,
        'message': 'Mining started.',
        'mining': {
          'active': true,
          'startedAt':
              now.toIso8601String(),
          'endsAt':
              endsAt.toIso8601String(),
          'miningRate':
              miningRate,
        },
      };
    } catch (error) {
      debugPrint(
        'START MINING ERROR: $error',
      );

      _setError(
        'Could not start mining.',
      );

      return null;
    }
  }

  // ==========================================================
  // CLAIM MINING
  // ==========================================================

  Future<Map<String, dynamic>?> claimMining() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return null;
    }

    try {
      final profile =
          await _supabase
              .from('profiles')
              .select()
              .eq(
                'id',
                userId,
              )
              .single();

      final active =
          profile['mining_active'] == true;

      final endsAtString =
          profile['mining_ends_at'];

      if (!active) {
        _setError(
          'Mining session is not active.',
        );
        return null;
      }

      if (endsAtString == null) {
        _setError(
          'Mining end time is missing.',
        );
        return null;
      }

      final endsAt =
          DateTime.parse(
        endsAtString.toString(),
      );

      if (DateTime.now().isBefore(endsAt)) {
        _setError(
          'Mining session has not ended yet.',
        );
        return null;
      }

      final rate =
          _toDouble(
        profile['mining_rate'],
        fallback: 0.2,
      );

      final reward = rate * 24;

      final currentBalance =
          _toDouble(
        profile['fan_balance'],
      );

      final newBalance =
          currentBalance + reward;

      final activeReferrals =
          _toInt(
        profile['active_referrals'],
      );

      final newRate =
          0.2 +
          activeReferrals * 0.02;

      await _supabase
          .from('profiles')
          .update({
        'fan_balance': newBalance,
        'mining_active': false,
        'mining_started_at': null,
        'mining_ends_at': null,
        'daily_ads_watched': 0,
        'ad_boost': 0,
        'mining_rate': newRate,
        'updated_at':
            DateTime.now().toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await refreshUser();

      _setError(null);

      return {
        'success': true,
        'message':
            'Mining reward claimed.',
        'reward': reward,
        'fanBalance': newBalance,
        'miningActive': false,
      };
    } catch (error) {
      debugPrint(
        'CLAIM MINING ERROR: $error',
      );

      _setError(
        'Could not claim mining reward.',
      );

      return null;
    }
  }

  // ==========================================================
  // REWARDED AD
  // ==========================================================

  Future<Map<String, dynamic>?> watchRewardedAd() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return null;
    }

    try {
      final profile =
          await _supabase
              .from('profiles')
              .select()
              .eq(
                'id',
                userId,
              )
              .single();

      final ads =
          _toInt(
        profile['daily_ads_watched'],
      );

      if (ads >= 7) {
        _setError(
          'You have reached the maximum of 7 rewarded ads today.',
        );
        return null;
      }

      final newAds = ads + 1;
      final newAdBoost =
          newAds * 0.1;

      final referrals =
          _toInt(
        profile['active_referrals'],
      );

      final newRate =
          0.2 +
          referrals * 0.02 +
          newAdBoost;

      await _supabase
          .from('profiles')
          .update({
        'daily_ads_watched': newAds,
        'ad_boost': newAdBoost,
        'mining_rate': newRate,
        'updated_at':
            DateTime.now().toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await refreshUser();

      _setError(null);

      return {
        'success': true,
        'message':
            'Ad reward applied.',
        'adsWatched': newAds,
        'adBoost': newAdBoost,
        'miningRate': newRate,
      };
    } catch (error) {
      debugPrint(
        'REWARDED AD ERROR: $error',
      );

      _setError(
        'Could not apply ad reward.',
      );

      return null;
    }
  }

  // ==========================================================
  // REFERRALS
  // ==========================================================

  Future<Map<String, dynamic>?> getReferrals() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final response =
          await _supabase
              .from('profiles')
              .select(
                'id,name,email,created_at,mining_active',
              )
              .eq(
                'referred_by',
                userId,
              );

      final list =
          List<Map<String, dynamic>>.from(
        response,
      );

      return {
        'success': true,
        'referralCode': referralCode,
        'activeReferrals':
            activeReferrals,
        'miningRate': miningRate,
        'referrals': list,
      };
    } catch (error) {
      debugPrint(
        'REFERRALS ERROR: $error',
      );

      _setError(
        'Could not load referrals.',
      );

      return null;
    }
  }

  // ==========================================================
  // APPLY REFERRAL
  // ==========================================================

  Future<bool> applyReferral(
    String code,
  ) async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return false;
    }

    final cleanCode =
        code.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      _setError(
        'Referral code is required.',
      );
      return false;
    }

    try {
      final referrer =
          await _supabase
              .from('profiles')
              .select(
                'id,referral_code',
              )
              .eq(
                'referral_code',
                cleanCode,
              )
              .maybeSingle();

      if (referrer == null) {
        _setError(
          'Invalid referral code.',
        );
        return false;
      }

      if (referrer['id'] == userId) {
        _setError(
          'You cannot use your own referral code.',
        );
        return false;
      }

      if (referredBy != null &&
          referredBy!.isNotEmpty) {
        _setError(
          'Referral has already been applied.',
        );
        return false;
      }

      await _supabase
          .from('profiles')
          .update({
        'referred_by':
            referrer['id'],
        'fan_balance':
            fanBalance + 20,
      }).eq(
        'id',
        userId,
      );

      final referrerBalance =
          _toDouble(
        referrer['fan_balance'],
      );

      final referrerCount =
          _toInt(
        referrer['active_referrals'],
      );

      await _supabase
          .from('profiles')
          .update({
        'fan_balance':
            referrerBalance + 5,
        'active_referrals':
            referrerCount + 1,
        'mining_rate':
            0.2 +
            (referrerCount + 1) * 0.02,
        'updated_at':
            DateTime.now().toIso8601String(),
      }).eq(
        'id',
        referrer['id'],
      );

      await refreshUser();

      return true;
    } catch (error) {
      debugPrint(
        'APPLY REFERRAL ERROR: $error',
      );

      _setError(
        'Could not apply referral.',
      );

      return false;
    }
  }
} 
