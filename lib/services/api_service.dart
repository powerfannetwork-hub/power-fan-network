// ============================================================
// POWER FAN NETWORK
// SUPABASE API SERVICE
// ============================================================
// Backend: Supabase
// Database: Supabase PostgreSQL
// Custom Node.js Backend: NOT USED
// Firebase: NOT USED
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // ==========================================================
  // SUPABASE CLIENT
  // ==========================================================

  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // ==========================================================
  // AUTH USER ID
  // ==========================================================

  static String get _userId {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    return user.id;
  }

  // ==========================================================
  // HELPER
  // ==========================================================

  static Map<String, dynamic> _map(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  static double _double(
    dynamic value, [
    double fallback = 0,
  ]) {
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

  // ==========================================================
  // STATUS
  // ==========================================================

  static Future<Map<String, dynamic>> status() async {
    return {
      'success': true,
      'app': 'POWER FAN NETWORK',
      'backend': 'Supabase',
      'authentication': 'Supabase Auth',
      'database': 'Supabase PostgreSQL',
    };
  }

  // ==========================================================
  // HEALTH
  // ==========================================================

  static Future<Map<String, dynamic>> health() async {
    try {
      await _supabase
          .from('profiles')
          .select('id')
          .limit(1);

      return {
        'success': true,
        'status': 'healthy',
        'database': 'connected',
      };
    } catch (error) {
      return {
        'success': false,
        'status': 'unhealthy',
        'database': 'disconnected',
        'message': error.toString(),
      };
    }
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  static Future<Map<String, dynamic>> dashboard() async {
    final userId = _userId;

    final profile =
        await _supabase
            .from('profiles')
            .select()
            .eq(
              'id',
              userId,
            )
            .single();

    return {
      'success': true,
      'user': _map(profile),
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
  }

  // ==========================================================
  // USER BOOTSTRAP
  // ==========================================================

  static Future<Map<String, dynamic>> bootstrapUser() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final existing =
        await _supabase
            .from('profiles')
            .select()
            .eq(
              'id',
              user.id,
            )
            .maybeSingle();

    if (existing != null) {
      return {
        'success': true,
        'user': _map(existing),
      };
    }

    final metadata =
        user.userMetadata ?? {};

    final created =
        await _supabase
            .from('profiles')
            .insert({
              'id': user.id,
              'email':
                  user.email ?? '',
              'name':
                  metadata['name'] ??
                      '',
              'fan_balance':
                  0,
              'afam_balance':
                  0,
              'mining_rate':
                  0.2,
              'active_referrals':
                  0,
              'daily_ads_watched':
                  0,
              'ad_boost':
                  0,
              'mining_active':
                  false,
              'kyc1_eligible':
                  false,
              'kyc1_verified':
                  false,
              'kyc2_eligible':
                  false,
              'kyc2_verified':
                  false,
              'kyc3_verified':
                  false,
            })
            .select()
            .single();

    return {
      'success': true,
      'user': _map(created),
    };
  }

  // ==========================================================
  // PROFILE
  // ==========================================================

  static Future<Map<String, dynamic>> getProfile() async {
    final result =
        await _supabase
            .from('profiles')
            .select()
            .eq(
              'id',
              _userId,
            )
            .single();

    return {
      'success': true,
      'user': _map(result),
    };
  }

  // ==========================================================
  // MINING CONFIG
  // ==========================================================

  static Future<Map<String, dynamic>> getMiningConfig() async {
    return {
      'success': true,
      'baseMiningRate': 0.2,
      'adBoostPerAd': 0.1,
      'maxDailyAds': 7,
      'maxAdBoost': 0.7,
      'miningHours': 24,
      'referralMiningBoost': 0.02,
    };
  }

  // ==========================================================
  // START MINING
  // ==========================================================

  static Future<Map<String, dynamic>> startMining() async {
    final now =
        DateTime.now().toUtc();

    final endsAt =
        now.add(
      const Duration(
        hours: 24,
      ),
    );

    final profile =
        await _supabase
            .from('profiles')
            .select(
              'active_referrals,ad_boost',
            )
            .eq(
              'id',
              _userId,
            )
            .single();

    final referralBoost =
        _double(
              profile['active_referrals'],
            ) *
            0.02;

    final adBoost =
        _double(
          profile['ad_boost'],
        );

    final rate =
        0.2 +
            referralBoost +
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
          rate,
      'updated_at':
          now.toIso8601String(),
    }).eq(
      'id',
      _userId,
    );

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
            rate,
      },
    };
  }

  // ==========================================================
  // CLAIM MINING
  // ==========================================================

  static Future<Map<String, dynamic>> claimMining() async {
    final userId =
        _userId;

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
        profile['mining_active'] ==
            true;

    if (!active) {
      throw Exception(
        'Mining session is not active.',
      );
    }

    final endsAtString =
        profile['mining_ends_at']
            ?.toString();

    if (endsAtString == null ||
        endsAtString.isEmpty) {
      throw Exception(
        'Mining end time is missing.',
      );
    }

    final endsAt =
        DateTime.tryParse(
      endsAtString,
    );

    if (endsAt == null) {
      throw Exception(
        'Invalid mining end time.',
      );
    }

    final now =
        DateTime.now().toUtc();

    if (now.isBefore(endsAt)) {
      throw Exception(
        'Mining session has not ended yet.',
      );
    }

    final rate =
        _double(
      profile['mining_rate'],
      0.2,
    );

    final reward =
        rate * 24;

    final currentBalance =
        _double(
          profile['fan_balance'],
        );

    final newBalance =
        currentBalance + reward;

    final activeReferrals =
        (profile['active_referrals']
                    as num?)
                ?.toInt() ??
            0;

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
  }

  // ==========================================================
  // WATCH REWARDED AD
  // ==========================================================

  static Future<Map<String, dynamic>> watchAd() async {
    final userId =
        _userId;

    final profile =
        await _supabase
            .from('profiles')
            .select(
              'daily_ads_watched,active_referrals',
            )
            .eq(
              'id',
              userId,
            )
            .single();

    final ads =
        (profile['daily_ads_watched']
                    as num?)
                ?.toInt() ??
            0;

    if (ads >= 7) {
      throw Exception(
        'You have reached the maximum of 7 rewarded ads today.',
      );
    }

    final newAds =
        ads + 1;

    final activeReferrals =
        (profile['active_referrals']
                    as num?)
                ?.toInt() ??
            0;

    final adBoost =
        newAds * 0.1;

    final referralBoost =
        activeReferrals *
            0.02;

    final rate =
        0.2 +
            referralBoost +
            adBoost;

    await _supabase
        .from('profiles')
        .update({
      'daily_ads_watched':
          newAds,
      'ad_boost':
          adBoost,
      'mining_rate':
          rate,
      'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
    }).eq(
      'id',
      userId,
    );

    return {
      'success': true,
      'message':
          'Ad reward applied.',
      'adsWatched':
          newAds,
      'adBoost':
          adBoost,
      'miningRate':
          rate,
    };
  }

  // ==========================================================
  // REFERRAL CONFIG
  // ==========================================================

  static Future<Map<String, dynamic>> getReferralConfig() async {
    return {
      'success': true,
      'newUserReward': 20,
      'inviterReward': 5,
      'miningBoostPerActiveReferral':
          0.02,
    };
  }

  // ==========================================================
  // APPLY REFERRAL
  // ==========================================================

  static Future<Map<String, dynamic>> applyReferral(
    String referralCode,
  ) async {
    final code =
        referralCode
            .trim()
            .toUpperCase();

    if (code.isEmpty) {
      throw Exception(
        'Referral code is required.',
      );
    }

    final userId =
        _userId;

    final current =
        await _supabase
            .from('profiles')
            .select(
              'referred_by,fan_balance',
            )
            .eq(
              'id',
              userId,
            )
            .single();

    if (current['referred_by'] != null) {
      throw Exception(
        'A referral has already been applied.',
      );
    }

    final referrer =
        await _supabase
            .from('profiles')
            .select(
              'id,active_referrals,fan_balance',
            )
            .eq(
              'referral_code',
              code,
            )
            .maybeSingle();

    if (referrer == null) {
      throw Exception(
        'Invalid referral code.',
      );
    }

    if (referrer['id'] ==
        userId) {
      throw Exception(
        'You cannot use your own referral code.',
      );
    }

    final currentBalance =
        _double(
          current['fan_balance'],
        );

    await _supabase
        .from('profiles')
        .update({
      'referred_by':
          referrer['id'],
      'fan_balance':
          currentBalance + 20,
      'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
    }).eq(
      'id',
      userId,
    );

    final oldReferrals =
        (referrer['active_referrals']
                    as num?)
                ?.toInt() ??
            0;

    final oldReferrerBalance =
        _double(
          referrer['fan_balance'],
        );

    final newReferrals =
        oldReferrals + 1;

    await _supabase
        .from('profiles')
        .update({
      'fan_balance':
          oldReferrerBalance + 5,
      'active_referrals':
          newReferrals,
      'mining_rate':
          0.2 +
              newReferrals *
                  0.02,
      'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
    }).eq(
      'id',
      referrer['id'],
    );

    return {
      'success': true,
      'message':
          'Referral applied successfully.',
      'newUserReward':
          20,
      'inviterReward':
          5,
    };
  }

  // ==========================================================
  // GET REFERRALS
  // ==========================================================

  static Future<Map<String, dynamic>> getReferrals() async {
    final userId =
        _userId;

    final profile =
        await _supabase
            .from('profiles')
            .select(
              'referral_code,active_referrals,mining_rate',
            )
            .eq(
              'id',
              userId,
            )
            .single();

    final referrals =
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

    return {
      'success': true,
      'referralCode':
          profile['referral_code'] ??
              '',
      'activeReferrals':
          profile['active_referrals'] ??
              0,
      'miningRate':
          profile['mining_rate'] ??
              0.2,
      'referrals':
          referrals,
    };
  }

  // ==========================================================
  // SOCIAL CONFIG
  // ==========================================================

  static Future<Map<String, dynamic>> getSocialConfig() async {
    return {
      'success': true,
      'dailyReward':
          10,
      'tasksPerDay':
          1,
    };
  }

  // ==========================================================
  // CLAIM SOCIAL REWARD
  // ==========================================================

  static Future<Map<String, dynamic>> claimSocialReward() async {
    final userId =
        _userId;

    final today =
        DateTime.now()
            .toUtc()
            .toIso8601String()
            .substring(
              0,
              10,
            );

    final existing =
        await _supabase
            .from('social_rewards')
            .select('id')
            .eq(
              'user_id',
              userId,
            )
            .eq(
              'reward_date',
              today,
            )
            .maybeSingle();

    if (existing != null) {
      throw Exception(
        'Today\'s social reward has already been claimed.',
      );
    }

    await _supabase
        .from('social_rewards')
        .insert({
      'user_id':
          userId,
      'reward_date':
          today,
      'reward':
          10,
    });

    return {
      'success': true,
      'reward':
          10,
      'message':
          'Social reward claimed successfully.',
    };
  }
}
