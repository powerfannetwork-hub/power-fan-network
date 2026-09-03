import 'dart:async';

import 'package:applovin_max/applovin_max.dart';

import '../globals/app_constants.dart';
import 'mining_service.dart';

class BoostAdsService {
  BoostAdsService({
    MiningService? miningService,
  }) : _miningService =
            miningService ?? MiningService.instance;

  static final BoostAdsService instance =
      BoostAdsService();

  final MiningService _miningService;

  bool _initialized = false;
  bool _initializing = false;

  Completer<bool>? _rewardCompleter;

  bool _rewardReceived = false;

  int _adsWatched = 0;

  // ============================================================
  // CONFIGURATION
  // ============================================================

  String get sdkKey =>
      AppConfig.appLovinSdkKey.trim();

  String get rewardedAdUnitId =>
      AppConfig.appLovinRewardedAdUnitId.trim();

  bool get isConfigured =>
      sdkKey.isNotEmpty &&
      rewardedAdUnitId.isNotEmpty;

  bool get isInitialized => _initialized;

  // ============================================================
  // SESSION STATE
  // ============================================================

  int get adsWatched => _adsWatched;

  int get remainingAds {
    final remaining =
        AppConfig.maxAdsPerSession -
        _adsWatched;

    return remaining < 0
        ? 0
        : remaining;
  }

  double get currentAdBoost {
    return calculateBoost(_adsWatched);
  }

  // ============================================================
  // BOOST CALCULATION
  // ============================================================

  double calculateBoost(int ads) {
    final safeAds = ads.clamp(
      0,
      AppConfig.maxAdsPerSession,
    );

    final boost =
        safeAds *
        AppConfig.adBoostPerAd;

    if (boost > AppConfig.maxAdBoost) {
      return AppConfig.maxAdBoost;
    }

    return boost.toDouble();
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

    if (adsWatched >=
        AppConfig.maxAdsPerSession) {
      return false;
    }

    if (!isConfigured) {
      return false;
    }

    return true;
  }

  // ============================================================
  // INITIALIZE APPLOVIN MAX
  // ============================================================

  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    if (_initializing) {
      return false;
    }

    if (!isConfigured) {
      return false;
    }

    _initializing = true;

    try {
      AppLovinMAX.setRewardedAdListener(
        RewardedAdListener(
          onAdLoadedCallback: (ad) {
            // Rewarded ad is ready.
          },

          onAdLoadFailedCallback: (
            adUnitId,
            error,
          ) {
            _completeReward(false);
          },

          onAdDisplayedCallback: (ad) {
            // Ad displayed.
          },

          onAdDisplayFailedCallback: (
            ad,
            error,
          ) {
            _completeReward(false);
          },

          onAdClickedCallback: (ad) {
            // Clicking does not grant FAN.
          },

          onAdHiddenCallback: (ad) {
            /*
             * IMPORTANT:
             *
             * Hiding the ad does NOT automatically
             * mean that the reward was earned.
             *
             * If the reward callback already arrived,
             * keep the successful result.
             *
             * Otherwise complete as false.
             */
            if (!_rewardReceived) {
              _completeReward(false);
            }

            _loadRewardedAd();
          },

          onAdReceivedRewardCallback: (
            ad,
            reward,
          ) {
            /*
             * AppLovin confirmed that the rewarded
             * event was received.
             */
            _rewardReceived = true;

            _completeReward(true);
          },

          onAdRevenuePaidCallback: (ad) {
            // Revenue information only.
          },
        ),
      );

      final configuration =
          await AppLovinMAX.initialize(
        sdkKey,
      );

      if (configuration == null) {
        _initialized = false;
        return false;
      }

      _initialized = true;

      await _loadRewardedAd();

      return true;
    } catch (_) {
      _initialized = false;
      return false;
    } finally {
      _initializing = false;
    }
  }

  // ============================================================
  // LOAD REWARDED AD
  // ============================================================

  Future<void> _loadRewardedAd() async {
    if (!_initialized ||
        rewardedAdUnitId.isEmpty) {
      return;
    }

    try {
      AppLovinMAX.loadRewardedAd(
        rewardedAdUnitId,
      );
    } catch (_) {
      // Ignore load errors.
      // A later request can try again.
    }
  }

  // ============================================================
  // CHECK REWARDED AD READY
  // ============================================================

  Future<bool> isRewardedAdReady() async {
    if (!_initialized ||
        rewardedAdUnitId.isEmpty) {
      return false;
    }

    try {
      final ready =
          await AppLovinMAX.isRewardedAdReady(
        rewardedAdUnitId,
      );

      return ready == true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // LOAD SESSION AD COUNT
  // ============================================================

  Future<int> getAdsWatchedForSession({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    try {
      final count =
          await _miningService
              .getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      _adsWatched = _clampAds(count);

      return _adsWatched;
    } catch (_) {
      return _adsWatched;
    }
  }

  // ============================================================
  // WATCH + RECORD
  // ============================================================

  Future<Map<String, dynamic>>
      watchAdAndRecord({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    /*
     * Always refresh the server-side session count
     * before attempting another rewarded ad.
     *
     * This prevents stale local state from allowing
     * an extra ad.
     */
    try {
      await getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );
    } catch (_) {
      // Local count remains available.
    }

    if (_adsWatched >=
        AppConfig.maxAdsPerSession) {
      return _failure(
        'You have reached the maximum of '
        '${AppConfig.maxAdsPerSession} ads '
        'for this mining session.',
      );
    }

    if (!isConfigured) {
      return _failure(
        'Rewarded ads are not configured yet.',
      );
    }

    final initialized =
        await initialize();

    if (!initialized) {
      return _failure(
        'Rewarded ads are temporarily unavailable.',
      );
    }

    final ready =
        await isRewardedAdReady();

    if (!ready) {
      await _loadRewardedAd();

      return _failure(
        'Rewarded ad is not ready. Please try again.',
      );
    }

    /*
     * Show the ad and wait for the actual
     * AppLovin reward callback.
     */
    final rewarded =
        await _showRewardedAd();

    if (!rewarded) {
      await _loadRewardedAd();

      return _failure(
        'The ad was not completed, so no FAN '
        'mining boost was added.',
      );
    }

    // ========================================================
    // SERVER RECORDING
    // ========================================================

    try {
      final result =
          await _miningService
              .recordRewardedAd();

      final success =
          result['success'] == true ||
          result['recorded'] == true ||
          result['ok'] == true;

      if (!success) {
        await _loadRewardedAd();

        return <String, dynamic>{
          'success': false,
          'message':
              result['message']?.toString() ??
                  'The rewarded ad could not be recorded.',
          'ads_watched': _adsWatched,
          'remaining_ads': remainingAds,
          'ad_boost': currentAdBoost,
        };
      }

      final serverCount =
          result['ads_watched'];

      if (serverCount is num) {
        _adsWatched =
            _clampAds(serverCount.toInt());
      } else {
        _adsWatched =
            _clampAds(_adsWatched + 1);
      }

      await _loadRewardedAd();

      return <String, dynamic>{
        'success': true,
        'message':
            '+${AppConfig.adBoostPerAd.toStringAsFixed(2)} '
            'FAN/H mining boost added.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
        'reward_rate':
            AppConfig.adBoostPerAd,
      };
    } catch (error) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'The ad was completed, but the server '
            'could not record the reward.',
        'error': error.toString(),
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }
  }

  // ============================================================
  // SHOW REWARDED AD
  // ============================================================

  Future<bool> _showRewardedAd() async {
    /*
     * Prevent two rewarded ads from being shown
     * at the same time.
     */
    if (_rewardCompleter != null) {
      return false;
    }

    final completer =
        Completer<bool>();

    _rewardCompleter = completer;
    _rewardReceived = false;

    try {
      AppLovinMAX.showRewardedAd(
        rewardedAdUnitId,
      );

      final result =
          await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          _completeReward(false);
          return false;
        },
      );

      return result;
    } catch (_) {
      _completeReward(false);
      return false;
    } finally {
      _rewardCompleter = null;
      _rewardReceived = false;
    }
  }

  // ============================================================
  // COMPLETE REWARD
  // ============================================================

  void _completeReward(
    bool rewarded,
  ) {
    final completer =
        _rewardCompleter;

    if (completer == null ||
        completer.isCompleted) {
      return;
    }

    completer.complete(rewarded);
  }

  // ============================================================
  // FAILURE RESULT
  // ============================================================

  Map<String, dynamic> _failure(
    String message,
  ) {
    return <String, dynamic>{
      'success': false,
      'message': message,
      'ads_watched': _adsWatched,
      'remaining_ads': remainingAds,
      'ad_boost': currentAdBoost,
    };
  }

  // ============================================================
  // CLAMP ADS
  // ============================================================

  int _clampAds(
    dynamic value,
  ) {
    int count;

    if (value is int) {
      count = value;
    } else if (value is num) {
      count = value.toInt();
    } else {
      count =
          int.tryParse(
            value?.toString() ?? '',
          ) ??
          0;
    }

    if (count < 0) {
      return 0;
    }

    if (count >
        AppConfig.maxAdsPerSession) {
      return AppConfig.maxAdsPerSession;
    }

    return count;
  }

  // ============================================================
  // REFRESH SESSION COUNT
  // ============================================================

  Future<void> refreshSessionCount({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    await getAdsWatchedForSession(
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  // ============================================================
  // RESET LOCAL STATE
  // ============================================================

  void resetLocalState() {
    _adsWatched = 0;
    _rewardReceived = false;
  }
}
