import 'dart:async';

import 'package:applovin_max/applovin_max.dart';

import '../globals/app_constants.dart';
import 'mining_service.dart';

class BoostAdsService {
  BoostAdsService({
    MiningService? miningService,
  }) : _miningService = miningService ?? MiningService.instance;

  static final BoostAdsService instance = BoostAdsService();

  final MiningService _miningService;

  bool _initialized = false;
  bool _initializing = false;

  Completer<bool>? _rewardCompleter;

  int _adsWatched = 0;

  // ============================================================
  // CONFIGURATION
  // ============================================================

  String get sdkKey => AppConfig.appLovinSdkKey.trim();

  String get rewardedAdUnitId =>
      AppConfig.appLovinRewardedAdUnitId.trim();

  bool get isConfigured =>
      sdkKey.isNotEmpty && rewardedAdUnitId.isNotEmpty;

  bool get isInitialized => _initialized;

  // ============================================================
  // SESSION STATE
  // ============================================================

  int get adsWatched => _adsWatched;

  int get remainingAds {
    final remaining =
        AppConfig.maxAdsPerSession - _adsWatched;

    return remaining < 0 ? 0 : remaining;
  }

  double get currentAdBoost {
    return _miningService.calculateMaximumAdBoost(
      _adsWatched,
    );
  }

  // ============================================================
  // INITIALIZE APPLOVIN
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
            // Clicking does NOT grant FAN.
          },
          onAdHiddenCallback: (ad) {
            /*
             * Do not grant anything here.
             *
             * The reward is granted only when
             * onAdReceivedRewardCallback fires.
             */
            _completeReward(false);

            _loadRewardedAd();
          },
          onAdReceivedRewardCallback: (
            ad,
            reward,
          ) {
            /*
             * AppLovin has confirmed that the user
             * earned the rewarded-ad reward.
             */
            _completeReward(true);
          },
          onAdRevenuePaidCallback: (ad) {
            // Revenue information only.
          },
        ),
      );

      final configuration =
          await AppLovinMAX.initialize(sdkKey);

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
    if (!_initialized || rewardedAdUnitId.isEmpty) {
      return;
    }

    try {
      AppLovinMAX.loadRewardedAd(
        rewardedAdUnitId,
      );
    } catch (_) {
      // Ignore load error.
      // The next request can try again.
    }
  }

  // ============================================================
  // CHECK READY
  // ============================================================

  Future<bool> isRewardedAdReady() async {
    if (!_initialized || rewardedAdUnitId.isEmpty) {
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
          await _miningService.getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      _adsWatched = count.clamp(
        0,
        AppConfig.maxAdsPerSession,
      );

      return _adsWatched;
    } catch (_) {
      return _adsWatched;
    }
  }

  // ============================================================
  // WATCH + RECORD
  // ============================================================

  Future<Map<String, dynamic>> watchAdAndRecord({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    if (remainingAds <= 0) {
      return <String, dynamic>{
        'success': false,
        'message':
            'You have reached the maximum of '
            '${AppConfig.maxAdsPerSession} ads '
            'for this mining session.',
        'ads_watched': _adsWatched,
        'remaining_ads': 0,
        'ad_boost': currentAdBoost,
      };
    }

    if (!isConfigured) {
      return <String, dynamic>{
        'success': false,
        'message':
            'Rewarded ads are not configured yet.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    final initialized = await initialize();

    if (!initialized) {
      return <String, dynamic>{
        'success': false,
        'message':
            'Rewarded ads are temporarily unavailable.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    final ready = await isRewardedAdReady();

    if (!ready) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'Rewarded ad is not ready. Please try again.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    final rewarded = await _showRewardedAd();

    if (!rewarded) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'The ad was not completed, so no FAN '
            'mining boost was added.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    // ========================================================
    // SERVER RECORDING
    // ========================================================

    try {
      final result =
          await _miningService.recordRewardedAd();

      final success =
          result['success'] == true ||
          result['recorded'] == true ||
          result['ok'] == true;

      if (!success) {
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
        _adsWatched = serverCount.toInt().clamp(
              0,
              AppConfig.maxAdsPerSession,
            );
      } else {
        _adsWatched =
            (_adsWatched + 1).clamp(
          0,
          AppConfig.maxAdsPerSession,
        );
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
        'reward_rate': AppConfig.adBoostPerAd,
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
    if (_rewardCompleter != null) {
      return false;
    }

    final completer = Completer<bool>();

    _rewardCompleter = completer;

    try {
      AppLovinMAX.showRewardedAd(
        rewardedAdUnitId,
      );

      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      _completeReward(false);
      return false;
    } finally {
      _rewardCompleter = null;
    }
  }

  // ============================================================
  // COMPLETE REWARD
  // ============================================================

  void _completeReward(bool rewarded) {
    final completer = _rewardCompleter;

    if (completer == null ||
        completer.isCompleted) {
      return;
    }

    completer.complete(rewarded);
  }

  // ============================================================
  // REFRESH
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
  }
}
