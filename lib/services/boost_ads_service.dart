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

  Completer<bool>? _initializationCompleter;
  Completer<bool>? _rewardCompleter;

  bool _rewardReceived = false;
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
    final remaining = AppConfig.maxAdsPerSession - _adsWatched;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  double get currentAdBoost => calculateBoost(_adsWatched);

  // ============================================================
  // BOOST CALCULATION
  // ============================================================

  double calculateBoost(int ads) {
    final safeAds = _clampAds(ads);

    final boost = safeAds * AppConfig.adBoostPerAd;

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

    if (adsWatched >= AppConfig.maxAdsPerSession) {
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

    if (!isConfigured) {
      return false;
    }

    // If initialization is already running,
    // wait for the same initialization instead
    // of immediately returning false.
    if (_initializing) {
      final existing = _initializationCompleter;

      if (existing != null) {
        return existing.future;
      }

      return false;
    }

    _initializing = true;

    final completer = Completer<bool>();
    _initializationCompleter = completer;

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
            // Do not complete a reward here.
            //
            // This callback belongs to ad loading,
            // not to an active reward transaction.
          },

          onAdDisplayedCallback: (ad) {
            // Ad displayed successfully.
          },

          onAdDisplayFailedCallback: (
            ad,
            error,
          ) {
            _completeReward(false);
          },

          onAdClickedCallback: (ad) {
            // Clicking an ad does NOT grant FAN.
          },

          onAdHiddenCallback: (ad) {
            /*
             * Closing the rewarded ad does not itself
             * grant FAN.
             *
             * The reward is valid only if AppLovin has
             * already fired onAdReceivedRewardCallback.
             */
            if (!_rewardReceived) {
              _completeReward(false);
            }

            unawaited(_loadRewardedAd());
          },

          onAdReceivedRewardCallback: (
            ad,
            reward,
          ) {
            /*
             * AppLovin has confirmed the rewarded event.
             */
            _rewardReceived = true;

            _completeReward(true);
          },

          onAdRevenuePaidCallback: (ad) {
            // Revenue information only.
          },
        ),
      );

      final configuration = await AppLovinMAX.initialize(
        sdkKey,
      );

      if (configuration == null) {
        _initialized = false;

        if (!completer.isCompleted) {
          completer.complete(false);
        }

        return false;
      }

      _initialized = true;

      await _loadRewardedAd();

      if (!completer.isCompleted) {
        completer.complete(true);
      }

      return true;
    } catch (_) {
      _initialized = false;

      if (!completer.isCompleted) {
        completer.complete(false);
      }

      return false;
    } finally {
      _initializing = false;

      if (identical(
        _initializationCompleter,
        completer,
      )) {
        _initializationCompleter = null;
      }
    }
  }

  // ============================================================
  // LOAD REWARDED AD
  // ============================================================

  Future<void> _loadRewardedAd() async {
    if (!_initialized) {
      return;
    }

    if (rewardedAdUnitId.isEmpty) {
      return;
    }

    try {
      AppLovinMAX.loadRewardedAd(
        rewardedAdUnitId,
      );
    } catch (_) {
      // Ignore load errors.
      //
      // The next request can attempt another load.
    }
  }

  // ============================================================
  // CHECK REWARDED AD READY
  // ============================================================

  Future<bool> isRewardedAdReady() async {
    if (!_initialized) {
      return false;
    }

    if (rewardedAdUnitId.isEmpty) {
      return false;
    }

    try {
      final ready = await AppLovinMAX.isRewardedAdReady(
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
      final count = await _miningService.getAdsWatchedForSession(
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

  Future<Map<String, dynamic>> watchAdAndRecord({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    // ----------------------------------------------------------
    // SESSION VALIDATION
    // ----------------------------------------------------------

    final now = DateTime.now();

    if (endsAt != null && !now.isBefore(endsAt)) {
      return _failure(
        'This mining session has ended. '
        'Claim your mining reward and start a new session.',
      );
    }

    // ----------------------------------------------------------
    // REFRESH SERVER AD COUNT
    // ----------------------------------------------------------

    await getAdsWatchedForSession(
      startedAt: startedAt,
      endsAt: endsAt,
    );

    if (_adsWatched >= AppConfig.maxAdsPerSession) {
      return _failure(
        'You have reached the maximum of '
        '${AppConfig.maxAdsPerSession} ads '
        'for this mining session.',
      );
    }

    // ----------------------------------------------------------
    // CONFIGURATION
    // ----------------------------------------------------------

    if (!isConfigured) {
      return _failure(
        'Rewarded ads are not configured yet.',
      );
    }

    // ----------------------------------------------------------
    // INITIALIZE
    // ----------------------------------------------------------

    final initialized = await initialize();

    if (!initialized) {
      return _failure(
        'Rewarded ads are temporarily unavailable.',
      );
    }

    // ----------------------------------------------------------
    // CHECK AD READY
    // ----------------------------------------------------------

    var ready = await isRewardedAdReady();

    if (!ready) {
      await _loadRewardedAd();

      // Give AppLovin a short moment to finish loading.
      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );

      ready = await isRewardedAdReady();
    }

    if (!ready) {
      return _failure(
        'Rewarded ad is not ready. Please try again.',
      );
    }

    // ----------------------------------------------------------
    // SHOW AD
    // ----------------------------------------------------------

    final rewarded = await _showRewardedAd();

    if (!rewarded) {
      await _loadRewardedAd();

      return _failure(
        'The ad was not completed, so no FAN '
        'mining boost was added.',
      );
    }

    // ----------------------------------------------------------
    // SERVER RECORDING
    // ----------------------------------------------------------

    try {
      /*
       * The database remains responsible for the actual
       * session count and reward calculation.
       */
      final result = await _miningService.recordRewardedAd();

      final success =
          result['success'] == true ||
          result['recorded'] == true ||
          result['ok'] == true;

      if (!success) {
        await _loadRewardedAd();

        return <String, dynamic>{
          'success': false,
          'message': result['message']?.toString() ??
              'The rewarded ad could not be recorded.',
          'ads_watched': _adsWatched,
          'remaining_ads': remainingAds,
          'ad_boost': currentAdBoost,
        };
      }

      // --------------------------------------------------------
      // SERVER COUNT
      // --------------------------------------------------------

      final serverCount = result['ads_watched'];

      if (serverCount is num) {
        _adsWatched = _clampAds(
          serverCount.toInt(),
        );
      } else {
        _adsWatched = _clampAds(
          _adsWatched + 1,
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
    } catch (_) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'The ad was completed, but the server '
            'could not record the reward.',
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
     * Prevent multiple rewarded ads from running
     * simultaneously.
     */
    if (_rewardCompleter != null) {
      return false;
    }

    final completer = Completer<bool>();

    _rewardCompleter = completer;
    _rewardReceived = false;

    try {
      AppLovinMAX.showRewardedAd(
        rewardedAdUnitId,
      );

      final result = await completer.future.timeout(
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
  // FAILURE RESULT
  // ============================================================

  Map<String, dynamic> _failure(String message) {
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

  int _clampAds(dynamic value) {
    int count;

    if (value is int) {
      count = value;
    } else if (value is num) {
      count = value.toInt();
    } else {
      count = int.tryParse(
            value?.toString() ?? '',
          ) ??
          0;
    }

    if (count < 0) {
      return 0;
    }

    if (count > AppConfig.maxAdsPerSession) {
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

    if (_rewardCompleter != null &&
        !_rewardCompleter!.isCompleted) {
      _rewardCompleter!.complete(false);
    }

    _rewardCompleter = null;
  }
}
