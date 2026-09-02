import 'package:supabase_flutter/supabase_flutter.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getUserMiningRate() async {
    final result = await _supabase.rpc('get_user_mining_rate');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'rate': result,
    };
  }

  Future<Map<String, dynamic>> startMining() async {
    final result = await _supabase.rpc('start_mining');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': false,
      'message': 'Unable to start mining.',
    };
  }

  Future<Map<String, dynamic>> getActiveMining() async {
    final result = await _supabase.rpc('get_active_mining');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'active': false,
    };
  }

  Future<Map<String, dynamic>> claimMining() async {
    final result = await _supabase.rpc('claim_mining');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': false,
      'message': 'Unable to claim mining.',
    };
  }

  Future<Map<String, dynamic>> recordRewardedAd({
    String? adRef,
  }) async {
    final Map<String, dynamic> params = {};

    if (adRef != null && adRef.trim().isNotEmpty) {
      params['p_ad_ref'] = adRef.trim();
    }

    final result = await _supabase.rpc(
      'record_rewarded_ad',
      params: params,
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'result': result,
    };
  }

  Future<Map<String, dynamic>> verifyRewardedAd(
    String adId,
  ) async {
    final result = await _supabase.rpc(
      'verify_rewarded_ad',
      params: {
        'p_ad_id': adId,
      },
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'result': result,
    };
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final result = await _supabase.rpc('get_dashboard');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'dashboard': result,
    };
  }

  Future<Map<String, dynamic>> dailyCheckin() async {
    final result = await _supabase.rpc('daily_checkin');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'result': result,
    };
  }

  Future<Map<String, dynamic>> completeDailySocialTask(
    String taskId,
  ) async {
    final result = await _supabase.rpc(
      'complete_daily_social_task',
      params: {
        'p_task_id': taskId,
      },
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'result': result,
    };
  }

  Future<Map<String, dynamic>> getReferralStats() async {
    final result = await _supabase.rpc('get_referral_stats');

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'stats': result,
    };
  }

  Future<Map<String, dynamic>> useReferralCode(
    String referralCode,
  ) async {
    final result = await _supabase.rpc(
      'use_referral_code',
      params: {
        'p_referral_code': referralCode.trim(),
      },
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'result': result,
    };
  }
}
