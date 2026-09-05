import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _client = SupabaseService.client;

  static const int miningDurationSeconds = 86400;
  static const double defaultMiningRate = 0.20;

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

      if (result == null) {
        return _emptyMining();
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List &&
          result.isNotEmpty &&
          result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return _emptyMining();
    });
  }

  Map<String, dynamic> _emptyMining() {
    return {
      'active': false,
      'expired': false,
      'claimable': false,
      'remaining_seconds': 0,
      'elapsed_seconds': 0,
      'ads_watched': 0,
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

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List &&
          result.isNotEmpty &&
          result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
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

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List &&
          result.isNotEmpty &&
          result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
    });
  }

  // ============================================================
  // RECORD REWARDED AD
  // ============================================================

  Future<Map<String, dynamic>> recordRewardedAd({
    String? adReference,
  }) async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'record_rewarded_ad',
        params: {
          'p_ad_reference': adReference,
        },
      );

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List &&
          result.isNotEmpty &&
          result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
    });
  }

  // ============================================================
  // VERIFY REWARDED AD
  // ============================================================

  Future<Map<String, dynamic>> verifyRewardedAd(
    String adId,
  ) async {
    if (adId.trim().isEmpty) {
      throw Exception('Ad ID is missing.');
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': adId,
        },
      );

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List &&
          result.isNotEmpty &&
          result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
    });
  }

  // ============================================================
  // WATCH + VERIFY
  // ============================================================

  Future<Map<String, dynamic>> recordAndVerifyRewardedAd({
    String? adReference,
  }) async {
    final recorded = await recordRewardedAd(
      adReference: adReference,
    );

    final success = recorded['success'] == true;

    if (!success) {
      return recorded;
    }

    final adId = recorded['ad_id']?.toString();

    if (adId == null || adId.isEmpty) {
      throw Exception(
        'Ad was recorded but no ad ID was returned.',
      );
    }

    return verifyRewardedAd(adId);
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

    return _toInt(value).clamp(0, 7);
  }

  // ============================================================
  // IS MINING
  // ============================================================

  Future<bool> isMining() async {
    final activeMining = await getActiveMining();

    final active =
        activeMining['active'] ??
        activeMining['is_mining'] ??
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

    return activeMining['expired'] == true;
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
        seconds: remainingSeconds,
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
        const Duration(seconds: miningDurationSeconds),
      );

      final remaining =
          calculatedEnd.difference(DateTime.now());

      return remaining.isNegative
          ? Duration.zero
          : remaining;
    }

    final remaining =
        endsAt.difference(DateTime.now());

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
        seconds: elapsedSeconds.clamp(
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
          const Duration(seconds: miningDurationSeconds),
        );

        final elapsed =
            DateTime.now().difference(calculatedStart);

        if (elapsed.isNegative) {
          return Duration.zero;
        }

        return Duration(
          seconds: elapsed.inSeconds.clamp(
            0,
            miningDurationSeconds,
          ),
        );
      }

      return Duration.zero;
    }

    final elapsed =
        DateTime.now().difference(startedAt);

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return Duration(
      seconds: elapsed.inSeconds.clamp(
        0,
        miningDurationSeconds,
      ),
    );
  }

  // ============================================================
  // FAN EARNED SO FAR
  //
  // DISPLAY ESTIMATE ONLY.
  // DATABASE REMAINS SOURCE OF TRUTH.
  // ============================================================

  Future<double> getEstimatedEarned() async {
    final mining = await getActiveMining();

    var rate = _toDouble(
      mining['rate'] ??
          mining['mining_rate'],
    );

    if (rate <= 0) {
      rate = await getUserMiningRate();
    }

    final elapsedSeconds = _toInt(
      mining['elapsed_seconds'],
    );

    if (elapsedSeconds > 0) {
      return rate *
          (elapsedSeconds / 3600.0);
    }

    final startedAt = _parseDateTime(
      mining['started_at'] ??
          mining['start_time'],
    );

    if (startedAt == null) {
      final endsAt = _parseDateTime(
        mining['ends_at'] ??
            mining['end_time'] ??
            mining['expires_at'],
      );

      if (endsAt == null) {
        return 0.0;
      }

      final calculatedStart = endsAt.subtract(
        const Duration(seconds: miningDurationSeconds),
      );

      final elapsed =
          DateTime.now().difference(calculatedStart);

      if (elapsed.isNegative) {
        return 0.0;
      }

      final seconds = elapsed.inSeconds.clamp(
        0,
        miningDurationSeconds,
      );

      return rate *
          (seconds / 3600.0);
    }

    final elapsed =
        DateTime.now().difference(startedAt);

    if (elapsed.isNegative) {
      return 0.0;
    }

    final seconds = elapsed.inSeconds.clamp(
      0,
      miningDurationSeconds,
    );

    return rate *
        (seconds / 3600.0);
  }

  // ============================================================
  // HELPERS
  // ============================================================

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

  DateTime? _parseDateTime(dynamic value) {
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

    final parsedIso = DateTime.tryParse(text);

    if (parsedIso != null) {
      return parsedIso.toLocal();
    }

    final numeric = num.tryParse(text);

    if (numeric != null) {
      return _fromTimestamp(numeric);
    }

    return null;
  }

  DateTime? _fromTimestamp(num timestamp) {
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
