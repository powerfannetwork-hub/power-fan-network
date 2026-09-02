import 'package:supabase_flutter/supabase_flutter.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic> _success(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {
      'success': true,
      'data': data,
    };
  }

  Map<String, dynamic> _error(Object error) {
    if (error is PostgrestException) {
      final message = error.message.trim();
      final code = error.code?.trim() ?? '';
      final details = error.details?.toString().trim() ?? '';
      final hint = error.hint?.trim() ?? '';

      final parts = <String>[];

      if (message.isNotEmpty) {
        parts.add(message);
      }

      if (code.isNotEmpty) {
        parts.add('Code: $code');
      }

      if (details.isNotEmpty &&
          details != 'null' &&
          details != '{}') {
        parts.add('Details: $details');
      }

      if (hint.isNotEmpty) {
        parts.add('Hint: $hint');
      }

      return {
        'success': false,
        'message': parts.isEmpty
            ? 'Supabase database error.'
            : parts.join('\n'),
        'error_code': code,
        'details': details,
        'hint': hint,
      };
    }

    if (error is AuthException) {
      return {
        'success': false,
        'message': error.message,
      };
    }

    return {
      'success': false,
      'message': error.toString(),
    };
  }

  bool _hasSession() {
    return _supabase.auth.currentSession != null &&
        _supabase.auth.currentUser != null;
  }

  Future<Map<String, dynamic>> getUserMiningRate() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'Your session has expired. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'get_user_mining_rate',
      );

      if (data is num) {
        return {
          'success': true,
          'rate': data.toDouble(),
        };
      }

      if (data is Map) {
        final result =
            Map<String, dynamic>.from(data);

        if (!result.containsKey('success')) {
          result['success'] = true;
        }

        return result;
      }

      return {
        'success': true,
        'rate': double.tryParse(
              data.toString(),
            ) ??
            0.2,
      };
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> startMining() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'start_mining',
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> getActiveMining() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'active': false,
          'message':
              'You are not logged in.',
        };
      }

      final data = await _supabase.rpc(
        'get_active_mining',
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> claimMining() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'claim_mining',
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> recordRewardedAd({
    String? adRef,
  }) async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'record_rewarded_ad',
        params: {
          'p_ad_ref': adRef,
        },
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> verifyRewardedAd({
    required String adId,
  }) async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': adId,
        },
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> useReferralCode(
    String referralCode,
  ) async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final cleanCode = referralCode.trim();

      if (cleanCode.isEmpty) {
        return {
          'success': false,
          'message': 'Referral code is required.',
        };
      }

      final data = await _supabase.rpc(
        'use_referral_code',
        params: {
          'p_referral_code': cleanCode,
        },
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'get_referral_stats',
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> completeDailySocialTask(
    String taskId,
  ) async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final cleanTaskId = taskId.trim();

      if (cleanTaskId.isEmpty) {
        return {
          'success': false,
          'message': 'Task ID is required.',
        };
      }

      final data = await _supabase.rpc(
        'complete_daily_social_task',
        params: {
          'p_task_id': cleanTaskId,
        },
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> dailyCheckin() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'daily_checkin',
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      if (!_hasSession()) {
        return {
          'success': false,
          'message':
              'You are not logged in. Please log in again.',
        };
      }

      final data = await _supabase.rpc(
        'get_dashboard',
      );

      return _success(data);
    } catch (e) {
      return _error(e);
    }
  }
}
