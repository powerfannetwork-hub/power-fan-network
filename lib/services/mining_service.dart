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

  Future<Map<String, dynamic>> getActiveMining() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_active_mining',
        params: {
          'p_user_id': _userId,
        },
      );

      if (result == null) {
        return {
          'is_mining': false,
        };
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'is_mining': false,
      };
    });
  }

  Future<double> getUserMiningRate() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_user_mining_rate',
        params: {
          'p_user_id': _userId,
        },
      );

      final rate = _toDouble(result);

      if (rate <= 0) {
        return 0.20;
      }

      return double.parse(rate.toStringAsFixed(2));
    });
  }

  Future<void> startMining() async {
    await SupabaseService.safeCall(() async {
      await _client.rpc(
        'start_mining',
        params: {
          'p_user_id': _userId,
        },
      );
    });
  }

  Future<Map<String, dynamic>> claimMining() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'claim_mining',
        params: {
          'p_user_id': _userId,
        },
      );

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
    });
  }

  Future<Map<String, dynamic>> recordRewardedAd() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'record_rewarded_ad',
        params: {
          'p_user_id': _userId,
        },
      );

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
    });
  }

  Future<Map<String, dynamic>> verifyRewardedAd() async {
    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'verify_rewarded_ad',
        params: {
          'p_user_id': _userId,
        },
      );

      if (result == null) {
        return <String, dynamic>{};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first);
      }

      return {
        'result': result,
      };
    });
  }

  Future<int> getAdsWatched() async {
    final activeMining = await getActiveMining();

    final value = activeMining['ads_watched'] ??
        activeMining['ad_count'] ??
        activeMining['ads_count'] ??
        0;

    final count = _toInt(value);

    return count.clamp(0, 7);
  }

  Future<bool> isMining() async {
    final activeMining = await getActiveMining();

    final value = activeMining['is_mining'] ??
        activeMining['is_active'] ??
        false;

    return value == true;
  }

  Future<DateTime?> getMiningEndsAt() async {
    final activeMining = await getActiveMining();

    return _parseDateTime(
      activeMining['ends_at'] ??
          activeMining['end_time'] ??
          activeMining['expires_at'],
    );
  }

  Future<Duration> getRemainingTime() async {
    final endsAt = await getMiningEndsAt();

    if (endsAt == null) {
      return Duration.zero;
    }

    final remaining = endsAt.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
