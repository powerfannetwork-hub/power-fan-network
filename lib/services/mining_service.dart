import 'package:supabase_flutter/supabase_flutter.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  Map<String, dynamic> _mapResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    return {
      'success': true,
      'result': result,
    };
  }

  Map<String, dynamic> _errorResult(
    Object error, {
    String fallbackMessage = 'Something went wrong. Please try again.',
  }) {
    if (error is PostgrestException) {
      return {
        'success': false,
        'error': true,
        'message': error.message.isNotEmpty
            ? error.message
            : fallbackMessage,
        'error_code': error.code,
        'details': error.details,
        'hint': error.hint,
      };
    }

    if (error is AuthException) {
      return {
        'success': false,
        'error': true,
        'message': error.message.isNotEmpty
            ? error.message
            : fallbackMessage,
      };
    }

    return {
      'success': false,
      'error': true,
      'message': error.toString(),
    };
  }

  Map<String, dynamic> _sessionError() {
    return {
      'success': false,
      'error': true,
      'message':
          'Your session has expired. Please log in again.',
    };
  }

  bool get isSignedIn => _supabase.auth.currentSession != null;

  // ------------------------------------------------------------
  // Mining Rate
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getUserMiningRate() async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      final result = await _supabase.rpc(
        'get_user_mining_rate',
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage: 'Unable to get mining rate.',
      );
    }
  }

  // ------------------------------------------------------------
  // Start Mining
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> startMining() async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      // start_mining() has NO parameters.
      final result = await _supabase.rpc(
        'start_mining',
      );

      final data = _mapResult(result);

      // Make sure success exists for easier UI handling.
      if (!data.containsKey('success')) {
        data['success'] = true;
      }

      return data;
    } catch (e) {
      // IMPORTANT:
      // Return the real Supabase error instead of hiding it.
      return _errorResult(
        e,
        fallbackMessage: 'Unable to start mining.',
      );
    }
  }

  // ------------------------------------------------------------
  // Get Active Mining
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getActiveMining() async {
    if (!isSignedIn) {
      return {
        'active': false,
        'success': false,
        'message':
            'Your session has expired. Please log in again.',
      };
    }

    try {
      final result = await _supabase.rpc(
        'get_active_mining',
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage: 'Unable to load mining session.',
      );
    }
  }

  // ------------------------------------------------------------
  // Claim Mining
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> claimMining() async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      final result = await _supabase.rpc(
        'claim_mining',
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage: 'Unable to claim mining.',
      );
    }
  }

  // ------------------------------------------------------------
  // Rewarded Ad
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> recordRewardedAd({
    String? adRef,
  }) async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      final Map<String, dynamic> params = {};

      if (adRef != null && adRef.trim().isNotEmpty) {
        params['p_ad_ref'] = adRef.trim();
      }

      final result = await _supabase.rpc(
        'record_rewarded_ad',
        params: params,
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to record rewarded ad.',
      );
    }
  }

  // ------------------------------------------------------------
  // Verify Rewarded Ad
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> verifyRewardedAd(
    String adId,
  ) async {
    if (!isSignedIn) {
      return _sessionError();
    }

    if (adId.trim().isEmpty) {
      return {
        'success': false,
        'error': true,
        'message': 'Ad ID is required.',
      };
    }

    try {
      final result = await _supabase.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': adId.trim(),
        },
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to verify rewarded ad.',
      );
    }
  }

  // ------------------------------------------------------------
  // Dashboard
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getDashboard() async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      final result = await _supabase.rpc(
        'get_dashboard',
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to load dashboard.',
      );
    }
  }

  // ------------------------------------------------------------
  // Daily Check-in
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> dailyCheckin() async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      final result = await _supabase.rpc(
        'daily_checkin',
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to complete daily check-in.',
      );
    }
  }

  // ------------------------------------------------------------
  // Daily Social Task
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> completeDailySocialTask(
    String taskId,
  ) async {
    if (!isSignedIn) {
      return _sessionError();
    }

    if (taskId.trim().isEmpty) {
      return {
        'success': false,
        'error': true,
        'message': 'Task ID is required.',
      };
    }

    try {
      final result = await _supabase.rpc(
        'complete_daily_social_task',
        params: {
          'p_task_id': taskId.trim(),
        },
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to complete daily social task.',
      );
    }
  }

  // ------------------------------------------------------------
  // Referral Stats
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getReferralStats() async {
    if (!isSignedIn) {
      return _sessionError();
    }

    try {
      final result = await _supabase.rpc(
        'get_referral_stats',
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to load referral statistics.',
      );
    }
  }

  // ------------------------------------------------------------
  // Use Referral Code
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> useReferralCode(
    String referralCode,
  ) async {
    if (!isSignedIn) {
      return _sessionError();
    }

    final cleanCode = referralCode.trim();

    if (cleanCode.isEmpty) {
      return {
        'success': false,
        'error': true,
        'message': 'Referral code is required.',
      };
    }

    try {
      final result = await _supabase.rpc(
        'use_referral_code',
        params: {
          'p_referral_code': cleanCode,
        },
      );

      return _mapResult(result);
    } catch (e) {
      return _errorResult(
        e,
        fallbackMessage:
            'Unable to use referral code.',
      );
    }
  }
}
