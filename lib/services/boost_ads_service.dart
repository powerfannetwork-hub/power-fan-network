import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';
import 'mining_service.dart';

class BoostAdsService {
  BoostAdsService._();

  static final BoostAdsService instance = BoostAdsService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final MiningService _miningService = MiningService.instance;

  // ============================================================
  // APPLOVIN MAX
  // ============================================================

  static const String appLovinSdkKey = AppConfig.appLovinSdkKey;

  static const String rewardedAdUnitId =
      AppConfig.appLovinRewardedAdUnitId;

  // ============================================================
  // AD RULES
  // ============================================================

  static const int maxAdsPerSession = AppConfig.maxAdsPerSession;

  static const double boostPerAd = AppConfig.adBoostPerAd;

  static const double maximumBoost = AppConfig.maxAdBoost;

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  bool _initialized = false;
  bool _loading = false;

  Completer<bool>? _rewardCompleter;

  bool get isInitialized => _initialized;

  bool get isConfigured =>
      appLovinSdkKey.trim().isNotEmpty &&
      rewardedAdUnitId.trim().isNotEmpty;

  bool get isLoading => _loading;

  // ============================================================
  // AUTH CHECK
  // ============================================================

  void _requireUser() {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    if (session == null || user == null) {
      throw const AuthException(
        'Your session has expired. Please log in again.',
      );
    }
  }

  // ============================================================
  // ERROR FORMAT
  // ============================================================

  Exception _formatError(
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

  // ============================================================
  // INITIALIZE APPLOVIN
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // Do not initialize with fake/empty values.
    if (!isConfigured) {
      return;
    }

    try {
      AppLovinMAX.setRewardedAdListener(
        RewardedAdListener(
          onAdLoadedCallback: (ad) {
            _loading = false;
          },
          onAdLoadFailedCallback: (
            String adUnitId,
            MAError error,
          ) {
            _loading = false;
            _completeReward(false);
          },
          onAdDisplayedCallback: (ad) {},
          onAdDisplayFailedCallback: (
            ad,
            MAError error,
          ) {
            _loading = false;

            _completeReward(false);

            unawaited(loadRewardedAd());
          },
          onAdClickedCallback: (ad) {},
          onAdReceivedRewardCallback: (
            ad,
            MAReward reward,
          ) {
            // AppLovin confirms the reward.
            // FAN is NOT added here.
            //
            // The database reward is recorded only
            // after this callback succeeds.
            _completeReward(true);
          },
          onAdHiddenCallback: (ad) {
            // If reward callback did not happen,
            // the ad is treated as incomplete.
            _completeReward(false);

            unawaited(loadRewardedAd());
          },
          onAdRevenuePaidCallback: (ad) {},
        ),
      );

      final configuration = await AppLovinMAX.initialize(
        appLovinSdkKey,
      );

      if (configuration == null) {
        return;
      }

      _initialized = true;

      final user = _supabase.auth.currentUser;

      if (user != null) {
        AppLovinMAX.setUserId(user.id);
      }

      await loadRewardedAd();
    } catch (_) {
      _initialized = false;
      _loading = false;
    }
  }

  // ============================================================
  // LOAD REWARDED AD
  // ============================================================

  Future<void> loadRewardedAd() async {
    if (!_initialized) {
      return;
    }

    if (!isConfigured) {
      return;
    }

    if (_loading) {
      return;
    }

    try {
      final ready = await AppLovinMAX.isRewardedAdReady(
        rewardedAdUnitId,
      );

      if (ready == true) {
        return;
      }

      _loading = true;

      AppLovinMAX.loadRewardedAd(
        rewardedAdUnitId,
      );
    } catch (_) {
      _loading = false;
    }
  }

  // ============================================================
  // SHOW REWARDED AD
  // ============================================================

  Future<bool> showRewardedAd() async {
    if (!_initialized || !isConfigured) {
      return false;
    }

    if (_rewardCompleter != null &&
        !_rewardCompleter!.isCompleted) {
      return false;
    }

    try {
      final ready = await AppLovinMAX.isRewardedAdReady(
        rewardedAdUnitId,
      );

      if (ready != true) {
        await loadRewardedAd();
        return false;
      }

      final completer = Completer<bool>();

      _rewardCompleter = completer;

      AppLovinMAX.showRewardedAd(
        rewardedAdUnitId,
      );

      final rewarded = await completer.future;

      if (identical(_rewardCompleter, completer)) {
        _rewardCompleter = null;
      }

      return rewarded;
    } catch (_) {
      _completeReward(false);

      _rewardCompleter = null;

      unawaited(loadRewardedAd());

      return false;
    }
  }

  // ============================================================
  // COMPLETE APPLOVIN REWARD
  // ============================================================

  void _completeReward(bool rewarded) {
    final completer = _rewardCompleter;

    if (completer == null) {
      return;
    }

    if (completer.isCompleted) {
      return;
    }

    completer.complete(rewarded);
  }

  // ============================================================
  // GET ADS WATCHED IN CURRENT 24-HOUR SESSION
  // ============================================================

  Future<int> getAdsWatchedForSession({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    try {
      _requireUser();

      final user = _supabase.auth.currentUser!;

      final startUtc = startedAt.toUtc();

      final query = _supabase
          .from('ad_boosts')
          .select('id')
          .eq('user_id', user.id)
          // IMPORTANT:
          // The database column is watched_at.
          .gte(
            'watched_at',
            startUtc.toIso8601String(),
          );

      final rows = endsAt == null
          ? await query
          : await query.lt(
              'watched_at',
              endsAt.toUtc().toIso8601String(),
            );

      if (rows is! List) {
        return 0;
      }

      if (rows.length >= maxAdsPerSession) {
        return maxAdsPerSession;
      }

      return rows.length;
    } catch (error) {
      throw _formatError(
        error,
        action: 'load this mining session\'s ad count',
      );
    }
  }

  // ============================================================
  // RECORD COMPLETED REWARDED AD
  // ============================================================

  Future<Map<String, dynamic>>
      recordCompletedRewardedAd() async {
    try {
      _requireUser();

      final reference =
          'mobile_${DateTime.now().millisecondsSinceEpoch}';

      final result =
          await _miningService.recordRewardedAd(
        adRef: reference,
      );

      return result;
    } catch (error) {
      throw _formatError(
        error,
        action: 'record rewarded ad',
      );
    }
  }

  // ============================================================
  // COMPLETE FULL AD FLOW
  // ============================================================

  Future<Map<String, dynamic>>
      watchAdAndRecord({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    try {
      _requireUser();

      final now = DateTime.now();

      // ----------------------------------------------------------
      // SESSION NOT STARTED
      // ----------------------------------------------------------

      if (now.isBefore(startedAt)) {
        return <String, dynamic>{
          'success': false,
          'reason': 'session_not_started',
          'ads_watched': 0,
          'max_ads': maxAdsPerSession,
          'message':
              'The mining session has not started yet.',
        };
      }

      // ----------------------------------------------------------
      // SESSION FINISHED
      // ----------------------------------------------------------

      if (endsAt != null && !now.isBefore(endsAt)) {
        return <String, dynamic>{
          'success': false,
          'reason': 'session_finished',
          'message':
              'Mining session is complete. Claim your reward and start a new session before watching more ads.',
        };
      }

      // ----------------------------------------------------------
      // CHECK CURRENT SESSION COUNT
      // ----------------------------------------------------------

      final currentCount =
          await getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      if (currentCount >= maxAdsPerSession) {
        return <String, dynamic>{
          'success': false,
          'reason': 'limit_reached',
          'ads_watched': maxAdsPerSession,
          'max_ads': maxAdsPerSession,
          'message':
              'You have reached the 7 ads limit for this mining session.',
        };
      }

      // ----------------------------------------------------------
      // SHOW AD
      // ----------------------------------------------------------

      final rewarded = await showRewardedAd();

      if (!rewarded) {
        return <String, dynamic>{
          'success': false,
          'reason': 'ad_not_completed',
          'ads_watched': currentCount,
          'max_ads': maxAdsPerSession,
          'message':
              'The rewarded ad was not completed. No mining boost was added.',
        };
      }

      // ----------------------------------------------------------
      // CHECK SESSION AGAIN AFTER AD
      // ----------------------------------------------------------

      final latestCount =
          await getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      if (latestCount >= maxAdsPerSession) {
        return <String, dynamic>{
          'success': false,
          'reason': 'limit_reached',
          'ads_watched': maxAdsPerSession,
          'max_ads': maxAdsPerSession,
          'message':
              'You have reached the 7 ads limit for this mining session.',
        };
      }

      // ----------------------------------------------------------
      // RECORD ONLY AFTER APPLOVIN REWARD CALLBACK
      // ----------------------------------------------------------

      final result =
          await recordCompletedRewardedAd();

      if (result['success'] == false) {
        return <String, dynamic>{
          ...result,
          'success': false,
        };
      }

      final newCount = latestCount + 1;

      final boost = calculateBoost(newCount);

      return <String, dynamic>{
        ...result,
        'success': true,
        'ads_watched': newCount,
        'max_ads': maxAdsPerSession,
        'boost': boost,
        'boost_per_ad': boostPerAd,
        'maximum_boost': maximumBoost,
      };
    } catch (error) {
      throw _formatError(
        error,
        action: 'complete rewarded ad',
      );
    }
  }

  // ============================================================
  // CALCULATE AD BOOST
  // ============================================================

  double calculateBoost(int adsWatched) {
    final safeCount = adsWatched.clamp(
      0,
      maxAdsPerSession,
    );

    final boost = safeCount * boostPerAd;

    return boost.clamp(
      0.0,
      maximumBoost,
    );
  }

  // ============================================================
  // CAN WATCH AD
  // ============================================================

  bool canWatchAd({
    required int adsWatched,
    required bool isMining,
    required bool sessionFinished,
  }) {
    if (!isMining) {
      return false;
    }

    if (sessionFinished) {
      return false;
    }

    if (adsWatched >= maxAdsPerSession) {
      return false;
    }

    return true;
  }

  // ============================================================
  // REMAINING ADS
  // ============================================================

  int remainingAds(int adsWatched) {
    final safeCount = adsWatched.clamp(
      0,
      maxAdsPerSession,
    );

    return maxAdsPerSession - safeCount;
  }

  // ============================================================
  // SESSION AD STATUS
  // ============================================================

  Map<String, dynamic> getSessionAdStatus(
    int adsWatched,
  ) {
    final safeCount = adsWatched.clamp(
      0,
      maxAdsPerSession,
    );

    return <String, dynamic>{
      'ads_watched': safeCount,
      'max_ads': maxAdsPerSession,
      'remaining_ads':
          maxAdsPerSession - safeCount,
      'boost': calculateBoost(safeCount),
      'boost_per_ad': boostPerAd,
      'maximum_boost': maximumBoost,
      'limit_reached':
          safeCount >= maxAdsPerSession,
    };
  }
}
