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

    if (id == null || id.isEmpty) {
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

    if (id == null || id.isEmpty) {
      return _emptyMining();
    }

    /*
     * IMPORTANT:
     *
     * Supabase/RPC is authoritative.
     *
     * We intentionally do NOT catch database/RPC errors here.
     * If the database has an error, HomeScreen must know about it.
     *
     * The backend function:
     *
     *   get_active_mining()
     *
     * decides whether the session is:
     *
     *   active
     *   claimable
     *   claimed
     *   idle
     */
    final result = await _client.rpc('get_active_mining');

    return _mapFromRpcResult(result);
  }

  Map<String, dynamic> _emptyMining() {
    return <String, dynamic>{
      'id': null,
      'user_id': _userId,
      'started_at': null,
      'ends_at': null,
      'claimed': false,
      'active': false,
      'claimable': false,
      'claim_required': false,
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

    if (id == null || id.isEmpty) {
      return defaultMiningRate;
    }

    try {
      final result = await _client.rpc('get_user_mining_rate');

      final rate = _toDouble(result);

      if (rate <= 0) {
        return defaultMiningRate;
      }

      return double.parse(
        rate.toStringAsFixed(2),
      );
    } catch (_) {
      return defaultMiningRate;
    }
  }

  Future<double> getMiningRateForUser(
    String targetUserId,
  ) async {
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

      return double.parse(
        rate.toStringAsFixed(2),
      );
    } catch (_) {
      return defaultMiningRate;
    }
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<Map<String, dynamic>> startMining() async {
    userId;

    /*
     * Server creates/checks the 24-hour session.
     *
     * We do NOT create a local session.
     * We do NOT fabricate started_at or ends_at.
     */
    final result = await _client.rpc('start_mining');

    final mapped = _mapFromRpcResult(result);

    if (mapped.isEmpty) {
      throw Exception(
        'Mining server returned an empty response.',
      );
    }

    return mapped;
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<Map<String, dynamic>> claimMining() async {
    userId;

    /*
     * IMPORTANT:
     *
     * No DateTime.now() check here.
     *
     * The database decides whether:
     *
     *   - the 24 hours are complete
     *   - the session is claimable
     *   - the rewarded ad is verified
     *   - the reward can be credited
     *
     * This prevents a wrong phone clock from bypassing/blocking
     * the mining rules.
     */
    final result = await _client.rpc('claim_mining');

    final mapped = _mapFromRpcResult(result);

    if (mapped.isEmpty) {
      throw Exception(
        'Mining claim server returned an empty response.',
      );
    }

    return mapped;
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
  // IS MINING
  // ============================================================

  Future<bool> isMining() async {
    final mining = await getActiveMining();

    final serverActive =
        _toBool(mining['active']);

    final status =
        mining['status']
            ?.toString()
            .trim()
            .toLowerCase();

    if (serverActive) {
      return true;
    }

    if (status == 'active' ||
        status == 'mining' ||
        status == 'running' ||
        status == 'started') {
      return true;
    }

    /*
     * Fallback only.
     *
     * The server's active/status values are preferred.
     */
    final startedAt = _parseDateTime(
      mining['started_at'],
    );

    final endsAt = _parseDateTime(
      mining['ends_at'],
    );

    if (startedAt == null ||
        endsAt == null) {
      return false;
    }

    final now = DateTime.now().toUtc();

    return !now.isBefore(startedAt) &&
        now.isBefore(endsAt);
  }

  // ============================================================
  // IS CLAIMABLE
  // ============================================================

  Future<bool> isClaimable() async {
    final mining = await getActiveMining();

    final claimed =
        _toBool(mining['claimed']) ||
        _toBool(mining['is_claimed']);

    if (claimed) {
      return false;
    }

    final serverClaimable =
        _toBool(mining['claimable']) ||
        _toBool(mining['can_claim']) ||
        _toBool(mining['claim_required']) ||
        _toBool(mining['requires_claim']) ||
        _toBool(mining['needs_claim']);

    if (serverClaimable) {
      return true;
    }

    final status =
        mining['status']
            ?.toString()
            .trim()
            .toLowerCase();

    if (status == 'claimable' ||
        status == 'completed' ||
        status == 'complete' ||
        status == 'expired' ||
        status == 'finished' ||
        status == 'ready_to_claim' ||
        status == 'pending_claim' ||
        status == 'awaiting_claim' ||
        status == 'session_completed' ||
        status == 'ended') {
      return true;
    }

    /*
     * Last fallback only.
     */
    final endsAt = _parseDateTime(
      mining['ends_at'],
    );

    if (endsAt == null) {
      return false;
    }

    return !endsAt.isAfter(
      DateTime.now().toUtc(),
    );
  }

  // ============================================================
  // IS EXPIRED
  // ============================================================

  Future<bool> isExpired() async {
    final mining = await getActiveMining();

    final serverClaimable =
        _toBool(mining['claimable']) ||
        _toBool(mining['claim_required']) ||
        _toBool(mining['requires_claim']) ||
        _toBool(mining['needs_claim']);

    if (serverClaimable) {
      return true;
    }

    final status =
        mining['status']
            ?.toString()
            .trim()
            .toLowerCase();

    if (status == 'expired' ||
        status == 'completed' ||
        status == 'claimable' ||
        status == 'ready_to_claim' ||
        status == 'ended') {
      return true;
    }

    final endsAt = _parseDateTime(
      mining['ends_at'],
    );

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
    final mining = await getActiveMining();

    /*
     * If backend provides remaining_seconds, prefer it.
     */
    final serverRemaining = _toInt(
      mining['remaining_seconds'] ??
          mining['seconds_remaining'],
    );

    if (serverRemaining > 0) {
      return Duration(
        seconds: serverRemaining,
      );
    }

    final endsAt = _parseDateTime(
      mining['ends_at'],
    );

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
    final startedAt =
        await getMiningStartedAt();

    if (startedAt == null) {
      return Duration.zero;
    }

    final now = DateTime.now().toUtc();

    if (now.isBefore(startedAt)) {
      return Duration.zero;
    }

    final elapsed =
        now.difference(startedAt);

    if (elapsed.inSeconds >
        miningDurationSeconds) {
      return const Duration(
        seconds: miningDurationSeconds,
      );
    }

    return elapsed;
  }

  // ============================================================
  // ESTIMATED EARNED
  // ============================================================

  Future<double> getEstimatedEarned() async {
    final mining =
        await getActiveMining();

    return _toDouble(
      mining['reward'],
    );
  }

  // ============================================================
  // CURRENT REWARD
  // ============================================================

  Future<double> getCurrentReward() async {
    final mining =
        await getActiveMining();

    return _toDouble(
      mining['reward'],
    );
  }

  // ============================================================
  // SESSION ID
  // ============================================================

  Future<String?> getMiningSessionId() async {
    final mining =
        await getActiveMining();

    final id = mining['id'];

    if (id == null) {
      return null;
    }

    final value =
        id.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  // ============================================================
  // MINING STATUS
  // ============================================================

  Future<String> getMiningStatus() async {
    final mining =
        await getActiveMining();

    final status =
        mining['status'];

    if (status != null) {
      final value =
          status.toString().trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    if (_toBool(mining['active'])) {
      return 'active';
    }

    if (_toBool(mining['claimable']) ||
        _toBool(mining['claim_required']) ||
        _toBool(mining['requires_claim'])) {
      return 'claimable';
    }

    if (_toBool(mining['claimed'])) {
      return 'claimed';
    }

    return 'idle';
  }

  // ============================================================
  // COMPLETE EXPIRED SESSION
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
  // REFRESH MINING
  // ============================================================

  Future<Map<String, dynamic>>
      refreshMining() async {
    try {
      await completeExpiredMiningSession();
    } catch (_) {
      /*
       * Do not allow this helper RPC to break the main
       * get_active_mining flow.
       */
    }

    return getActiveMining();
  }

  // ============================================================
  // RPC RESULT NORMALIZER
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

  // ============================================================
  // HELPERS
  // ============================================================

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

  bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y';
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

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final parsed =
        DateTime.tryParse(text);

    return parsed?.toUtc();
  }
}
