import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart'; // Wannan shine File 1

class MiningService {
  MiningService._();
  static final MiningService instance = MiningService._();
  final SupabaseClient _client = SupabaseService.client;

  // 1. WANNAN ZAI LISSAFTA RATE NA GASKI
  Future<double> getUserMiningRate() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0.2;

    double rate = 0.20; // 1. Base Rate

    // 2. Referral Bonus: +0.02 kowanne
    try {
      final referralInfo = await _client.rpc('get_referral_info');
      final activeReferrals = (referralInfo['active_referrals'] ?? 0) as int;
      rate += activeReferrals * 0.02;
    } catch (_) {}

    // 3. Ad Bonus: +0.10 kowanne, max 7
    final activeMining = await getActiveMining();
    final startedAt = _parseDateTime(activeMining['started_at']);
    if (startedAt != null) {
      final adsWatched = await getAdsWatchedForSession(startedAt: startedAt);
      rate += adsWatched.clamp(0, 7) * 0.10;
    }
    
    return double.parse(rate.toStringAsFixed(2)); // zai iya kaiwa 0.90
  }

  Future<Map<String, dynamic>> getProfile() async {
    return SupabaseService.safeCall(() async {
      final res = await _client.from('profiles').select().eq('id', _client.auth.currentUser!.id).single();
      return res;
    });
  }

  Future<Map<String, dynamic>> getActiveMining() async {
    return SupabaseService.safeCall(() async {
      final res = await _client.from('mining_sessions').select().eq('user_id', _client.auth.currentUser!.id).eq('is_active', true).maybeSingle();
      return res ?? {'is_mining': false};
    });
  }

  Future<int> getAdsWatchedForSession({required DateTime startedAt}) async {
    return SupabaseService.safeCall(() async {
      final res = await _client.from('mining_ads').select().eq('user_id', _client.auth.currentUser!.id).eq('session_started_at', startedAt.toIso8601String());
      return (res as List).length;
    });
  }

  // 2. WATCH AD - BA ZA AI BA BAYAN SESSION YA KARE
  Future<void> watchAd() async {
    final active = await getActiveMining();
    if (active['is_mining'] != true) throw Exception('Session ya ƙare. Fara sabo');

    final startedAt = _parseDateTime(active['started_at']);
    if (startedAt == null) throw Exception('Session data ta bace');
    
    final ads = await getAdsWatchedForSession(startedAt: startedAt);
    if (ads >= 7) throw Exception('Ka kammala ads 7 na wannan session');

    await SupabaseService.safeCall(() async {
      await _client.from('mining_ads').insert({
        'user_id': _client.auth.currentUser!.id,
        'session_started_at': startedAt.toIso8601String(),
        'created_at': DateTime.now().toIso8601String()
      });
    });
  }

  // 3. START MINING - YANA SAKE SAITA ADS COUNT
  Future<void> startMining() async {
    await SupabaseService.safeCall(() async {
      await _client.rpc('start_mining_session');
    });
  }

  // 4. CLAIM - BA ZA AI BA KAFIN AWA 24
  Future<Map<String, dynamic>> claimMining() async {
    final active = await getActiveMining();
    final endsAt = _parseDateTime(active['ends_at']);
    if (endsAt != null && DateTime.now().isBefore(endsAt)) {
      throw Exception('Ba za ka iya claim ba. Awa 24 basu cika ba');
    }
    return SupabaseService.safeCall(() async {
      return await _client.rpc('claim_mining_reward');
    });
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
