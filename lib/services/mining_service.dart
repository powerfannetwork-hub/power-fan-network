import 'package:supabase_flutter/supabase_flutter.dart';

class MiningService {
  MiningService._();

  static final MiningService instance = MiningService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _requireUser() async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    if (session == null || user == null) {
      throw const AuthException(
        'Your session has expired. Please log in again.',
      );
    }
  }

  Map<String, dynamic> _mapResult(dynamic result) {
    if (result == null) {
      return <String, dynamic>{};
    }

    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;

      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    if (result is num) {
      return <String, dynamic>{
        'rate': result.toDouble(),
      };
    }

    throw Exception(
      'Unexpected Supabase response: ${result.runtimeType}',
    );
  }

  Exception _formatSupabaseError(
    Object error, {
    required String action,
  }) {
    if (error is PostgrestException) {
      final message = error.message.trim();
      final details = error.details?.toString().trim() ?? '';
      final hint = error.hint?.trim() ?? '';
      final code = error.code?.trim() ?? '';

      final parts = <String>[
        if (message.isNotEmpty) message,
        if (code.isNotEmpty) 'Code: $code',
        if (details.isNotEmpty && details != 'Bad Request')
          'Details: $details',
        if (hint.isNotEmpty) 'Hint: $hint',
      ];

      return Exception(
        parts.isEmpty
            ? 'Unable to $action.'
            : parts.join('\n'),
      );
    }

    if (error is AuthException) {
      return Exception(error.message);
    }

    return Exception(
      'Unable to $action.\n$error',
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      await _requireUser();

      final user = _supabase.auth.currentUser!;

      final response = await _supabase
          .from('profiles')
          .select('fan_balance, afam_balance')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return <String, dynamic>{
          'fan_balance': 0.0,
          'afam_balance': 0.0,
        };
      }

      return Map<String, dynamic>.from(response);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'load account balance',
      );
    }
  }

  Future<int> getAdsWatchedToday() async {
    try {
      await _requireUser();

      final user = _supabase.auth.currentUser!;

      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final endOfDay =
          startOfDay.add(const Duration(days: 1));

      final rows = await _supabase
          .from('ad_boosts')
          .select('id')
          .eq('user_id', user.id)
          .gte(
            'created_at',
            startOfDay.toUtc().toIso8601String(),
          )
          .lt(
            'created_at',
            endOfDay.toUtc().toIso8601String(),
          );

      if (rows is List) {
        return rows.length > 7 ? 7 : rows.length;
      }

      return 0;
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'load today\'s ad count',
      );
    }
  }

  Future<Map<String, dynamic>> getUserMiningRate() async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'get_user_mining_rate',
      );

      if (result is num) {
        return <String, dynamic>{
          'rate': result.toDouble(),
        };
      }

      final data = _mapResult(result);

      if (data['rate'] == null &&
          data['mining_rate'] == null &&
          data['value'] == null) {
        return <String, dynamic>{
          ...data,
          'rate': 0.2,
        };
      }

      return data;
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'load mining rate',
      );
    }
  }

  Future<Map<String, dynamic>> startMining() async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'start_mining',
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'start mining',
      );
    }
  }

  Future<Map<String, dynamic>> getActiveMining() async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'get_active_mining',
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'load mining session',
      );
    }
  }

  Future<Map<String, dynamic>> claimMining() async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'claim_mining',
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'claim mining reward',
      );
    }
  }

  Future<Map<String, dynamic>> recordRewardedAd({
    String? adRef,
  }) async {
    try {
      await _requireUser();

      /*
       * p_ad_ref has a database default value.
       *
       * Calling the RPC without parameters is safer than
       * sending a parameter name that may be stale in the
       * PostgREST schema cache.
       *
       * The local reference is therefore not trusted as proof
       * of an advertisement. Final ad verification must be
       * handled by the rewarded-ad verification flow.
       */
      final result = await _supabase.rpc(
        'record_rewarded_ad',
      );

      final data = _mapResult(result);

      return <String, dynamic>{
        ...data,
        'ad_ref': adRef,
      };
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'record rewarded ad',
      );
    }
  }

  Future<Map<String, dynamic>> verifyRewardedAd({
    required String adId,
  }) async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'verify_rewarded_ad',
        params: <String, dynamic>{
          'p_ad_id': adId,
        },
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'verify rewarded ad',
      );
    }
  }

  Future<Map<String, dynamic>> dailyCheckin() async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'daily_checkin',
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'complete daily check-in',
      );
    }
  }

  Future<Map<String, dynamic>> completeDailySocialTask({
    required String taskId,
  }) async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'complete_daily_social_task',
        params: <String, dynamic>{
          'p_task_id': taskId,
        },
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'complete social task',
      );
    }
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      await _requireUser();

      final result = await _supabase.rpc(
        'get_dashboard',
      );

      return _mapResult(result);
    } catch (error) {
      throw _formatSupabaseError(
        error,
        action: 'load dashboard',
      );
    }
  }
}
