import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> getProfile() async {
    final user = _client.auth.currentUser!;
    final res = await _client.from('profiles').select().eq('id', user.id).single();
    return res;
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser!;
    await _client.from('profiles').update(data).eq('id', user.id);
  }

  static Future<Map<String, dynamic>> startMining() async {
    final user = _client.auth.currentUser!;
    await _client.from('profiles').update({'mining_active': true, 'mining_started_at': DateTime.now().toIso8601String()}).eq('id', user.id);
    return {'success': true};
  }

  static Future<Map<String, dynamic>> claimMining() async {
    final user = _client.auth.currentUser!;
    final profile = await getProfile();
    double earned = 0.0100; // 0.01 FAN per claim
    double newBalance = (profile['fan_balance']?? 0) + earned;
    await _client.from('profiles').update({'fan_balance': newBalance, 'mining_active': false, 'mining_started_at': null}).eq('id', user.id);
    return {'earned': earned};
  }

  static Future<Map<String, dynamic>> watchAd() async {
    final profile = await getProfile();
    double newBalance = (profile['fan_balance']?? 0) + 0.0020; // 0.002 FAN per ad
    await updateProfile({'fan_balance': newBalance});
    return {'earned': 0.0020};
  }

  static Future<Map<String, dynamic>> getReferrals() async {
    final profile = await getProfile();
    return {
      'referralCode': profile['referral_code']?? '',
      'activeReferrals': profile['referrals_count']?? 0,
      'earnings': (profile['referrals_count']?? 0) * 20
    };
  }

  // WANNAN SABON FUNCTION NE
  static Future<Map<String, dynamic>> applyReferral(String code) async {
    try {
      // A halin yanzu za mu yi +20 FAN kawai. Daga baya za mu duba idan code din na gaske ne
      final profile = await getProfile();
      double newBalance = (profile['fan_balance']?? 0) + 20.0;
      await updateProfile({'fan_balance': newBalance});
      return {'success': true};
    } catch (e) {
      throw Exception('Invalid Referral Code');
    }
  }
}
