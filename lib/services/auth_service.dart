import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;

  bool get loading => _loading;

  String? get error => _error;

  bool get isAuthenticated =>
      _supabase.auth.currentSession != null &&
      _supabase.auth.currentUser != null;

  String get userId =>
      _supabase.auth.currentUser?.id ?? '';

  String get name =>
      (_user?['name'] ??
              _supabase.auth.currentUser?.userMetadata?['name'] ??
              '')
          .toString();

  String get email =>
      _supabase.auth.currentUser?.email ?? '';

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

  DateTime? get miningStartedAt {
    final value = _user?['mining_started_at'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  DateTime? get miningEndsAt {
    final value = _user?['mining_ends_at'];
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

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

      await _loadCurrentUser();

      _supabase.auth.onAuthStateChange.listen(
        (data) async {
          if (data.session == null) {
            _user = null;
            notifyListeners();
          } else {
            await _loadCurrentUser();
          }
        },
      );
    } catch (error) {
      debugPrint(
        'SUPABASE AUTH INITIALIZE ERROR: $error',
      );

      _setError(
        'Could not initialize account.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final cleanEmail =
          email.trim().toLowerCase();

      final cleanName =
          name.trim();

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

      if (response.session == null) {
        _setError(
          'Account created. Please verify your email before logging in.',
        );
        return true;
      }

      await _loadCurrentUser();

      return true;
    } on AuthException catch (error) {
      debugPrint(
        'SUPABASE REGISTER ERROR: ${error.message}',
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

      if (response.session == null ||
          response.user == null) {
        _setError(
          'Login failed.',
        );
        return false;
      }

      await _loadCurrentUser();

      return true;
    } on AuthException catch (error) {
      debugPrint(
        'SUPABASE LOGIN ERROR: ${error.message}',
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

  Future<bool> _loadCurrentUser() async {
    if (!isAuthenticated) {
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
                userId,
              )
              .maybeSingle();

      if (response == null) {
        _user = {
          'id': userId,
          'name':
              _supabase
                  .auth
                  .currentUser
                  ?.userMetadata?['name'] ??
              '',
          'email': email,
        };
      } else {
        _user =
            Map<String, dynamic>.from(
          response,
        );
      }

      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'LOAD CURRENT USER ERROR: $error',
      );

      return false;
    }
  }

  Future<bool> refreshUser() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      await _supabase.auth.getUser();

      return await _loadCurrentUser();
    } catch (error) {
      debugPrint(
        'REFRESH USER ERROR: $error',
      );

      _setError(
        'Could not refresh account.',
      );

      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (error) {
      debugPrint(
        'SUPABASE LOGOUT ERROR: $error',
      );
    }

    _user = null;
    _setError(null);

    notifyListeners();
  }

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
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      _setError(null);

      return true;
    } on AuthException catch (error) {
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

  Future<bool> updateProfile({
    required String name,
  }) async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return false;
    }

    if (name.trim().length < 2) {
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
            'name': name.trim(),
          },
        ),
      );

      await _supabase
          .from('profiles')
          .update({
            'name': name.trim(),
            'updated_at':
                DateTime.now()
                    .toUtc()
                    .toIso8601String(),
          })
          .eq(
            'id',
            userId,
          );

      await _loadCurrentUser();

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

  Future<Map<String, dynamic>?>
      getDashboard() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'get_dashboard',
      );

      final data =
          _normalizeRpcResult(result);

      if (data != null) {
        if (data['user'] is Map) {
          _user =
              Map<String, dynamic>.from(
            data['user'] as Map,
          );
        } else if (data['profile'] is Map) {
          _user =
              Map<String, dynamic>.from(
            data['profile'] as Map,
          );
        }

        notifyListeners();

        return data;
      }

      await _loadCurrentUser();

      return {
        'success': true,
        'user': _user,
      };
    } catch (error) {
      debugPrint(
        'DASHBOARD ERROR: $error',
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      startMining() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'start_mining',
      );

      final data =
          _normalizeRpcResult(result);

      if (data != null) {
        await _loadCurrentUser();
        _setError(null);
        return data;
      }

      await _loadCurrentUser();

      return {
        'success': true,
        'message': 'Mining started.',
      };
    } catch (error) {
      debugPrint(
        'START MINING ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not start mining.',
        ),
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      claimMining() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'claim_mining',
      );

      final data =
          _normalizeRpcResult(result);

      await _loadCurrentUser();

      _setError(null);

      return data ??
          {
            'success': true,
            'message':
                'Mining reward claimed.',
          };
    } catch (error) {
      debugPrint(
        'CLAIM MINING ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not claim mining reward.',
        ),
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      watchRewardedAd() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'record_rewarded_ad',
      );

      final data =
          _normalizeRpcResult(result);

      await _loadCurrentUser();

      _setError(null);

      return data ??
          {
            'success': true,
          };
    } catch (error) {
      debugPrint(
        'REWARDED AD ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not apply ad reward.',
        ),
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      getReferrals() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'get_referral_stats',
      );

      final data =
          _normalizeRpcResult(result);

      return data ??
          {
            'success': true,
            'referralCode': referralCode,
            'activeReferrals':
                activeReferrals,
            'miningRate': miningRate,
            'referrals': [],
          };
    } catch (error) {
      debugPrint(
        'REFERRALS ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not load referrals.',
        ),
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      dailyCheckIn() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'daily_checkin',
      );

      final data =
          _normalizeRpcResult(result);

      await _loadCurrentUser();

      return data;
    } catch (error) {
      debugPrint(
        'DAILY CHECK-IN ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not complete daily check-in.',
        ),
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      completeDailySocialTask(
    String taskId,
  ) async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'complete_daily_social_task',
        params: {
          'p_task_id': taskId,
        },
      );

      final data =
          _normalizeRpcResult(result);

      await _loadCurrentUser();

      return data;
    } catch (error) {
      debugPrint(
        'SOCIAL TASK ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not complete social task.',
        ),
      );

      return null;
    }
  }

  Future<Map<String, dynamic>?>
      useReferralCode(
    String code,
  ) async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final result =
          await _supabase.rpc(
        'use_referral_code',
        params: {
          'p_code':
              code.trim().toUpperCase(),
        },
      );

      final data =
          _normalizeRpcResult(result);

      await _loadCurrentUser();

      return data;
    } catch (error) {
      debugPrint(
        'USE REFERRAL ERROR: $error',
      );

      _setError(
        _rpcErrorMessage(
          error,
          'Could not apply referral code.',
        ),
      );

      return null;
    }
  }

  Map<String, dynamic>? _normalizeRpcResult(
    dynamic result,
  ) {
    if (result == null) {
      return null;
    }

    if (result is Map) {
      return Map<String, dynamic>.from(
        result,
      );
    }

    if (result is List &&
        result.isNotEmpty &&
        result.first is Map) {
      return Map<String, dynamic>.from(
        result.first as Map,
      );
    }

    return null;
  }

  String _rpcErrorMessage(
    Object error,
    String fallback,
  ) {
    if (error is PostgrestException) {
      if (error.message.trim().isNotEmpty) {
        return error.message;
      }
    }

    if (error is AuthException) {
      if (error.message.trim().isNotEmpty) {
        return error.message;
      }
    }

    return fallback;
  }
}
