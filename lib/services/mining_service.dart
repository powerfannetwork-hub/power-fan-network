import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class MiningService {
  MiningService._internal();

  static final MiningService _instance = MiningService._internal();

  /// Backward-compatible singleton.
  ///
  /// Other files in the app use:
  /// MiningService.instance
  static MiningService get instance => _instance;

  /// Also keep the old factory style:
  /// MiningService()
  factory MiningService() {
    return _instance;
  }

  final SupabaseClient _client = SupabaseService.client;

  static const int miningDurationSeconds = 86400;
  static const int maxAdsPerSession = 7;
  static const double defaultMiningRate = 0.20;

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

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

    if (value is double) return value.round();

    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? fallback;
  }

  double _toDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;

    if (value is double) return value;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? fallback;
  }

  bool _toBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;

    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().toLowerCase().trim();

    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }

    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }

    return fallback;
  }

  Map<String, dynamic> _normalize(dynamic response) {
    if (response == null) {
      return <String, dynamic>{};
    }

    if (response is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response);
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return <String, dynamic>{};
  }

  // ------------------------------------------------------------
  // PROFILE
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // GET FAN BALANCE
  // ------------------------------------------------------------

  Future<double> getFanBalance() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return 0;
    }

    try {
      final row = await _client
          .from('profiles')
          .select('fan_balance')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) {
        return 0;
      }

      return _toDouble(
        row['fan_balance'],
        0,
      );
    } catch (_) {
      return 0;
    }
  }

  // ------------------------------------------------------------
  // GET ADS WATCHED
  //
  // Keep this method because other parts of the old app use:
  // MiningService.instance.getAdsWatched()
  //
  // We first use the active mining RPC because the server is the
  // authority for the current session.
  // ------------------------------------------------------------

  Future<int> getAdsWatched() async {
    try {
      final data = await getActiveMining();

      return _toInt(
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
        0,
      );
    } catch (_) {
      return 0;
    }
  }

  // ------------------------------------------------------------
  // START MINING
  //
  // Server decides everything.
  // Flutter does not decide whether a session has expired.
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> startMining() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'active': false,
          'claimable': false,
          'remaining_seconds': 0,
          'error': 'You must be signed in.',
        };
      }

      final response = await _client.rpc(
        'start_mining',
      );

      final data = _normalize(response);

      return _prepareMiningResult(data);
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'active': false,
        'claimable': false,
        'remaining_seconds': 0,
        'error': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'active': false,
        'claimable': false,
        'remaining_seconds': 0,
        'error': e.toString(),
      };
    }
  }

  // ------------------------------------------------------------
  // GET ACTIVE MINING
  //
  // Server returns remaining_seconds.
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getActiveMining() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'active': false,
          'claimable': false,
          'remaining_seconds': 0,
          'ads_watched': 0,
          'error': 'You must be signed in.',
        };
      }

      final response = await _client.rpc(
        'get_active_mining',
      );

      final data = _normalize(response);

      return _prepareMiningResult(data);
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'active': false,
        'claimable': false,
        'remaining_seconds': 0,
        'ads_watched': 0,
        'error': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'active': false,
        'claimable': false,
        'remaining_seconds': 0,
        'ads_watched': 0,
        'error': e.toString(),
      };
    }
  }

  // ------------------------------------------------------------
  // NORMALIZE SERVER RESULT
  // ------------------------------------------------------------

  Map<String, dynamic> _prepareMiningResult(
    Map<String, dynamic> data,
  ) {
    final status = data['status']?.toString().toLowerCase();

    final active =
        _toBool(data['active']) ||
        status == 'active';

    final claimable =
        _toBool(data['claimable']) ||
        _toBool(data['claim_required']) ||
        status == 'ready_to_claim' ||
        status == 'claimable' ||
        status == 'expired' ||
        status == 'ended';

    final remainingSeconds = _toInt(
      _value(
        data,
        [
          'remaining_seconds',
          'remaining',
          'seconds_remaining',
        ],
        0,
      ),
      0,
    );

    final rate = _toDouble(
      _value(
        data,
        [
          'rate',
          'mining_rate',
          'total_rate',
        ],
        defaultMiningRate,
      ),
      defaultMiningRate,
    );

    final totalRate = _toDouble(
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
          'reward_amount',
        ],
        0,
      ),
      0,
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
      0,
    );

    return {
      ...data,

      'success': data['success'] ?? true,

      'active': active,

      'claimable': claimable,

      'remaining_seconds':
          remainingSeconds < 0 ? 0 : remainingSeconds,

      'rate': rate,

      'mining_rate': rate,

      'total_rate': totalRate,

      'reward': reward,

      'session_reward': reward,

      'ads_watched': adsWatched,

      'ad_count': adsWatched,
    };
  }

  // ------------------------------------------------------------
  // CURRENT MINING RATE
  // ------------------------------------------------------------

  Future<double> getUserMiningRate() async {
    try {
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

      return _toDouble(
        response,
        defaultMiningRate,
      );
    } catch (_) {
      return defaultMiningRate;
    }
  }

  // ------------------------------------------------------------
  // CLAIM MINING
  //
  // Backend decides whether the 24 hours are actually complete.
  // No local DateTime check here.
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> claimMining() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'error': 'You must be signed in.',
        };
      }

      final response = await _client.rpc(
        'claim_mining',
      );

      final data = _normalize(response);

      return {
        ...data,
        'success': data['success'] ?? true,
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ------------------------------------------------------------
  // REQUEST CLAIM AD
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> requestClaimAd() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'error': 'You must be signed in.',
        };
      }

      final response = await _client.rpc(
        'request_claim_ad',
      );

      return _normalize(response);
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ------------------------------------------------------------
  // CLAIM AD STATUS
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> getClaimAdStatus() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'error': 'You must be signed in.',
        };
      }

      final response = await _client.rpc(
        'get_claim_ad_status',
      );

      return _normalize(response);
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'error': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
