import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class DailySpinService {
  DailySpinService._internal();

  static final DailySpinService _instance =
      DailySpinService._internal();

  factory DailySpinService() {
    return _instance;
  }

  static DailySpinService get instance => _instance;

  final SupabaseClient _client = SupabaseService.client;

  // ============================================================
  // GET DAILY SPIN STATUS
  //
  // Server is authoritative.
  // The client does NOT calculate whether the user has spun today.
  // ============================================================

  Future<Map<String, dynamic>> getStatus() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await SupabaseService.safeCall(
      () => _client.rpc('get_daily_spin_status'),
    );

    return _normalize(response);
  }

  // ============================================================
  // SPIN
  //
  // The reward is selected by PostgreSQL.
  //
  // Flutter does NOT:
  // - choose the reward
  // - calculate the probability
  // - add FAN to the balance
  // - write wallet transactions
  //
  // All reward processing happens inside spin_daily().
  // ============================================================

  Future<Map<String, dynamic>> spin() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    final response = await SupabaseService.safeCall(
      () => _client.rpc('spin_daily'),
    );

    return _normalize(response);
  }

  // ============================================================
  // AUTH CHECK
  // ============================================================

  bool get isSignedIn {
    return _client.auth.currentUser != null;
  }

  // ============================================================
  // CURRENT USER ID
  // ============================================================

  String? get userId {
    return _client.auth.currentUser?.id;
  }

  // ============================================================
  // NORMALIZE SUPABASE RPC RESPONSE
  // ============================================================

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
  // SAFE VALUE HELPERS
  // ============================================================

  bool isSuccess(Map<String, dynamic> data) {
    final value = data['success'];

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  bool canSpin(Map<String, dynamic> data) {
    final value = data['can_spin'];

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  bool alreadySpun(Map<String, dynamic> data) {
    final value = data['already_spun'] ??
        data['spun_today'];

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  double fanAmount(Map<String, dynamic> data) {
    final value = data['fan_amount'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  double fanBalance(Map<String, dynamic> data) {
    final value = data['fan_balance'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  String rewardTitle(Map<String, dynamic> data) {
    return data['reward_title']?.toString() ??
        '';
  }

  String rewardCode(Map<String, dynamic> data) {
    return data['reward_code']?.toString() ??
        '';
  }

  String rewardType(Map<String, dynamic> data) {
    return data['reward_type']?.toString() ??
        '';
  }

  int boostDurationMinutes(
    Map<String, dynamic> data,
  ) {
    final value =
        data['boost_duration_minutes'];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  double boostRatePerHour(
    Map<String, dynamic> data,
  ) {
    final value =
        data['boost_rate_per_hour'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  String message(Map<String, dynamic> data) {
    return data['message']?.toString() ??
        '';
  }
}
