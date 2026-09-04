import 'package:supabase_flutter/supabase_flutter.dart';

import 'mining_service.dart';
import 'referral_service.dart';
import 'supabase_service.dart';

class ApiService {
  ApiService._();

  static final SupabaseClient _client = SupabaseService.client;

  static String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.id;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    return SupabaseService.safeCall(() async {
      final result = await _client
          .from('profiles')
          .select()
          .eq('id', _userId)
          .single();

      return Map<String, dynamic>.from(result);
    });
  }

  static Future<void> updateProfile(
    Map<String, dynamic> data,
  ) async {
    await SupabaseService.safeCall(() async {
      await _client
          .from('profiles')
          .update(data)
          .eq('id', _userId);
    });
  }

  static Future<Map<String, dynamic>> startMining() async {
    await MiningService.instance.startMining();

    return {
      'success': true,
    };
  }

  static Future<Map<String, dynamic>> claimMining() async {
    return MiningService.instance.claimMining();
  }

  static Future<Map<String, dynamic>> watchAd() async {
    return MiningService.instance.recordRewardedAd();
  }

  static Future<Map<String, dynamic>> getReferrals() async {
    final info =
        await ReferralService.instance.getReferralInfo();

    return {
      'referralCode': info.referralCode,
      'activeReferrals': info.activeReferrals,
      'totalReferrals': info.totalReferrals,
      'earnings': info.totalInviterRewards,
      'miningBonus': info.miningBonus,
      'miningBonusPerActiveReferral':
          info.miningBonusPerActiveReferral,
    };
  }

  static Future<Map<String, dynamic>> applyReferral(
    String code,
  ) async {
    final result =
        await ReferralService.instance.applyReferralCode(code);

    if (!result.success) {
      throw Exception(result.message);
    }

    return {
      'success': true,
      'message': result.message,
    };
  }
}
