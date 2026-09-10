import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _client = SupabaseService.client;

  // ============================================================
  // MINING CONFIGURATION
  // ============================================================

  static const int miningDurationSeconds = 86400; // 24 hours
  static const int maxAdsPerSession = 7;

  static const double defaultMiningRate = 0.20;
  static const double adBoostPerAd = 0.10;
  static const double referralBoostPerReferral = 0.02;

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? get _userId => _client.auth.currentUser?.id;

  String get userId {
    final id = _userId;

    if (id == null || id.isEmpty) {
      throw Exception('User is not authenticated.');
    }

    return id;
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> getProfile() async {
    final id = _userId;

    if (id == null) {
      return null;
    }

    final result = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // ACTIVE MINING
  // ============================================================

  Future<Map<String, dynamic>> getActiveMining() async {
    final id = _userId;

    if (id == null) {
      return _emptyMining();
    }

    try {
      final result = await _client.rpc('get_active_mining');

      return _mapFromRpcResult(result);
    } catch (_) {
      return _emptyMining();
    }
  }

  Map<String, dynamic> _emptyMining() {
    return <String, dynamic>{
      'id': null,
      'user_id': _userId,
      'started_at': null,
      'ends_at': null,
      'claimed': false,
      'base_rate': defaultMiningRate,
      'ad_rate': 0.0,
      'referral_rate': 0.0,
      'total_rate': defaultMiningRate,
      'reward': 0.0,
      'ads_watched': 0,
      'active_referrals': 0,
      'status': 'idle',
    };
  }

  // ============================================================
  // MINING RATE
  // ============================================================

  Future<double> getUserMiningRate() async {
    final id = _userId;

    if (id == null) {
      return defaultMiningRate;
    }

    try {
      final result = await _client.rpc('get_user_mining_rate');

      final rate = _toDouble(result);

      if (rate <= 0) {
        return defaultMiningRate;
      }

      return double.parse(rate.toStringAsFixed(2));
    } catch (_) {
      return defaultMiningRate;
    }
  }

  Future<double> getMiningRateForUser(String targetUserId) async {
    if (targetUserId.trim().isEmpty) {
      return defaultMiningRate;
    }

    try {
      final result = await _client.rpc(
        'get_user_mining_rate',
        params: <String, dynamic>{
          'p_user_id': targetUserId,
        },
      );

      final rate = _toDouble(result);

      if (rate <= 0) {
        return defaultMiningRate;
      }

      return double.parse(rate.toStringAsFixed(2));
    } catch (_) {
      return defaultMiningRate;
    }
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<Map<String, dynamic>> startMining() async {
    userId;

    final result = await _client.rpc('start_mining');

    return _mapFromRpcResult(result);
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<Map<String, dynamic>> claimMining() async {
    userId;

    final result = await _client.rpc('claim_mining');

    return _mapFromRpcResult(result);
  }

  // ============================================================
  // REWARDED ADS
  // ============================================================

  Future<Map<String, dynamic>> recordRewardedAd() async {
    userId;

    final result = await _client.rpc('record_rewarded_ad');

    return _mapFromRpcResult(result);
  }

  Future<Map<String, dynamic>> verifyRewardedAd(String adId) async {
    userId;

    final cleanAdId = adId.trim();

    if (cleanAdId.isEmpty) {
      throw Exception('Invalid ad ID.');
    }

    final result = await _client.rpc(
      'verify_rewarded_ad',
      params: <String, dynamic>{
        'p_ad_id': cleanAdId,
      },
    );

    return _mapFromRpcResult(result);
  }

  Future<Map<String, dynamic>> recordAndVerifyRewardedAd() async {
    final recorded = await recordRewardedAd();

    // Backend record_rewarded_ad() returns "ad_id".
    final adId = recorded['ad_id']?.toString();

    if (adId == null || adId.isEmpty) {
      throw Exception(
        'Rewarded ad was recorded without an ID.',
      );
    }

    return verifyRewardedAd(adId);
  }

  // ============================================================
  // ADS COUNT
  // ============================================================

  Future<int> getAdsWatched() async {
    final mining = await getActiveMining();

    return _clampInt(
      _toInt(mining['ads_watched']),
      0,
      maxAdsPerSession,
    );
  }

  // ============================================================
  // ACTIVE REFERRALS
  // ============================================================

  Future<int> getActiveReferrals() async {
    final mining = await getActiveMining();

    return _toInt(
      mining['active_referrals'],
    );
  }

  // ============================================================
  // AD BOOST
  // ============================================================

  Future<double> getAdBoost() async {
    final mining = await getActiveMining();

    final ads = _clampInt(
      _toInt(mining['ads_watched']),
      0,
      maxAdsPerSession,
    );

    return ads * adBoostPerAd;
  }

  // ============================================================
  // REFERRAL BOOST
  // ============================================================

  Future<double> getReferralBoost() async {
    final referrals = await getActiveReferrals();

    return referrals * referralBoostPerReferral;
  }

  // ============================================================
  // TOTAL MINING RATE
  // ============================================================

  Future<double> getCurrentMiningRate() async {
    final mining = await getActiveMining();

    final totalRate = _toDouble(
      mining['total_rate'],
    );

    if (totalRate > 0) {
      return totalRate;
    }

    final baseRate = _toDouble(
      mining['base_rate'],
      fallback: defaultMiningRate,
    );

    final adRate = _toDouble(
      mining['ad_rate'],
    );

    final referralRate = _toDouble(
      mining['referral_rate'],
    );

    final calculatedRate =
        baseRate +
        adRate +
        referralRate;

    if (calculatedRate <= 0) {
      return defaultMiningRate;
    }

    return calculatedRate;
  }

  // ============================================================
  // MINING STATUS
  // ============================================================

  Future<bool> isMining() async {
    final mining = await getActiveMining();

    final status =
        mining['status']?.toString().toLowerCase();

    if (status == 'active' || status == 'mining') {
      return true;
    }

    final startedAt =
        _parseDateTime(mining['started_at']);

    final endsAt =
        _parseDateTime(mining['ends_at']);

    if (startedAt == null || endsAt == null) {
      return false;
    }

    final now = DateTime.now().toUtc();

    return now.isAfter(startedAt) &&
        now.isBefore(endsAt);
  }

  Future<bool> isClaimable() async {
    final mining = await getActiveMining();

    final status =
        mining['status']?.toString().toLowerCase();

    if (status == 'claimable' ||
        status == 'completed') {
      return true;
    }

    final endsAt =
        _parseDateTime(mining['ends_at']);

    if (endsAt == null) {
      return false;
    }

    final now = DateTime.now().toUtc();

    return !endsAt.isAfter(now) &&
        mining['claimed'] != true;
  }

  Future<bool> isExpired() async {
    final mining = await getActiveMining();

    final endsAt =
        _parseDateTime(mining['ends_at']);

    if (endsAt == null) {
      return false;
    }

    return !endsAt.isAfter(
      DateTime.now().toUtc(),
    );
  }

  // ============================================================
  // MINING DATES
  // ============================================================

  Future<DateTime?> getMiningStartedAt() async {
    final mining = await getActiveMining();

    return _parseDateTime(
      mining['started_at'],
    );
  }

  Future<DateTime?> getMiningEndsAt() async {
    final mining = await getActiveMining();

    return _parseDateTime(
      mining['ends_at'],
    );
  }

  // ============================================================
  // REMAINING TIME
  // ============================================================

  Future<Duration> getRemainingTime() async {
    final endsAt = await getMiningEndsAt();

    if (endsAt == null) {
      return Duration.zero;
    }

    final now = DateTime.now().toUtc();

    if (!endsAt.isAfter(now)) {
      return Duration.zero;
    }

    return endsAt.difference(now);
  }

  // ============================================================
  // ELAPSED TIME
  // ============================================================

  Future<Duration> getElapsedTime() async {
    final startedAt = await getMiningStartedAt();

    if (startedAt == null) {
      return Duration.zero;
    }

    final now = DateTime.now().toUtc();

    if (now.isBefore(startedAt)) {
      return Duration.zero;
    }

    final elapsed = now.difference(startedAt);

    if (elapsed.inSeconds > miningDurationSeconds) {
      return const Duration(
        seconds: miningDurationSeconds,
      );
    }

    return elapsed;
  }

  // ============================================================
  // ESTIMATED EARNED
  // SERVER AUTHORITATIVE
  // ============================================================

  Future<double> getEstimatedEarned() async {
    final mining = await getActiveMining();

    return _toDouble(
      mining['reward'],
    );
  }

  // ============================================================
  // CURRENT REWARD
  // ============================================================

  Future<double> getCurrentReward() async {
    final mining = await getActiveMining();

    return _toDouble(
      mining['reward'],
    );
  }

  // ============================================================
  // MINING SESSION ID
  // ============================================================

  Future<String?> getMiningSessionId() async {
    final mining = await getActiveMining();

    final id = mining['id'];

    if (id == null) {
      return null;
    }

    final value = id.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  // ============================================================
  // MINING STATUS TEXT
  // ============================================================

  Future<String> getMiningStatus() async {
    final mining = await getActiveMining();

    final status = mining['status'];

    if (status != null) {
      final value = status.toString().trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    final claimed =
        mining['claimed'] == true;

    if (claimed) {
      return 'claimed';
    }

    final endsAt =
        _parseDateTime(mining['ends_at']);

    if (endsAt != null) {
      final now = DateTime.now().toUtc();

      if (endsAt.isAfter(now)) {
        return 'active';
      }

      return 'claimable';
    }

    return 'idle';
  }

  // ============================================================
  // COMPLETE EXPIRED MINING SESSION
  // ============================================================

  Future<Map<String, dynamic>>
      completeExpiredMiningSession() async {
    userId;

    final result =
        await _client.rpc(
      'complete_expired_mining_session',
    );

    return _mapFromRpcResult(result);
  }

  // ============================================================
  // REFRESH MINING DATA
  // ============================================================

  Future<Map<String, dynamic>>
      refreshMining() async {
    try {
      await completeExpiredMiningSession();
    } catch (_) {
      // The mining engine itself handles
      // the authoritative state.
    }

    return getActiveMining();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _mapFromRpcResult(
    dynamic result,
  ) {
    if (result == null) {
      return <String, dynamic>{};
    }

    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(
        result,
      );
    }

    if (result is Map) {
      return Map<String, dynamic>.from(
        result,
      );
    }

    if (result is List) {
      if (result.isEmpty) {
        return <String, dynamic>{};
      }

      final first = result.first;

      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(
          first,
        );
      }

      if (first is Map) {
        return Map<String, dynamic>.from(
          first,
        );
      }
    }

    return <String, dynamic>{
      'result': result,
    };
  }

  int _toInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().trim(),
        ) ??
        fallback;
  }

  double _toDouble(
    dynamic value, {
    double fallback = 0.0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString().trim(),
        ) ??
        fallback;
  }

  int _clampInt(
    int value,
    int minimum,
    int maximum,
  ) {
    if (value < minimum) {
      return minimum;
    }

    if (value > maximum) {
      return maximum;
    }

    return value;
  }

  DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(text);

    return parsed?.toUtc();
  }
}
