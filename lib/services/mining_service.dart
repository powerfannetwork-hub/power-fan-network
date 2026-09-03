import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

class MiningService {
  MiningService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final MiningService instance = MiningService();

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  String? get _userId => _client.auth.currentUser?.id;

  void _requireAuthenticated() {
    if (_userId == null) {
      throw const AuthException('User is not authenticated.');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List && data.isNotEmpty) {
      final first = data.first;

      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(first);
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is! List) {
      return <Map<String, dynamic>>[];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  Future<Map<String, dynamic>?> getProfile() async {
    _requireAuthenticated();

    final userId = _userId!;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<double> getUserMiningRate() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcGetUserMiningRate,
    );

    if (data is num) {
      return data.toDouble();
    }

    final map = _asMap(data);

    return _asDouble(
      map['mining_rate'] ??
          map['rate'] ??
          map['current_rate'] ??
          AppConfig.baseMiningRate,
      fallback: AppConfig.baseMiningRate,
    );
  }

  Future<Map<String, dynamic>> startMining() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcStartMining,
    );

    return _asMap(data);
  }

  Future<Map<String, dynamic>?> getActiveMining() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcGetActiveMining,
    );

    final map = _asMap(data);

    if (map.isEmpty) {
      return null;
    }

    return map;
  }

  Future<Map<String, dynamic>> claimMining() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcClaimMining,
    );

    return _asMap(data);
  }

  Future<Map<String, dynamic>> recordRewardedAd() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcRecordRewardedAd,
    );

    return _asMap(data);
  }

  Future<Map<String, dynamic>> verifyRewardedAd(
    String adId,
  ) async {
    _requireAuthenticated();

    if (adId.trim().isEmpty) {
      throw ArgumentError('adId cannot be empty.');
    }

    final data = await _client.rpc(
      AppConfig.rpcVerifyRewardedAd,
      params: <String, dynamic>{
        'p_ad_id': adId,
      },
    );

    return _asMap(data);
  }

  Future<int> getAdsWatchedForSession({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    _requireAuthenticated();

    final start = startedAt.toUtc();

    final query = _client
        .from('ad_rewards')
        .select('id')
        .eq('user_id', _userId!)
        .gte('watched_at', start.toIso8601String());

    final response = endsAt == null
        ? await query
        : await query.lte(
            'watched_at',
            endsAt.toUtc().toIso8601String(),
          );

    return response.length;
  }

  Future<int> getSessionAdCount({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    return getAdsWatchedForSession(
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  Future<Map<String, dynamic>> dailyCheckin() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcDailyCheckin,
    );

    return _asMap(data);
  }

  Future<Map<String, dynamic>> completeDailySocialTask(
    String taskId,
  ) async {
    _requireAuthenticated();

    if (taskId.trim().isEmpty) {
      throw ArgumentError('taskId cannot be empty.');
    }

    final data = await _client.rpc(
      AppConfig.rpcClaimDailySocialReward,
      params: <String, dynamic>{
        'p_task_id': taskId,
      },
    );

    return _asMap(data);
  }

  Future<Map<String, dynamic>> getDashboard() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcGetDashboard,
    );

    return _asMap(data);
  }

  Future<Map<String, dynamic>> getMiningStatus() async {
    final active = await getActiveMining();
    final rate = await getUserMiningRate();

    final profile = await getProfile();

    return <String, dynamic>{
      'active': active != null,
      'mining': active,
      'rate': rate,
      'profile': profile,
    };
  }

  Future<int> getActiveReferralCount() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      'calculate_active_referrals',
      params: <String, dynamic>{
        'p_user_id': _userId!,
      },
    );

    if (data is num) {
      return data.toInt();
    }

    final map = _asMap(data);

    return _asInt(
      map['active_referrals'] ??
          map['count'] ??
          map['referrals'],
    );
  }

  Future<List<Map<String, dynamic>>> getMyMiningSessions({
    int limit = 20,
  }) async {
    _requireAuthenticated();

    final safeLimit = limit.clamp(1, 100);

    final response = await _client
        .from('mining_sessions')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(safeLimit);

    return _asMapList(response);
  }

  Future<Map<String, dynamic>?> getLatestMiningSession() async {
    _requireAuthenticated();

    final response = await _client
        .from('mining_sessions')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(1);

    if (response.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(response.first);
  }

  bool isSessionActive(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) {
      return false;
    }

    final status = session['status']?.toString().toLowerCase();

    if (status == 'active') {
      final endsAt = _asDateTime(
        session['ends_at'] ??
            session['mining_ends_at'],
      );

      if (endsAt == null) {
        return true;
      }

      return endsAt.isAfter(DateTime.now().toUtc());
    }

    final miningActive = session['mining_active'];

    if (miningActive is bool) {
      return miningActive;
    }

    return false;
  }

  double calculateMaximumAdBoost(int adsWatched) {
    final safeAds = adsWatched.clamp(
      0,
      AppConfig.maxAdsPerSession,
    );

    final boost =
        safeAds * AppConfig.adBoostPerAd;

    return boost.clamp(
      0,
      AppConfig.maxAdBoost,
    );
  }

  double calculateMiningRate({
    int activeReferrals = 0,
    int adsWatched = 0,
  }) {
    final safeReferrals =
        activeReferrals < 0 ? 0 : activeReferrals;

    final safeAds = adsWatched.clamp(
      0,
      AppConfig.maxAdsPerSession,
    );

    final referralBoost =
        safeReferrals * AppConfig.referralMiningBoost;

    final adBoost =
        calculateMaximumAdBoost(safeAds);

    return AppConfig.baseMiningRate +
        referralBoost +
        adBoost;
  }
}
