import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

class MiningService {
  MiningService._internal();

  static final MiningService instance = MiningService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  User _requireAuthenticated() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not authenticated.');
    }

    return user;
  }

  // ---------------------------------------------------------------------------
  // RESPONSE HELPERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List && data.isNotEmpty) {
      final first = data.first;

      if (first is Map<String, dynamic>) {
        return first;
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
        .where((item) => item is Map)
        .map((item) => Map<String, dynamic>.from(item as Map))
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

  double _asDouble(dynamic value, {double fallback = 0.0}) {
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

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = value?.toString().toLowerCase();

    if (text == 'true' || text == 't' || text == '1') {
      return true;
    }

    if (text == 'false' || text == 'f' || text == '0') {
      return false;
    }

    return fallback;
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getProfile() async {
    final user = _requireAuthenticated();

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(data);
  }

  // ---------------------------------------------------------------------------
  // MINING RATE
  // ---------------------------------------------------------------------------

  Future<double> getUserMiningRate() async {
    final user = _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcGetUserMiningRate,
      params: <String, dynamic>{
        'p_user_id': user.id,
      },
    );

    if (data is num) {
      return data.toDouble();
    }

    final map = _asMap(data);

    return _asDouble(
      map['mining_rate'] ??
          map['rate'] ??
          map['current_rate'] ??
          map['result'],
      fallback: AppConfig.baseMiningRate,
    );
  }

  // ---------------------------------------------------------------------------
  // START MINING
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> startMining() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcStartMining,
    );

    return _asMap(data);
  }

  // ---------------------------------------------------------------------------
  // ACTIVE MINING
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // CLAIM MINING
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> claimMining() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcClaimMining,
    );

    return _asMap(data);
  }

  // ---------------------------------------------------------------------------
  // REWARDED AD
  // ---------------------------------------------------------------------------

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
      throw ArgumentError.value(
        adId,
        'adId',
        'Ad ID cannot be empty.',
      );
    }

    final data = await _client.rpc(
      AppConfig.rpcVerifyRewardedAd,
      params: <String, dynamic>{
        'p_ad_id': adId.trim(),
      },
    );

    return _asMap(data);
  }

  // ---------------------------------------------------------------------------
  // ADS WATCHED FOR CURRENT SESSION
  // ---------------------------------------------------------------------------

  Future<int> getAdsWatchedForSession({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    final user = _requireAuthenticated();

    var query = _client
        .from('ad_rewards')
        .select('id')
        .eq('user_id', user.id)
        .gte(
          'watched_at',
          startedAt.toUtc().toIso8601String(),
        );

    if (endsAt != null) {
      query = query.lte(
        'watched_at',
        endsAt.toUtc().toIso8601String(),
      );
    }

    final data = await query;

    return data.length;
  }

  Future<int> getSessionAdCount({
    required DateTime startedAt,
    DateTime? endsAt,
  }) {
    return getAdsWatchedForSession(
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY CHECK-IN
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> dailyCheckin() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcDailyCheckin,
    );

    return _asMap(data);
  }

  // ---------------------------------------------------------------------------
  // DAILY SOCIAL TASK
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> completeDailySocialTask(
    String taskId,
  ) async {
    _requireAuthenticated();

    if (taskId.trim().isEmpty) {
      throw ArgumentError.value(
        taskId,
        'taskId',
        'Task ID cannot be empty.',
      );
    }

    /*
     * The current social-task backend uses:
     *
     *   claim_daily_social_reward
     *
     * The previous MiningService referenced a constant that did not exist
     * in AppConfig. We keep this legacy method working without requiring
     * another AppConfig constant.
     */
    final data = await _client.rpc(
      'claim_daily_social_reward',
      params: <String, dynamic>{
        'p_task_id': taskId.trim(),
      },
    );

    return _asMap(data);
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getDashboard() async {
    _requireAuthenticated();

    final data = await _client.rpc(
      AppConfig.rpcGetDashboard,
    );

    return _asMap(data);
  }

  // ---------------------------------------------------------------------------
  // MINING STATUS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getMiningStatus() async {
    final profile = await getProfile();
    final activeMining = await getActiveMining();

    final miningActive = _asBool(
      activeMining?['active'] ??
          activeMining?['mining_active'] ??
          profile['mining_active'],
      fallback: false,
    );

    final startedAt = _asDateTime(
      activeMining?['started_at'] ??
          activeMining?['mining_started_at'] ??
          profile['mining_started_at'],
    );

    final endsAt = _asDateTime(
      activeMining?['ends_at'] ??
          activeMining?['mining_ends_at'] ??
          profile['mining_ends_at'],
    );

    final rate = _asDouble(
      activeMining?['mining_rate'] ??
          activeMining?['rate'] ??
          profile['mining_rate'],
      fallback: AppConfig.baseMiningRate,
    );

    return <String, dynamic>{
      'mining_active': miningActive,
      'started_at': startedAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'mining_rate': rate,
      'fan_balance': _asDouble(profile['fan_balance']),
      'afam_balance': _asDouble(profile['afam_balance']),
    };
  }

  // ---------------------------------------------------------------------------
  // ACTIVE REFERRALS
  // ---------------------------------------------------------------------------

  Future<int> getActiveReferralCount() async {
    final user = _requireAuthenticated();

    final data = await _client.rpc(
      'calculate_active_referrals',
      params: <String, dynamic>{
        'p_user_id': user.id,
      },
    );

    if (data is num) {
      return data.toInt();
    }

    final map = _asMap(data);

    return _asInt(
      map['active_referrals'] ??
          map['count'] ??
          map['result'],
    );
  }

  // ---------------------------------------------------------------------------
  // SESSION HELPERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMiningSessions({
    int limit = 20,
  }) async {
    final user = _requireAuthenticated();

    final safeLimit = limit.clamp(1, 100);

    final data = await _client
        .from('mining_sessions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(safeLimit);

    return _asMapList(data);
  }

  Future<Map<String, dynamic>?> getLatestMiningSession() async {
    final user = _requireAuthenticated();

    final data = await _client
        .from('mining_sessions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> getSessionById(
    String sessionId,
  ) async {
    final user = _requireAuthenticated();

    if (sessionId.trim().isEmpty) {
      return null;
    }

    final data = await _client
        .from('mining_sessions')
        .select()
        .eq('id', sessionId.trim())
        .eq('user_id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  // ---------------------------------------------------------------------------
  // CALCULATIONS
  // ---------------------------------------------------------------------------

  double calculateMiningReward({
    required double miningRate,
    required Duration duration,
  }) {
    final hours = duration.inSeconds / 3600.0;

    if (hours <= 0 || miningRate <= 0) {
      return 0.0;
    }

    return miningRate * hours;
  }

  double calculateMaximumAdBoost(int adsWatched) {
    final safeAds = adsWatched.clamp(0, AppConfig.maxAdsPerSession);

    final boost = safeAds * AppConfig.adBoostPerAd;

    return boost.clamp(
      0.0,
      AppConfig.maxAdBoost,
    );
  }

  double calculateReferralMiningBonus(int activeReferrals) {
    if (activeReferrals <= 0) {
      return 0.0;
    }

    return activeReferrals * AppConfig.referralMiningBoost;
  }

  double calculateExpectedMiningRate({
    required int activeReferrals,
    required int adsWatched,
  }) {
    final referralBonus =
        calculateReferralMiningBonus(activeReferrals);

    final adBoost =
        calculateMaximumAdBoost(adsWatched);

    return AppConfig.baseMiningRate +
        referralBonus +
        adBoost;
  }

  // ---------------------------------------------------------------------------
  // CONVENIENCE METHODS
  // ---------------------------------------------------------------------------

  Future<int> getCurrentSessionAds() async {
    final activeMining = await getActiveMining();

    if (activeMining == null) {
      return 0;
    }

    final startedAt = _asDateTime(
      activeMining['started_at'] ??
          activeMining['mining_started_at'],
    );

    if (startedAt == null) {
      return 0;
    }

    final endsAt = _asDateTime(
      activeMining['ends_at'] ??
          activeMining['mining_ends_at'],
    );

    return getAdsWatchedForSession(
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  Future<bool> isMiningActive() async {
    final activeMining = await getActiveMining();

    if (activeMining == null || activeMining.isEmpty) {
      return false;
    }

    return _asBool(
      activeMining['active'] ??
          activeMining['mining_active'],
      fallback: false,
    );
  }

  Future<bool> canStartMining() async {
    return !(await isMiningActive());
  }

  Future<bool> canClaimMining() async {
    final activeMining = await getActiveMining();

    if (activeMining == null || activeMining.isEmpty) {
      return false;
    }

    final endsAt = _asDateTime(
      activeMining['ends_at'] ??
          activeMining['mining_ends_at'],
    );

    if (endsAt == null) {
      return false;
    }

    return !DateTime.now().toUtc().isBefore(
          endsAt.toUtc(),
        );
  }

  // ---------------------------------------------------------------------------
  // RAW RPC HELPERS
  // ---------------------------------------------------------------------------

  Future<dynamic> callRpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    _requireAuthenticated();

    if (functionName.trim().isEmpty) {
      throw ArgumentError.value(
        functionName,
        'functionName',
        'Function name cannot be empty.',
      );
    }

    return _client.rpc(
      functionName.trim(),
      params: params,
    );
  }
}
