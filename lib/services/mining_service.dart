import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _client = SupabaseService.client;

  static const int miningDurationSeconds = 86400;
  static const int maxAdsPerSession = 7;

  static const double defaultMiningRate = 0.20;
  static const double adBoostPerAd = 0.10;
  static const double referralBoostPerReferral = 0.02;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.id;
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, dynamic>> getProfile() async {
    return SupabaseService.safeCall(() async {
      final result = await _client
          .from('profiles')
          .select()
          .eq('id', _userId)
          .single();

      return Map<String, dynamic>.from(result);
    });
  }

  // ============================================================
  // ACTIVE MINING
  // ============================================================

  Future<Map<String, dynamic>> getActiveMining() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_active_mining',
      );

      return _mapFromRpcResult(result);
    });
  }

  Map<String, dynamic> _emptyMining() {
    return {
      'success': true,
      'active': false,
      'is_mining': false,
      'mining_active': false,
      'expired': false,
      'claimable': false,
      'session_finished': false,
      'remaining_seconds': 0,
      'elapsed_seconds': 0,
      'ads_watched': 0,
      'ad_boost': 0.0,
      'active_referrals': 0,
      'mining_rate': defaultMiningRate,
      'reward': 0.0,
    };
  }

  // ============================================================
  // MINING RATE
  // ============================================================

  Future<double> getUserMiningRate() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_user_mining_rate',
      );

      final rate = _toDouble(result);

      if (rate <= 0) {
        return defaultMiningRate;
      }

      return double.parse(
        rate.toStringAsFixed(2),
      );
    });
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<Map<String, dynamic>> startMining() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'start_mining',
      );

      return _mapFromRpcResult(result);
    });
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<Map<String, dynamic>> claimMining() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'claim_mining',
      );

      return _mapFromRpcResult(result);
    });
  }

  // ============================================================
  // RECORD REWARDED AD
  // ============================================================

  Future<Map<String, dynamic>> recordRewardedAd() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'record_rewarded_ad',
      );

      return _mapFromRpcResult(result);
    });
  }

  // ============================================================
  // VERIFY REWARDED AD
  // ============================================================

  Future<Map<String, dynamic>> verifyRewardedAd(
    String adId,
  ) async {
    final trimmedAdId = adId.trim();

    if (trimmedAdId.isEmpty) {
      throw Exception(
        'Ad ID is missing.',
      );
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': trimmedAdId,
        },
      );

      return _mapFromRpcResult(result);
    });
  }

  // ============================================================
  // RECORD + VERIFY REWARDED AD
  // ============================================================

  Future<Map<String, dynamic>> recordAndVerifyRewardedAd() async {
    final recorded = await recordRewardedAd();

    if (recorded['success'] != true) {
      return recorded;
    }

    final adId = recorded['ad_id']?.toString();

    if (adId == null || adId.isEmpty) {
      throw Exception(
        'Ad was recorded but no ad ID was returned.',
      );
    }

    final verified = await verifyRewardedAd(adId);

    return {
      ...recorded,
      ...verified,
      'recorded': true,
      'verified': verified['verified'] == true,
    };
  }

  // ============================================================
  // ADS WATCHED
  // ============================================================

  Future<int> getAdsWatched() async {
    final activeMining = await getActiveMining();

    final value =
        activeMining['ads_watched'] ??
        activeMining['ad_count'] ??
        activeMining['ads_count'] ??
        0;

    return _clampInt(
      _toInt(value),
      0,
      maxAdsPerSession,
    );
  }

  // ============================================================
  // ACTIVE REFERRALS
  // ============================================================

  Future<int> getActiveReferrals() async {
    final activeMining = await getActiveMining();

    final value =
        activeMining['active_referrals'] ??
        activeMining['referrals'] ??
        0;

    return _toInt(value);
  }

  // ============================================================
  // AD BOOST
  // ============================================================

  Future<double> getAdBoost() async {
    final activeMining = await getActiveMining();

    final value =
        activeMining['ad_boost'] ??
        0.0;

    return _toDouble(value);
  }

  // ============================================================
  // IS MINING
  // ============================================================

  Future<bool> isMining() async {
    final activeMining = await getActiveMining();

    final active =
        activeMining['active'] ??
        activeMining['is_mining'] ??
        activeMining['mining_active'] ??
        activeMining['is_active'] ??
        false;

    return active == true;
  }

  // ============================================================
  // IS CLAIMABLE
  // ============================================================

  Future<bool> isClaimable() async {
    final activeMining = await getActiveMining();

    return activeMining['claimable'] == true;
  }

  // ============================================================
  // IS EXPIRED
  // ============================================================

  Future<bool> isExpired() async {
    final activeMining = await getActiveMining();

    return activeMining['expired'] == true ||
        activeMining['session_finished'] == true ||
        activeMining['claimable'] == true;
  }

  // ============================================================
  // MINING END TIME
  // ============================================================

  Future<DateTime?> getMiningEndsAt() async {
    final activeMining = await getActiveMining();

    final value =
        activeMining['ends_at'] ??
        activeMining['end_time'] ??
        activeMining['expires_at'];

    return _parseDateTime(value);
  }

  // ============================================================
  // MINING START TIME
  // ============================================================

  Future<DateTime?> getMiningStartedAt() async {
    final activeMining = await getActiveMining();

    final value =
        activeMining['started_at'] ??
        activeMining['start_time'];

    return _parseDateTime(value);
  }

  // ============================================================
  // REMAINING TIME
  // ============================================================

  Future<Duration> getRemainingTime() async {
    final activeMining = await getActiveMining();

    final remainingSeconds = _toInt(
      activeMining['remaining_seconds'],
    );

    if (remainingSeconds > 0) {
      return Duration(
        seconds: _clampInt(
          remainingSeconds,
          0,
          miningDurationSeconds,
        ),
      );
    }

    final endsAt = _parseDateTime(
      activeMining['ends_at'] ??
          activeMining['end_time'] ??
          activeMining['expires_at'],
    );

    if (endsAt == null) {
      final startedAt = _parseDateTime(
        activeMining['started_at'] ??
            activeMining['start_time'],
      );

      if (startedAt == null) {
        return Duration.zero;
      }

      final calculatedEnd = startedAt.add(
        const Duration(
          seconds: miningDurationSeconds,
        ),
      );

      final remaining = calculatedEnd.difference(
        DateTime.now(),
      );

      return remaining.isNegative
          ? Duration.zero
          : remaining;
    }

    final remaining = endsAt.difference(
      DateTime.now(),
    );

    return remaining.isNegative
        ? Duration.zero
        : remaining;
  }

  // ============================================================
  // ELAPSED TIME
  // ============================================================

  Future<Duration> getElapsedTime() async {
    final activeMining = await getActiveMining();

    final elapsedSeconds = _toInt(
      activeMining['elapsed_seconds'],
    );

    if (elapsedSeconds > 0) {
      return Duration(
        seconds: _clampInt(
          elapsedSeconds,
          0,
          miningDurationSeconds,
        ),
      );
    }

    final startedAt = _parseDateTime(
      activeMining['started_at'] ??
          activeMining['start_time'],
    );

    if (startedAt == null) {
      final endsAt = _parseDateTime(
        activeMining['ends_at'] ??
            activeMining['end_time'] ??
            activeMining['expires_at'],
      );

      if (endsAt != null) {
        final calculatedStart = endsAt.subtract(
          const Duration(
            seconds: miningDurationSeconds,
          ),
        );

        final elapsed = DateTime.now().difference(
          calculatedStart,
        );

        if (elapsed.isNegative) {
          return Duration.zero;
        }

        return Duration(
          seconds: _clampInt(
            elapsed.inSeconds,
            0,
            miningDurationSeconds,
          ),
        );
      }

      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(
      startedAt,
    );

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return Duration(
      seconds: _clampInt(
        elapsed.inSeconds,
        0,
        miningDurationSeconds,
      ),
    );
  }

  // ============================================================
  // FAN EARNED SO FAR
  //
  // IMPORTANT:
  // The server is the source of truth.
  //
  // The mining engine calculates:
  //   Base reward
  //   + time-weighted ad reward
  //   + time-weighted referral reward
  //
  // Therefore the Flutter app must NOT calculate:
  //   currentRate × totalElapsedTime
  //
  // because that would incorrectly give earlier hours
  // the later ad boost.
  // ============================================================

  Future<double> getEstimatedEarned() async {
    final mining = await getActiveMining();

    final serverReward = _toDouble(
      mining['reward'],
    );

    if (serverReward > 0) {
      return serverReward;
    }

    if (mining['claimable'] == true) {
      return 0.0;
    }

    return 0.0;
  }

  // ============================================================
  // SESSION REWARD
  // ============================================================

  Future<double> getCurrentReward() async {
    final mining = await getActiveMining();

    return _toDouble(
      mining['reward'],
    );
  }

  // ============================================================
  // SESSION ID
  // ============================================================

  Future<String?> getMiningSessionId() async {
    final mining = await getActiveMining();

    final value = mining['session_id'];

    if (value == null) {
      return null;
    }

    final id = value.toString().trim();

    return id.isEmpty ? null : id;
  }

  // ============================================================
  // MINING STATUS
  // ============================================================

  Future<Map<String, dynamic>> getMiningStatus() async {
    final mining = await getActiveMining();

    final remainingSeconds = _clampInt(
      _toInt(
        mining['remaining_seconds'],
      ),
      0,
      miningDurationSeconds,
    );

    final elapsedSeconds = _clampInt(
      _toInt(
        mining['elapsed_seconds'],
      ),
      0,
      miningDurationSeconds,
    );

    final adsWatched = _clampInt(
      _toInt(
        mining['ads_watched'],
      ),
      0,
      maxAdsPerSession,
    );

    return {
      ...mining,
      'is_mining':
          mining['active'] == true ||
          mining['mining_active'] == true,
      'claimable':
          mining['claimable'] == true,
      'expired':
          mining['expired'] == true,
      'remaining_seconds':
          remainingSeconds,
      'elapsed_seconds':
          elapsedSeconds,
      'ads_watched':
          adsWatched,
    };
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _mapFromRpcResult(
    dynamic result,
  ) {
    if (result == null) {
      return _emptyMining();
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List &&
        result.isNotEmpty &&
        result.first is Map) {
      return Map<String, dynamic>.from(
        result.first as Map,
      );
    }

    return {
      'result': result,
    };
  }

  int _toInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
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

  // ============================================================
  // DATE / TIMESTAMP PARSER
  //
  // Supports:
  // - DateTime
  // - ISO strings
  // - Unix seconds
  // - Unix milliseconds
  // - numeric strings
  // ============================================================

  DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is num) {
      return _fromTimestamp(value);
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final parsedIso = DateTime.tryParse(
      text,
    );

    if (parsedIso != null) {
      return parsedIso.toLocal();
    }

    final numeric = num.tryParse(
      text,
    );

    if (numeric != null) {
      return _fromTimestamp(
        numeric,
      );
    }

    return null;
  }

  DateTime? _fromTimestamp(
    num timestamp,
  ) {
    try {
      final value = timestamp.toInt();

      // Milliseconds timestamp.
      if (value.abs() >= 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(
          value,
          isUtc: true,
        ).toLocal();
      }

      // Seconds timestamp.
      return DateTime.fromMillisecondsSinceEpoch(
        value * 1000,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return null;
    }
  }
}
