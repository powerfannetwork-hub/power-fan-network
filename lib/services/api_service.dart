import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static User? get currentUser => _supabase.auth.currentUser;
  static String? get userId => currentUser?.id;

  static Future<Map<String, dynamic>?> getProfile() async {
    final id = userId;
    if (id == null) return null;
    final data = await _supabase.from('profiles').select().eq('id', id).maybeSingle();
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  static Future<Map<String, dynamic>?> dashboard() async => getProfile();

  static Future<Map<String, dynamic>> startMining() async {
    final id = userId; if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile(); if (profile == null) throw Exception('User profile not found.');
    if (profile['mining_active'] == true) throw Exception('Mining is already active.');
    final now = DateTime.now(); final endsAt = now.add(const Duration(hours: 24));
    await _supabase.from('profiles').update({
      'mining_active': true, 'mining_started_at': now.toIso8601String(), 'mining_ends_at': endsAt.toIso8601String(), 'updated_at': now.toIso8601String(),
    }).eq('id', id);
    return {'success': true, 'message': 'Mining started successfully.'};
  }

  static Future<Map<String, dynamic>> claimMining() async {
    final id = userId; if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile(); if (profile == null) throw Exception('User profile not found.');
    if (profile['mining_active'] != true) throw Exception('Mining session is not active.');
    final endsAt = DateTime.parse(profile['mining_ends_at']); final now = DateTime.now();
    if (now.isBefore(endsAt)) throw Exception('Mining session has not ended yet.');
    final miningRate = toDouble(profile['mining_rate'], fallback: 0.2);
    final reward = miningRate * 24; final newBalance = toDouble(profile['fan_balance']) + reward;
    final activeReferrals = toInt(profile['active_referrals']); final normalRate = 0.2 + activeReferrals * 0.02;
    await _supabase.from('profiles').update({
      'fan_balance': newBalance, 'mining_active': false, 'mining_started_at': null, 'mining_ends_at': null,
      'daily_ads_watched': 0, 'ad_boost': 0, 'mining_rate': normalRate, 'updated_at': now.toIso8601String(),
    }).eq('id', id);
    return {'success': true, 'message': 'Mining reward claimed: ${reward.toStringAsFixed(4)} FAN'};
  }

  static Future<Map<String, dynamic>> watchAd() async {
    final id = userId; if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile(); if (profile == null) throw Exception('User profile not found.');
    final adsWatched = toInt(profile['daily_ads_watched']);
    if (adsWatched >= 7) throw Exception('You have reached the maximum of 7 rewarded ads today.');
    final newAds = adsWatched + 1; final adBoost = newAds * 0.1;
    final miningRate = 0.2 + (toInt(profile['active_referrals']) * 0.02) + adBoost;
    await _supabase.from('profiles').update({
      'daily_ads_watched': newAds, 'ad_boost': adBoost, 'mining_rate': miningRate, 'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    return {'success': true, 'message': 'Ad reward applied. +0.1 FAN/H'};
  }

  static Future<Map<String, dynamic>> getReferrals() async {
    final id = userId; if (id == null) throw Exception('User is not logged in.');
    final profile = await getProfile(); if (profile == null) throw Exception('User profile not found.');
    final referrals = await _supabase.from('profiles').select('id, name, email, created_at, mining_active').eq('referred_by', id);
    return {
      'success': true, 'referralCode': profile['referral_code'] ?? '', 'activeReferrals': toInt(profile['active_referrals']),
      'miningRate': toDouble(profile['mining_rate'], fallback: 0.2), 'referrals': List<Map<String, dynamic>>.from(referrals),
    };
  }

  static Future<void> clearToken() async { await _supabase.auth.signOut(); } // AN KARA WANNAN

  // HELPERS Dole ne su kasance public
  static double toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback; if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }
  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback; if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }
}
