// ============================================================
// POWER FAN NETWORK
// API SERVICE
// ============================================================
// Backend: Supabase
// Authentication: Supabase Auth
// Database: Supabase PostgreSQL
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================================
  // USER
  // ==========================================================
  static User? get currentUser => _supabase.auth.currentUser;
  static String? get userId => currentUser?.id;

  // ==========================================================
  // PROFILE
  // ==========================================================
  static Future<Map<String, dynamic>?> getProfile() async {
    final id = userId;
    if (id == null) return null;
    final data = await _supabase.from('profiles').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================
  static Future<Map<String, dynamic>?> dashboard() async {
    return getProfile();
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================
  static Future<Map<String, dynamic>?> updateProfile({required String name}) async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    await _supabase.from('profiles').update({'name': name.trim(), 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
    return getProfile();
  }

  // ==========================================================
  // MINING CONFIG
  // ==========================================================
  static Future<Map<String, dynamic>> getMiningConfig() async {
    return {'baseMiningRate': 0.2, 'adBoostPerAd': 0.1, 'maxDailyAds': 7, 'maxAdBoost': 0.7, 'miningHours': 24};
  }

  // ==========================================================
  // START MINING
  // ==========================================================
  static Future<Map<String, dynamic>> startMining() async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile();
    if (profile == null) throw Exception('User profile not found.');
    if (profile['mining_active'] == true) throw Exception('Mining is already active.');
    final now = DateTime.now();
    final endsAt = now.add(const Duration(hours: 24));
    await _supabase.from('profiles').update({
      'mining_active': true,
      'mining_started_at': now.toIso8601String(),
      'mining_ends_at': endsAt.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }).eq('id', id);
    return {
      'success': true, 'miningActive': true, 'miningStartedAt': now.toIso8601String(),
      'miningEndsAt': endsAt.toIso8601String(), 'miningRate': toDouble(profile['mining_rate'], fallback: 0.2),
    };
  }

  // ==========================================================
  // CLAIM MINING
  // ==========================================================
  static Future<Map<String, dynamic>> claimMining() async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile();
    if (profile == null) throw Exception('User profile not found.');
    if (profile['mining_active'] != true) throw Exception('Mining session is not active.');
    final endsAtString = profile['mining_ends_at']?.toString();
    if (endsAtString == null || endsAtString.isEmpty) throw Exception('Mining end time is missing.');
    final endsAt = DateTime.tryParse(endsAtString);
    if (endsAt == null) throw Exception('Invalid mining end time.');
    final now = DateTime.now();
    if (now.isBefore(endsAt)) throw Exception('Mining session has not ended yet.');
    final miningRate = toDouble(profile['mining_rate'], fallback: 0.2);
    final reward = miningRate * 24;
    final currentBalance = toDouble(profile['fan_balance']);
    final newBalance = currentBalance + reward;
    final activeReferrals = toInt(profile['active_referrals']);
    final normalRate = 0.2 + activeReferrals * 0.02;
    await _supabase.from('profiles').update({
      'fan_balance': newBalance, 'mining_active': false, 'mining_started_at': null, 'mining_ends_at': null,
      'daily_ads_watched': 0, 'ad_boost': 0, 'mining_rate': normalRate, 'updated_at': now.toIso8601String(),
    }).eq('id', id);
    return {'success': true, 'reward': reward, 'fanBalance': newBalance, 'miningActive': false};
  }

  // ==========================================================
  // REWARDED AD
  // ==========================================================
  static Future<Map<String, dynamic>> watchAd() async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile();
    if (profile == null) throw Exception('User profile not found.');
    final adsWatched = toInt(profile['daily_ads_watched']);
    if (adsWatched >= 7) throw Exception('You have reached the maximum of 7 rewarded ads today.');
    final newAds = adsWatched + 1;
    final adBoost = newAds * 0.1;
    final activeReferrals = toInt(profile['active_referrals']);
    final referralBoost = activeReferrals * 0.02;
    final miningRate = 0.2 + referralBoost + adBoost;
    await _supabase.from('profiles').update({
      'daily_ads_watched': newAds, 'ad_boost': adBoost, 'mining_rate': miningRate, 'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    return {'success': true, 'adsWatched': newAds, 'adBoost': adBoost, 'miningRate': miningRate};
  }

  // ==========================================================
  // REFERRAL CONFIG
  // ==========================================================
  static Future<Map<String, dynamic>> getReferralConfig() async {
    return {'newUserReward': 20, 'inviterReward': 5, 'miningBoostPerReferral': 0.02};
  }

  // ==========================================================
  // APPLY REFERRAL
  // ==========================================================
  static Future<Map<String, dynamic>> applyReferral(String referralCode) async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    final code = referralCode.trim().toUpperCase();
    if (code.isEmpty) throw Exception('Referral code is required.');
    final current = await getProfile();
    if (current == null) throw Exception('User profile not found.');
    if (current['referred_by'] != null) throw Exception('Referral has already been applied.');
    final referrer = await _supabase.from('profiles').select().eq('referral_code', code).maybeSingle();
    if (referrer == null) throw Exception('Invalid referral code.');
    final referrerId = referrer['id']?.toString();
    if (referrerId == null || referrerId == id) throw Exception('Invalid referral code.');
    final referrerBalance = toDouble(referrer['fan_balance']);
    final referrerCount = toInt(referrer['active_referrals']);
    final newReferrerCount = referrerCount + 1;
    final newReferrerRate = 0.2 + newReferrerCount * 0.02;
    await _supabase.from('profiles').update({'referred_by': referrerId, 'fan_balance': 20, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
    await _supabase.from('profiles').update({
      'fan_balance': referrerBalance + 5, 'active_referrals': newReferrerCount, 'mining_rate': newReferrerRate, 'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', referrerId);
    return {'success': true, 'newUserReward': 20, 'inviterReward': 5, 'referrerMiningRate': newReferrerRate};
  }

  // ==========================================================
  // REFERRALS
  // ==========================================================
  static Future<Map<String, dynamic>> getReferrals() async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile();
    if (profile == null) throw Exception('User profile not found.');
    final referrals = await _supabase.from('profiles').select('id, name, email, created_at, mining_active').eq('referred_by', id);
    return {
      'success': true, 'referralCode': profile['referral_code'] ?? '',
      'activeReferrals': toInt(profile['active_referrals']),
      'miningRate': toDouble(profile['mining_rate'], fallback: 0.2),
      'referrals': List<Map<String, dynamic>>.from(referrals),
    };
  }

  // ==========================================================
  // SOCIAL CONFIG
  // ==========================================================
  static Future<Map<String, dynamic>> getSocialConfig() async {
    return {'dailyReward': 10, 'tasks': ['Follow official social page', 'Like official post', 'Comment on official post']};
  }

  // ==========================================================
  // CLAIM SOCIAL REWARD
  // ==========================================================
  static Future<Map<String, dynamic>> claimSocialReward() async {
    final id = userId;
    if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile();
    if (profile == null) throw Exception('User profile not found.');
    final lastClaim = profile['last_social_claim_at']?.toString();
    final now = DateTime.now();
    if (lastClaim != null && lastClaim.isNotEmpty) {
      final previous = DateTime.tryParse(lastClaim);
      if (previous != null) {
        final difference = now.difference(previous);
        if (difference.inHours < 24) throw Exception('Daily social reward has already been claimed.');
      }
    }
    final balance = toDouble(profile['fan_balance']);
    final newBalance = balance + 10;
    await _supabase.from('profiles').update({'fan_balance': newBalance, 'last_social_claim_at': now.toIso8601String(), 'updated_at': now.toIso8601String()}).eq('
