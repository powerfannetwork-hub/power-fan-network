// ============================================================
// POWER FAN NETWORK
// SUPABASE AUTH SERVICE
// ============================================================
// Authentication: Supabase Auth
// Database: Supabase PostgreSQL
// Firebase Authentication: NOT USED
// Custom JWT Backend: NOT USED
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  // ==========================================================
  // SUPABASE
  // ==========================================================

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ==========================================================
  // STATE
  // ==========================================================

  User? _authUser;

  Map<String, dynamic>? _user;

  bool _loading = false;

  String? _error;

  // ==========================================================
  // GETTERS
  // ==========================================================

  User? get authUser => _authUser;

  Map<String, dynamic>? get user => _user;

  bool get loading => _loading;

  String? get error => _error;

  bool get isAuthenticated =>
      _authUser != null;

  String get userId =>
      _authUser?.id ??
      (_user?['id'] ?? '').toString();

  String get name =>
      (_user?['name'] ??
              _authUser?.userMetadata?['name'] ??
              '')
          .toString();

  String get email =>
      _authUser?.email ??
      (_user?['email'] ?? '').toString();

  String get referralCode =>
      (_user?['referral_code'] ??
              _user?['referralCode'] ??
              '')
          .toString();

  String? get referredBy {
    final value =
        _user?['referred_by'] ??
            _user?['referredBy'];

    if (value == null) {
      return null;
    }

    return value.toString();
  }

  double get fanBalance =>
      _toDouble(
        _user?['fan_balance'] ??
            _user?['fanBalance'],
      );

  double get afamBalance =>
      _toDouble(
        _user?['afam_balance'] ??
            _user?['afamBalance'],
      );

  double get miningRate =>
      _toDouble(
        _user?['mining_rate'] ??
            _user?['miningRate'],
        fallback: 0.2,
      );

  int get activeReferrals =>
      _toInt(
        _user?['active_referrals'] ??
            _user?['activeReferrals'],
      );

  int get dailyAdsWatched =>
      _toInt(
        _user?['daily_ads_watched'] ??
            _user?['dailyAdsWatched'],
      );

  double get adBoost =>
      _toDouble(
        _user?['ad_boost'] ??
            _user?['adBoost'],
      );

  bool get miningActive =>
      _user?['mining_active'] ==
              true ||
          _user?['miningActive'] ==
              true;

  DateTime? get miningStartedAt =>
      _toDateTime(
        _user?['mining_started_at'] ??
            _user?['miningStartedAt'],
      );

  DateTime? get miningEndsAt =>
      _toDateTime(
        _user?['mining_ends_at'] ??
            _user?['miningEndsAt'],
      );

  int get consecutiveCheckIns =>
      _toInt(
        _user?['consecutive_check_ins'] ??
            _user?['consecutiveCheckIns'],
      );

  bool get kyc1Eligible =>
      _user?['kyc1_eligible'] ==
              true ||
          _user?['kyc1Eligible'] ==
              true;

  bool get kyc1Verified =>
      _user?['kyc1_verified'] ==
              true ||
          _user?['kyc1Verified'] ==
              true;

  bool get kyc2Eligible =>
      _user?['kyc2_eligible'] ==
              true ||
          _user?['kyc2Eligible'] ==
              true;

  bool get kyc2Verified =>
      _user?['kyc2_verified'] ==
              true ||
          _user?['kyc2Verified'] ==
              true;

  bool get kyc3Verified =>
      _user?['kyc3_verified'] ==
              true ||
          _user?['kyc3Verified'] ==
              true;

  // ==========================================================
  // HELPERS
  // ==========================================================

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        fallback;
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  DateTime? _toDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  void _setLoading(
    bool value,
  ) {
    _loading = value;
    notifyListeners();
  }

  void _setError(
    String? value,
  ) {
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
      _authUser =
          _supabase.auth.currentUser;

      if (_authUser != null) {
        await _loadProfile(
          showError: false,
        );
      }

      _supabase.auth.onAuthStateChange.listen(
        (data) async {
          _authUser = data.session?.user;

          if (_authUser != null) {
            await _loadProfile(
              showError: false,
            );
          } else {
            _user = null;
          }

          notifyListeners();
        },
      );
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
      final cleanName =
          name.trim();

      final cleanEmail =
          email.trim().toLowerCase();

      final cleanReferral =
          referralCode
              ?.trim()
              .toUpperCase();

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

      if (
        !RegExp(
          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
        ).hasMatch(cleanEmail)
      ) {
        _setError(
          'Invalid email address.',
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
            'referral_code':
                cleanReferral,
        },
      );

      if (response.user == null) {
        _setError(
          'Account could not be created.',
        );
        return false;
      }

      _authUser =
          response.user;

      // Profile is created by the
      // Supabase database trigger.
      await _loadProfile(
        showError: false,
      );

      _setError(null);

      notifyListeners();

      return true;
    } on AuthException catch (error) {
      debugPrint(
        'REGISTER AUTH ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return false;
    } catch (error) {
      debugPrint(
        'REGISTER ERROR: $error',
      );

      _setError(
        'Registration failed. Please try again.',
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
        email:
            email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null) {
        _setError(
          'Login failed.',
        );
        return false;
      }

      _authUser =
          response.user;

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      notifyListeners();

      return true;
    } on AuthException catch (error) {
      debugPrint(
        'LOGIN AUTH ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return false;
    } catch (error) {
      debugPrint(
        'LOGIN ERROR: $error',
      );

      _setError(
        'Login failed. Please try again.',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // LOAD PROFILE
  // ==========================================================

  Future<bool> _loadProfile({
    bool showError = true,
  }) async {
    final currentUser =
        _supabase.auth.currentUser;

    if (currentUser == null) {
      _user = null;
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

      if (response == null) {
        _user = {
          'id': currentUser.id,
          'email':
              currentUser.email ?? '',
          'name':
              currentUser.userMetadata?[
                      'name'] ??
                  '',
        };

        return true;
      }

      _user =
          Map<String, dynamic>.from(
        response,
      );

      notifyListeners();

      return true;
    } on PostgrestException catch (error) {
      debugPrint(
        'LOAD PROFILE DATABASE ERROR: ${error.message}',
      );

      if (showError) {
        _setError(
          'Could not load your profile.',
        );
      }

      return false;
    } catch (error) {
      debugPrint(
        'LOAD PROFILE ERROR: $error',
      );

      if (showError) {
        _setError(
          'Could not load your profile.',
        );
      }

      return false;
    }
  }

  // ==========================================================
  // REFRESH USER
  // ==========================================================

  Future<bool> refreshUser() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      await _supabase.auth.refreshSession();

      _authUser =
          _supabase.auth.currentUser;

      return await _loadProfile(
        showError: true,
      );
    } on AuthException catch (error) {
      debugPrint(
        'REFRESH AUTH ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return false;
    } catch (error) {
      debugPrint(
        'REFRESH USER ERROR: $error',
      );

      _setError(
        'Could not refresh your account.',
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

    _authUser = null;
    _user = null;
    _setError(null);

    notifyListeners();
  }

  // ==========================================================
  // CHANGE PASSWORD
  // ==========================================================

  Future<bool> changePassword({
    required String currentPassword,
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
      // Verify the current password
      // before changing it.
      final email =
          _supabase.auth.currentUser?.email;

      if (email == null ||
          email.isEmpty) {
        _setError(
          'Your account email could not be found.',
        );

        return false;
      }

      final verify =
          await _supabase.auth
              .signInWithPassword(
        email: email,
        password: currentPassword,
      );

      if (verify.user == null) {
        _setError(
          'Current password is incorrect.',
        );

        return false;
      }

      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      _setError(null);

      return true;
    } on AuthException catch (error) {
      debugPrint(
        'CHANGE PASSWORD AUTH ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

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

    final cleanName =
        name.trim();

    if (cleanName.length < 2) {
      _setError(
        'Name is too short.',
      );

      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _supabase
          .from('profiles')
          .update({
        'name': cleanName,
        'updated_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'name': cleanName,
          },
        ),
      );

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      notifyListeners();

      return true;
    } on PostgrestException catch (error) {
      debugPrint(
        'UPDATE PROFILE DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return false;
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
      await _loadProfile(
        showError: false,
      );

      return {
        'success': true,
        'user':
            _user ?? {},
        'rules': {
          'baseMiningRate':
              0.2,
          'adBoostPerAd':
              0.1,
          'maxDailyAds':
              7,
          'maxAdBoost':
              0.7,
          'referralMiningBoost':
              0.02,
          'newUserReferralReward':
              20,
          'inviterReferralReward':
              5,
          'dailySocialReward':
              10,
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
      final now =
          DateTime.now().toUtc();

      final endsAt =
          now.add(
        const Duration(
          hours: 24,
        ),
      );

      final newRate =
          0.2 +
              activeReferrals *
                  0.02 +
              adBoost;

      await _supabase
          .from('profiles')
          .update({
        'mining_active':
            true,
        'mining_started_at':
            now.toIso8601String(),
        'mining_ends_at':
            endsAt.toIso8601String(),
        'mining_rate':
            newRate,
        'updated_at':
            now.toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      return {
        'success': true,
        'message':
            'Mining started.',
        'mining': {
          'active': true,
          'startedAt':
              now.toIso8601String(),
          'endsAt':
              endsAt.toIso8601String(),
          'miningRate':
              newRate,
        },
      };
    } on PostgrestException catch (error) {
      debugPrint(
        'START MINING DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return null;
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
      await _loadProfile(
        showError: false,
      );

      if (!miningActive) {
        _setError(
          'Mining session is not active.',
        );

        return null;
      }

      final endsAt =
          miningEndsAt;

      if (endsAt == null) {
        _setError(
          'Mining end time is missing.',
        );

        return null;
      }

      final now =
          DateTime.now().toUtc();

      if (now.isBefore(endsAt)) {
        _setError(
          'Mining session has not ended yet.',
        );

        return null;
      }

      final reward =
          miningRate * 24;

      final newBalance =
          fanBalance + reward;

      final baseRate =
          0.2 +
              activeReferrals *
                  0.02;

      await _supabase
          .from('profiles')
          .update({
        'fan_balance':
            newBalance,
        'mining_active':
            false,
        'mining_started_at':
            null,
        'mining_ends_at':
            null,
        'daily_ads_watched':
            0,
        'ad_boost':
            0,
        'mining_rate':
            baseRate,
        'updated_at':
            now.toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      return {
        'success': true,
        'message':
            'Mining reward claimed.',
        'reward':
            reward,
        'fanBalance':
            newBalance,
        'miningActive':
            false,
      };
    } on PostgrestException catch (error) {
      debugPrint(
        'CLAIM MINING DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return null;
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
      await _loadProfile(
        showError: false,
      );

      if (dailyAdsWatched >= 7) {
        _setError(
          'You have reached the maximum of 7 rewarded ads today.',
        );

        return null;
      }

      final newAds =
          dailyAdsWatched + 1;

      final newAdBoost =
          newAds * 0.1;

      final referralBoost =
          activeReferrals *
              0.02;

      final newRate =
          0.2 +
              referralBoost +
              newAdBoost;

      await _supabase
          .from('profiles')
          .update({
        'daily_ads_watched':
            newAds,
        'ad_boost':
            newAdBoost,
        'mining_rate':
            newRate,
        'updated_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      return {
        'success': true,
        'message':
            'Ad reward applied.',
        'adsWatched':
            newAds,
        'adBoost':
            newAdBoost,
        'miningRate':
            newRate,
      };
    } on PostgrestException catch (error) {
      debugPrint(
        'REWARDED AD DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return null;
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
              )
              .order(
                'created_at',
                ascending: false,
              );

      final referrals =
          (response as List)
              .map(
                (item) =>
                    Map<String, dynamic>.from(
                  item as Map,
                ),
              )
              .toList();

      return {
        'success': true,
        'referralCode':
            referralCode,
        'activeReferrals':
            activeReferrals,
        'miningRate':
            miningRate,
        'referrals':
            referrals,
      };
    } on PostgrestException catch (error) {
      debugPrint(
        'REFERRALS DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return null;
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
              .select('id,referral_code')
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

      if (referrer['id'] ==
          userId) {
        _setError(
          'You cannot use your own referral code.',
        );

        return false;
      }

      if (referredBy != null &&
          referredBy!.isNotEmpty) {
        _setError(
          'A referral has already been applied.',
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
        'updated_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
      }).eq(
        'id',
        userId,
      );

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      return true;
    } on PostgrestException catch (error) {
      debugPrint(
        'APPLY REFERRAL DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return false;
    } catch (error) {
      debugPrint(
        'APPLY REFERRAL ERROR: $error',
      );

      _setError(
        'Could not apply referral code.',
      );

      return false;
    }
  }

  // ==========================================================
  // SOCIAL REWARD
  // ==========================================================

  Future<bool> claimSocialReward() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );

      return false;
    }

    try {
      await _supabase.rpc(
        'claim_social_reward',
      );

      await _loadProfile(
        showError: false,
      );

      _setError(null);

      return true;
    } on PostgrestException catch (error) {
      debugPrint(
        'SOCIAL REWARD DATABASE ERROR: ${error.message}',
      );

      _setError(
        error.message,
      );

      return false;
    } catch (error) {
      debugPrint(
        'SOCIAL REWARD ERROR: $error',
      );

      _setError(
        'Could not claim social reward.',
      );

      return false;
    }
  }
}
