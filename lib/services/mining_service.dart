import 'package:supabase_flutter/supabase_flutter.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current user's mining rate.
  ///
  /// Base rate = 0.20 FAN/H
  /// Ad boost = +0.10 FAN/H per ad
  /// Referral boost = +0.02 FAN/H per active referral
  Future<double> getMiningRate() async {
    final result = await _supabase.rpc('get_user_mining_rate');

    if (result == null) {
      return 0.20;
    }

    if (result is num) {
      return result.toDouble();
    }

    return double.tryParse(result.toString()) ?? 0.20;
  }

  /// Start a new 24-hour mining session.
  Future<Map<String, dynamic>> startMining() async {
    final result = await _supabase.rpc('start_mining');

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw Exception('Unable to start mining.');
  }

  /// Get the user's currently active mining session.
  Future<Map<String, dynamic>> getActiveMining() async {
    final result = await _supabase.rpc('get_active_mining');

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw Exception('Unable to get active mining session.');
  }

  /// Claim the FAN earned from the active mining session.
  Future<Map<String, dynamic>> claimMining() async {
    final result = await _supabase.rpc('claim_mining');

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw Exception('Unable to claim mining reward.');
  }

  /// Convenience method to determine whether mining is currently active.
  Future<bool> isMiningActive() async {
    try {
      final result = await getActiveMining();

      return result['active'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Get the active mining session data.
  Future<MiningSession?> getSession() async {
    try {
      final result = await getActiveMining();

      if (result['active'] != true) {
        return null;
      }

      return MiningSession(
        sessionId: result['session_id']?.toString(),
        startedAt: _parseDate(result['started_at']),
        endsAt: _parseDate(result['ends_at']),
        rate: _parseDouble(result['rate']),
      );
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  double _parseDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }
}

class MiningSession {
  final String? sessionId;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final double rate;

  const MiningSession({
    required this.sessionId,
    required this.startedAt,
    required this.endsAt,
    required this.rate,
  });

  bool get isActive {
    if (endsAt == null) {
      return false;
    }

    return DateTime.now().isBefore(endsAt!);
  }

  Duration get remaining {
    if (endsAt == null) {
      return Duration.zero;
    }

    final difference = endsAt!.difference(DateTime.now());

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  Duration get elapsed {
    if (startedAt == null) {
      return Duration.zero;
    }

    final difference = DateTime.now().difference(startedAt!);

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  double get estimatedEarned {
    final hours = elapsed.inSeconds / 3600.0;

    return hours * rate;
  }
}
