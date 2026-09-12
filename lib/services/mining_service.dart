import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class MiningService {
  MiningService._internal();

  static final MiningService _instance = MiningService._internal();

  factory MiningService() {
    return _instance;
  }

  /// Backward-compatible singleton access.
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

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;

    if (value is double) return value;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? fallback;
  }

  bool _toBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;

    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().trim().toLowerCase();

    if (text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'active' ||
        text == 'claimable') {
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
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(value.toString())?.toLocal();
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
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      final first = raw.first;

      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(first);
      }

      if (first is Map) {
        return first.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // START MINING
  //
  // IMPORTANT:
  // Activation Ad is handled by LevelPlayAdsService/HomeScreen.
  // This method ONLY starts the mining session.
  // ============================================================

  Future<Map<String, dynamic>> startMining() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await _client.rpc('start_mining');

    return _prepareMiningResult(response);
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

    // If the backend returned an end time, calculate the remaining
    // time again on the client so the countdown stays accurate.
    if (endsAt != null) {
      final calculatedRemaining =
          endsAt.difference(DateTime.now()).inSeconds;

      if (calculatedRemaining >= 0) {
        remainingSeconds = calculatedRemaining;
      } else {
        remainingSeconds = 0;
      }
    }

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

    final adsWatched = _toInt(
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

    final normalized = <String, dynamic>{
      ...data,

      'active': active,
      'claimable': claimable,
      'expired': expired,

      'started_at': startedAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),

      'remaining_seconds': remainingSeconds,

      'rate': rate,
      'mining_rate': rate,
      'total_rate': rate,

      'reward': reward,
      'session_reward': reward,

      'ads_watched': adsWatched,

      'status': status,
    };

    return normalized;
  }

  // ============================================================
  // CHECK IF CURRENT USER IS MINING
  // ============================================================

  Future<bool> isMining() async {
    final result = await getActiveMining();

    return _toBool(
      result['active'],
      false,
    );
  }

  // ============================================================
  // CHECK IF CURRENT USER CAN CLAIM
  // ============================================================

  Future<bool> isClaimable() async {
    final result = await getActiveMining();

    if (_toBool(result['claimable'], false)) {
      return true;
    }

    final status = result['status']?.toString().trim().toLowerCase();

    return status == 'claimable' ||
        status == 'ready_to_claim' ||
        status == 'completed' ||
        status == 'expired' ||
        status == 'ended' ||
        status == 'pending_claim';
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

    final response = await _client.rpc(
      'get_user_mining_rate',
      params: {
        'p_user_id': user.id,
      },
    );

    if (response is num) {
      return response.toDouble();
    }

    final data = _normalize(response);

    return _toDouble(
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
  }

  // ============================================================
  // GET ADS WATCHED
  //
  // These are BOOST ADS for the CURRENT mining session.
  // Activation Ad is NOT counted here.
  // ============================================================

  Future<int> getAdsWatched() async {
    final result = await getActiveMining();

    return _toInt(
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
  }

  // ============================================================
  // CLAIM MINING
  //
  // IMPORTANT:
  // CLAIM DOES NOT REQUIRE AN AD.
  //
  // Correct flow:
  //
  // 1. 24h expires
  // 2. User presses CLAIM
  // 3. claim_mining runs directly
  // 4. User presses START MINING
  // 5. HomeScreen shows Activation Ad
  // 6. After Activation Ad reward -> startMining()
  // ============================================================

  Future<Map<String, dynamic>> claimMining() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await _client.rpc('claim_mining');

    return _normalize(response);
  }

  // ============================================================
  // BACKWARD COMPATIBILITY
  //
  // These methods are intentionally NOT used by the new mining
  // flow. Claiming no longer requires an ad.
  //
  // They are kept here so other old code will not fail to compile
  // if it still references them.
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
