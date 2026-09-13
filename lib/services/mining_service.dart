import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class MiningService {
  MiningService._internal();

  static final MiningService _instance = MiningService._internal();

  factory MiningService() {
    return _instance;
  }

  static MiningService get instance => _instance;

  final SupabaseClient _client = SupabaseService.client;

  // ============================================================
  // MINING CONFIG
  // ============================================================

  static const int miningDurationSeconds = 86400;
  static const int maxAdsPerSession = 7;
  static const double defaultMiningRate = 0.20;

  // ============================================================
  // HELPERS
  // ============================================================

  dynamic _value(
    Map<String, dynamic> data,
    List<String> keys, [
    dynamic fallback,
  ]) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key];
      }
    }

    return fallback;
  }

  int _toInt(
    dynamic value, [
    int fallback = 0,
  ]) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  double _toDouble(
    dynamic value, [
    double fallback = 0.0,
  ]) {
    if (value == null) {
      return fallback;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? fallback;
  }

  bool _toBool(
    dynamic value, [
    bool fallback = false,
  ]) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().trim().toLowerCase();

    if (text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'active' ||
        text == 'claimable' ||
        text == 'completed' ||
        text == 'claimed' ||
        text == 'success') {
      return true;
    }

    if (text == 'false' ||
        text == '0' ||
        text == 'no' ||
        text == 'inactive') {
      return false;
    }

    return fallback;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    final parsed = DateTime.tryParse(value.toString());

    return parsed?.toUtc();
  }

  Map<String, dynamic> _normalize(dynamic raw) {
    if (raw == null) {
      return <String, dynamic>{};
    }

    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(
          key.toString(),
          value,
        ),
      );
    }

    if (raw is List &&
        raw.isNotEmpty &&
        raw.first is Map) {
      final first = raw.first;

      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(first);
      }

      if (first is Map) {
        return first.map(
          (key, value) => MapEntry(
            key.toString(),
            value,
          ),
        );
      }
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // START MINING
  //
  // IMPORTANT:
  //
  // Activation Ad is handled by HomeScreen /
  // LevelPlayAdsService.
  //
  // This method ONLY calls start_mining().
  //
  // Correct flow:
  //
  // CLAIM
  //   ↓
  // START MINING
  //   ↓
  // ACTIVATION AD
  //   ↓
  // start_mining()
  //   ↓
  // 24-HOUR ACTIVE SESSION
  //   ↓
  // BOOST ADS
  // ============================================================

  Future<Map<String, dynamic>> startMining() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await _client.rpc('start_mining');

    final result = _prepareMiningResult(response);

    return result;
  }

  // ============================================================
  // GET ACTIVE MINING
  // ============================================================

  Future<Map<String, dynamic>> getActiveMining() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await _client.rpc('get_active_mining');

    return _prepareMiningResult(response);
  }

  // ============================================================
  // PREPARE / NORMALIZE MINING RESULT
  // ============================================================

  Map<String, dynamic> _prepareMiningResult(dynamic raw) {
    final data = _normalize(raw);

    if (data.isEmpty) {
      return <String, dynamic>{};
    }

    final status = _value(
      data,
      [
        'status',
        'mining_status',
      ],
      '',
    ).toString().trim().toLowerCase();

    final active = _toBool(
      _value(
        data,
        [
          'active',
          'is_active',
          'mining_active',
        ],
        false,
      ),
    );

    final claimable = _toBool(
      _value(
        data,
        [
          'claimable',
          'can_claim',
          'claim_required',
          'requires_claim',
          'needs_claim',
          'session_completed',
          'completed',
        ],
        false,
      ),
    );

    final expired = _toBool(
      _value(
        data,
        [
          'expired',
          'is_expired',
        ],
        false,
      ),
    );

    final claimed =
        _toBool(
          _value(
            data,
            [
              'claimed',
              'is_claimed',
            ],
            false,
          ),
        ) ||
        status == 'claimed';

    final startedAt = _toDateTime(
      _value(
        data,
        [
          'started_at',
          'start_time',
          'started',
          'mining_started_at',
        ],
      ),
    );

    final endsAt = _toDateTime(
      _value(
        data,
        [
          'ends_at',
          'end_time',
          'expires_at',
          'ended_at',
          'mining_ends_at',
        ],
      ),
    );

    int remainingSeconds = _toInt(
      _value(
        data,
        [
          'remaining_seconds',
          'seconds_remaining',
          'remaining',
        ],
        0,
      ),
    );

    if (remainingSeconds < 0) {
      remainingSeconds = 0;
    }

    // ------------------------------------------------------------
    // SERVER END TIME IS AUTHORITATIVE
    // ------------------------------------------------------------

    if (endsAt != null) {
      final now = DateTime.now().toUtc();

      final calculated = endsAt.difference(now).inSeconds;

      remainingSeconds = calculated > 0 ? calculated : 0;
    }

    // ------------------------------------------------------------
    // RATE
    // ------------------------------------------------------------

    var rate = _toDouble(
      _value(
        data,
        [
          'total_rate',
          'mining_rate',
          'rate',
        ],
        defaultMiningRate,
      ),
      defaultMiningRate,
    );

    if (rate <= 0) {
      rate = defaultMiningRate;
    }

    // ------------------------------------------------------------
    // REWARD
    // ------------------------------------------------------------

    final reward = _toDouble(
      _value(
        data,
        [
          'reward',
          'session_reward',
          'earned_reward',
          'reward_amount',
        ],
        0.0,
      ),
    );

    // ------------------------------------------------------------
    // BOOST ADS ONLY
    //
    // Activation Ad is NOT counted.
    // ------------------------------------------------------------

    var adsWatched = _toInt(
      _value(
        data,
        [
          'ads_watched',
          'ad_count',
          'ads_count',
          'daily_ads_watched',
        ],
        0,
      ),
    );

    if (adsWatched < 0) {
      adsWatched = 0;
    }

    if (adsWatched > maxAdsPerSession) {
      adsWatched = maxAdsPerSession;
    }

    // ------------------------------------------------------------
    // NORMALIZED RESULT
    // ------------------------------------------------------------

    final normalized = <String, dynamic>{
      ...data,

      'status': status,

      'active': active,

      'claimable': claimable,

      'expired': expired,

      'claimed': claimed,

      'started_at': startedAt?.toIso8601String(),

      'ends_at': endsAt?.toIso8601String(),

      'remaining_seconds': remainingSeconds,

      'rate': rate,

      'mining_rate': rate,

      'total_rate': rate,

      'reward': reward,

      'session_reward': reward,

      'ads_watched': adsWatched,
    };

    return normalized;
  }

  // ============================================================
  // CHECK IF CURRENT USER IS MINING
  // ============================================================

  Future<bool> isMining() async {
    final result = await getActiveMining();

    if (result.isEmpty) {
      return false;
    }

    if (_toBool(result['claimed'], false)) {
      return false;
    }

    final active = _toBool(
      result['active'],
      false,
    );

    if (!active) {
      return false;
    }

    final remaining = _toInt(
      result['remaining_seconds'],
      0,
    );

    if (remaining <= 0) {
      return false;
    }

    return true;
  }

  // ============================================================
  // CHECK IF CURRENT USER CAN CLAIM
  // ============================================================

  Future<bool> isClaimable() async {
    final result = await getActiveMining();

    if (result.isEmpty) {
      return false;
    }

    final claimed = _toBool(
      result['claimed'],
      false,
    );

    if (claimed) {
      return false;
    }

    final claimable = _toBool(
      result['claimable'],
      false,
    );

    if (claimable) {
      return true;
    }

    final status = result['status']
        ?.toString()
        .trim()
        .toLowerCase();

    return status == 'claimable' ||
        status == 'ready_to_claim' ||
        status == 'completed' ||
        status == 'complete' ||
        status == 'expired' ||
        status == 'ended' ||
        status == 'finished' ||
        status == 'pending_claim' ||
        status == 'awaiting_claim' ||
        status == 'session_completed';
  }

  // ============================================================
  // GET PROFILE
  // ============================================================

  Future<Map<String, dynamic>> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // GET FAN BALANCE
  // ============================================================

  Future<double> getFanBalance() async {
    final profile = await getProfile();

    return _toDouble(
      _value(
        profile,
        [
          'fan_balance',
          'balance',
        ],
        0.0,
      ),
    );
  }

  // ============================================================
  // GET USER MINING RATE
  // ============================================================

  Future<double> getUserMiningRate() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return defaultMiningRate;
    }

    try {
      final response = await _client.rpc(
        'get_user_mining_rate',
        params: {
          'p_user_id': user.id,
        },
      );

      if (response is num) {
        final rate = response.toDouble();

        return rate > 0 ? rate : defaultMiningRate;
      }

      final data = _normalize(response);

      final rate = _toDouble(
        _value(
          data,
          [
            'total_rate',
            'mining_rate',
            'rate',
          ],
          defaultMiningRate,
        ),
        defaultMiningRate,
      );

      return rate > 0 ? rate : defaultMiningRate;
    } catch (_) {
      return defaultMiningRate;
    }
  }

  // ============================================================
  // GET BOOST ADS WATCHED
  // ============================================================

  Future<int> getAdsWatched() async {
    final result = await getActiveMining();

    if (result.isEmpty) {
      return 0;
    }

    var count = _toInt(
      _value(
        result,
        [
          'ads_watched',
          'ad_count',
          'ads_count',
          'daily_ads_watched',
        ],
        0,
      ),
    );

    if (count < 0) {
      count = 0;
    }

    if (count > maxAdsPerSession) {
      count = maxAdsPerSession;
    }

    return count;
  }

  // ============================================================
  // CLAIM MINING
  //
  // CLAIM DOES NOT REQUIRE AN AD.
  //
  // IMPORTANT FIX:
  //
  // Supabase may return:
  //
  //   success: true
  //
  // OR:
  //
  //   claimed: true
  //
  // OR:
  //
  //   status: claimed
  //
  // We normalize all successful claim responses to:
  //
  //   success: true
  //   claimed: true
  //   already_claimed: true
  //
  // This makes HomeScreen reliably switch to
  // START MINING after a successful claim.
  // ============================================================

  Future<Map<String, dynamic>> claimMining() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await _client.rpc('claim_mining');

    final data = _normalize(response);

    if (data.isEmpty) {
      return <String, dynamic>{
        'success': false,
        'claimed': false,
        'message': 'Empty response from claim_mining.',
      };
    }

    final status = _value(
      data,
      [
        'status',
        'mining_status',
      ],
      '',
    ).toString().trim().toLowerCase();

    final message = _value(
      data,
      [
        'message',
        'error',
        'detail',
      ],
      '',
    ).toString().trim();

    final claimed = _toBool(
          _value(
            data,
            [
              'claimed',
              'is_claimed',
            ],
            false,
          ),
          false,
        ) ||
        status == 'claimed' ||
        status == 'success' ||
        status == 'claim_success' ||
        status == 'claimed_successfully';

    final alreadyClaimed = _toBool(
          _value(
            data,
            [
              'already_claimed',
            ],
            false,
          ),
          false,
        ) ||
        status == 'already_claimed';

    final explicitSuccess = _toBool(
      _value(
        data,
        [
          'success',
          'ok',
        ],
        false,
      ),
      false,
    );

    final success = explicitSuccess || claimed || alreadyClaimed;

    return <String, dynamic>{
      ...data,

      'success': success,

      'claimed': claimed || alreadyClaimed,

      'already_claimed': alreadyClaimed,

      'status': status,

      'message': message,
    };
  }

  // ============================================================
  // BACKWARD COMPATIBILITY
  //
  // Claiming no longer requires an ad.
  // ============================================================

  @Deprecated(
    'Claim ads are no longer part of the mining flow. '
    'Use claimMining() directly.',
  )
  Future<Map<String, dynamic>> requestClaimAd() async {
    return <String, dynamic>{
      'success': false,
      'message': 'Claiming mining does not require an ad.',
    };
  }

  @Deprecated(
    'Claim ads are no longer part of the mining flow. '
    'Use claimMining() directly.',
  )
  Future<Map<String, dynamic>> getClaimAdStatus() async {
    return <String, dynamic>{
      'success': false,
      'message': 'Claiming mining does not require an ad.',
    };
  }
}
