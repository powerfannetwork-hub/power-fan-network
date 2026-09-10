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

  // ============================================================
  // PROFILE
  // ============================================================

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

  // ============================================================
  // MINING
  // ============================================================

  static Future<Map<String, dynamic>> startMining() async {
    return MiningService.instance.startMining();
  }

  static Future<Map<String, dynamic>> claimMining() async {
    return MiningService.instance.claimMining();
  }

  /*
   * ============================================================
   * REWARDED ADS
   * ============================================================
   *
   * IMPORTANT:
   *
   * Rewarded-ad rewards are NOT created by ApiService.
   *
   * The correct flow is:
   *
   * Flutter LevelPlay
   *        ↓
   * LevelPlay S2S Callback
   *        ↓
   * Supabase levelplay-s2s Edge Function
   *        ↓
   * record_levelplay_reward()
   *        ↓
   * mining session
   *
   * Therefore this method MUST NOT call:
   *
   *   recordRewardedAd()
   *   record_rewarded_ad
   *   verify_rewarded_ad
   *
   * Keeping this compatibility method prevents older UI code
   * from causing a compile error, but it does NOT create a
   * reward.
   */

  static Future<Map<String, dynamic>> watchAd() async {
    return MiningService.instance.getActiveMining();
  }

  static Future<Map<String, dynamic>> getActiveMining() async {
    return MiningService.instance.getActiveMining();
  }

  static Future<double> getMiningRate() async {
    return MiningService.instance.getUserMiningRate();
  }

  static Future<int> getAdsWatched() async {
    return MiningService.instance.getAdsWatched();
  }

  static Future<bool> isMining() async {
    return MiningService.instance.isMining();
  }

  static Future<bool> isClaimable() async {
    return MiningService.instance.isClaimable();
  }

  // ============================================================
  // REFERRALS
  // ============================================================

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
    final cleanCode = code.trim();

    if (cleanCode.isEmpty) {
      throw Exception('Referral code cannot be empty.');
    }

    final result =
        await ReferralService.instance.applyReferralCode(
      cleanCode,
    );

    if (!result.success) {
      throw Exception(result.message);
    }

    return {
      'success': true,
      'message': result.message,
    };
  }
}
