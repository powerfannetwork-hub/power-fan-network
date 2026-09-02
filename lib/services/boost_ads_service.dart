import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mining_service.dart';

class BoostAdsService {
  BoostAdsService._();

  static final BoostAdsService instance =
      BoostAdsService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  final MiningService _miningService =
      MiningService.instance;

  /*
   * AppLovin MAX configuration.
   *
   * Leave these empty until the real values are available.
   * DO NOT use fake values.
   */
  static const String appLovinSdkKey = '';

  static const String rewardedAdUnitId = '';

  static const int maxAdsPerSession = 7;

  static const double boostPerAd = 0.1;

  static const double maximumBoost = 0.7;

  bool _initialized = false;

  bool _loading = false;

  Completer<bool>? _rewardCompleter;

  bool get isInitialized => _initialized;

  bool get isConfigured =>
      appLovinSdkKey.trim().isNotEmpty &&
      rewardedAdUnitId.trim().isNotEmpty;

  bool get isLoading => _loading;

  Future<void> _requireUser() async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    if (session == null || user == null) {
      throw const AuthException(
        'Your session has expired. Please log in again.',
      );
    }
  }

  Exception _formatError(
    Object error, {
    required String action,
  }) {
    if (error is PostgrestException) {
      final message = error.message.trim();
      final details =
          error.details?.toString().trim() ?? '';
      final hint = error.hint?.trim() ?? '';
      final code = error.code?.trim() ?? '';

      final parts = <String>[
        if (message.isNotEmpty) message,
        if (code.isNotEmpty) 'Code: $code',
        if (details.isNotEmpty &&
            details != 'Bad Request')
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

  /*
   * Initialize AppLovin MAX.
   *
   * Nothing is initialized when the real SDK key
   * and rewarded ad unit ID are still empty.
   */
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

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
            adUnitId,
            error,
          ) {
            _loading = false;

            _completeReward(false);
          },
          onAdDisplayedCallback: (ad) {},
          onAdDisplayFailedCallback: (
            ad,
            error,
          ) {
            _loading = false;

            _completeReward(false);

            loadRewardedAd();
          },
          onAdClickedCallback: (ad) {},
          onAdReceivedRewardCallback: (
            ad,
            reward,
          ) {
            /*
             * AppLovin confirms that the user
             * successfully completed the rewarded ad.
             *
             * The FAN reward is NOT added here.
             *
             * The database operation happens only
             * after this Future returns true.
             */
            _completeReward(true);
          },
          onAdHiddenCallback: (ad) {
            /*
             * If no reward callback was received,
             * the ad was not successfully completed.
             */
            _completeReward(false);

            loadRewardedAd();
          },
          onAdRevenuePaidCallback: (ad) {},
        ),
      );

      final configuration =
          await AppLovinMAX.initialize(
        appLovinSdkKey,
      );

      if (configuration == null) {
        return;
      }

      _initialized = true;

      final user =
          _supabase.auth.currentUser;

      if (user != null) {
        AppLovinMAX.setUserId(user.id);
      }

      await loadRewardedAd();
    } catch (error) {
      _initialized = false;
      _loading = false;
    }
  }

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
      final ready =
          await AppLovinMAX.isRewardedAdReady(
        rewardedAdUnitId,
      );

      if (ready == true) {
        return;
      }

      _loading = true;

      AppLovinMAX.loadRewardedAd(
        rewardedAdUnitId,
      );
    } catch (error) {
      _loading = false;
    }
  }

  Future<bool> showRewardedAd() async {
    if (!_initialized || !isConfigured) {
      return false;
    }

    try {
      final ready =
          await AppLovinMAX.isRewardedAdReady(
        rewardedAdUnitId,
      );

      if (ready != true) {
        await loadRewardedAd();
        return false;
      }

      if (_rewardCompleter != null &&
          !_rewardCompleter!.isCompleted) {
        return false;
      }

      final completer =
          Completer<bool>();

      _rewardCompleter = completer;

      AppLovinMAX.showRewardedAd(
        rewardedAdUnitId,
      );

      final rewarded =
          await completer.future;

      if (identical(
        _rewardCompleter,
        completer,
      )) {
        _rewardCompleter = null;
      }

      return rewarded;
    } catch (error) {
      _completeReward(false);

      _rewardCompleter = null;

      await loadRewardedAd();

      return false;
    }
  }

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

  /*
   * Gets the number of rewarded ads watched
   * INSIDE THE CURRENT MINING SESSION.
   *
   * This is intentionally NOT based on the calendar day.
   *
   * Example:
   *
   * Session:
   * 10:00 Monday
   * ->
   * 10:00 Tuesday
   *
   * Ads from Sunday are not counted.
   * Ads from another session are not counted.
   */
  Future<int> getAdsWatchedForSession({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    try {
      await _requireUser();

      final user =
          _supabase.auth.currentUser!;

      final startUtc =
          startedAt.toUtc();

      final query =
          _supabase
              .from('ad_boosts')
              .select('id')
              .eq('user_id', user.id)
              .gte(
                'created_at',
                startUtc.toIso8601String(),
              );

      final rows = endsAt == null
          ? await query
          : await query.lt(
              'created_at',
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
        action:
            'load this mining session\'s ad count',
      );
    }
  }

  /*
   * Records the rewarded ad only AFTER
   * AppLovin confirms that the user completed it.
   */
  Future<Map<String, dynamic>>
      recordCompletedRewardedAd() async {
    try {
      await _requireUser();

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

  /*
   * Complete the entire Boost Ad flow:
   *
   * 1. Check current session.
   * 2. Check 7-ad session limit.
   * 3. Show rewarded ad.
   * 4. Wait for AppLovin reward callback.
   * 5. Record the completed ad.
   *
   * No FAN/H boost is added before AppLovin
   * confirms completion.
   */
  Future<Map<String, dynamic>>
      watchAdAndRecord({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    try {
      await _requireUser();

      final now = DateTime.now();

      if (now.isBefore(startedAt)) {
        return <String, dynamic>{
          'success': false,
          'reason': 'session_not_started',
          'message':
              'The mining session has not started yet.',
        };
      }

      if (endsAt != null &&
          !now.isBefore(endsAt)) {
        return <String, dynamic>{
          'success': false,
          'reason': 'session_finished',
          'message':
              'Mining session is complete. Claim your reward and start a new session before watching more ads.',
        };
      }

      final currentCount =
          await getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      if (currentCount >=
          maxAdsPerSession) {
        return <String, dynamic>{
          'success': false,
          'reason': 'limit_reached',
          'ads_watched': maxAdsPerSession,
          'message':
              'You have reached the 7 ads limit for this mining session.',
        };
      }

      final rewarded =
          await showRewardedAd();

      if (!rewarded) {
        return <String, dynamic>{
          'success': false,
          'reason': 'ad_not_completed',
          'ads_watched': currentCount,
          'message':
              'The rewarded ad was not completed. No mining boost was added.',
        };
      }

      /*
       * Re-check the session limit after the ad.
       *
       * This protects against two operations reaching
       * this point unexpectedly at the same time.
       */
      final latestCount =
          await getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      if (latestCount >=
          maxAdsPerSession) {
        return <String, dynamic>{
          'success': false,
          'reason': 'limit_reached',
          'ads_watched': maxAdsPerSession,
          'message':
              'You have reached the 7 ads limit for this mining session.',
        };
      }

      final result =
          await recordCompletedRewardedAd();

      if (result['success'] == false) {
        return <String, dynamic>{
          ...result,
          'success': false,
        };
      }

      final newCount =
          latestCount + 1;

      final boost =
          (newCount * boostPerAd)
              .clamp(
                0.0,
                maximumBoost,
              );

      return <String, dynamic>{
        ...result,
        'success': true,
        'ads_watched': newCount,
        'boost': boost,
        'boost_per_ad': boostPerAd,
        'max_ads': maxAdsPerSession,
      };
    } catch (error) {
      throw _formatError(
        error,
        action: 'complete rewarded ad',
      );
    }
  }

  /*
   * Calculates the boost based ONLY on ads.
   *
   * Referral bonuses are deliberately not included here.
   */
  double calculateBoost(int adsWatched) {
    final safeCount =
        adsWatched.clamp(
      0,
      maxAdsPerSession,
    );

    return (safeCount * boostPerAd)
        .clamp(
      0.0,
      maximumBoost,
    );
  }

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
}
