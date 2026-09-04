import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _client = SupabaseService.client;

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
        return {
          'active': false,
          'expired': false,
          'claimable': false,
          'remaining_seconds': 0,
          'elapsed_seconds': 0,
          'ads_watched': 0,
        };
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
        'active': false,
        'expired': false,
        'claimable': false,
        'remaining_seconds': 0,
        'elapsed_seconds': 0,
        'ads_watched': 0,
      };
    });
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
        return 0.20;
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
  //
  // This creates the ad record and returns ad_id.
  // It does NOT verify the ad yet.
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
  //
  // Must receive the ad_id returned by recordRewardedAd().
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
  //
  // This helper is useful for the development/test flow.
  // Production AppLovin flow should call record first,
  // then verify ONLY after the rewarded ad is actually completed.
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

    final count = _toInt(value);

    return count.clamp(0, 7);
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

    final claimable =
        activeMining['claimable'] ?? false;

    return claimable == true;
  }

  // ============================================================
  // IS EXPIRED
  // ============================================================

  Future<bool> isExpired() async {
    final activeMining = await getActiveMining();

    final expired =
        activeMining['expired'] ?? false;

    return expired == true;
  }

  // ============================================================
  // MINING END TIME
  // ============================================================

  Future<DateTime?> getMiningEndsAt() async {
    final activeMining = await getActiveMining();

    return _parseDateTime(
      activeMining['ends_at'] ??
          activeMining['end_time'] ??
          activeMining['expires_at'],
    );
  }

  // ============================================================
  // MINING START TIME
  // ============================================================

  Future<DateTime?> getMiningStartedAt() async {
    final activeMining = await getActiveMining();

    return _parseDateTime(
      activeMining['started_at'] ??
          activeMining['start_time'],
    );
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
      activeMining['ends_at'],
    );

    if (endsAt == null) {
      return Duration.zero;
    }

    final remaining =
        endsAt.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
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
        seconds: elapsedSeconds,
      );
    }

    final startedAt = _parseDateTime(
      activeMining['started_at'],
    );

    if (startedAt == null) {
      return Duration.zero;
    }

    final elapsed =
        DateTime.now().difference(startedAt);

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return elapsed;
  }

  // ============================================================
  // FAN EARNED SO FAR
  //
  // This is calculated locally for display only.
  // The database remains the final source of truth.
  // ============================================================

  Future<double> getEstimatedEarned() async {
    final mining = await getActiveMining();

    final rate = _toDouble(
      mining['rate'],
    );

    final elapsedSeconds = _toInt(
      mining['elapsed_seconds'],
    );

    if (rate <= 0 || elapsedSeconds <= 0) {
      return 0.0;
    }

    final earned =
        rate * (elapsedSeconds / 3600.0);

    return earned;
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

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }
}
