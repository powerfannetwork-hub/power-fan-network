import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'kyc_service.dart';
import 'mining_service.dart';
import 'supabase_service.dart';

class LevelPlayAdsService
    implements LevelPlayInitListener, LevelPlayRewardedAdListener {
  LevelPlayAdsService._();

  static final LevelPlayAdsService instance =
      LevelPlayAdsService._();

  // ============================================================
  // LEVELPLAY CONFIGURATION
  // ============================================================

  static const String appKeyAndroid = '27f58cf85';

  static const String rewardedAdUnitId =
      'z69e4f6g6emi98mbu';

  static const int maxAdsPerSession = 7;

  // ============================================================
  // STATE
  // ============================================================

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _loading = false;
  bool _showing = false;

  bool _rewardProcessing = false;
  bool _rewardGrantedForCurrentAd = false;

  // Number of rewarded ads already recorded by Supabase
  // before the current LevelPlay ad was shown.
  int? _adsWatchedBeforeCurrentAd;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isInitialized => _initialized;

  bool get isLoading => _loading;

  bool get isShowing => _showing;

  // ============================================================
  // INITIALIZE LEVELPLAY
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final user =
          SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: user is not authenticated yet.',
        );
        return;
      }

      final initRequest =
          LevelPlayInitRequest
              .builder(appKeyAndroid)
              .withUserId(userId)
              .build();

      await LevelPlay.init(
        initRequest: initRequest,
        initListener: this,
      );
    } catch (e) {
      debugPrint(
        'LevelPlay initialization error: $e',
      );
    }
  }

  // ============================================================
  // LOAD REWARDED AD
  // ============================================================

  Future<void> loadRewardedAd() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      return;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    if (_loading) {
      return;
    }

    try {
      final ready =
          await _rewardedAd!.isAdReady();

      if (ready) {
        return;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay ready check before load failed: $e',
      );
    }

    _loading = true;

    try {
      _rewardedAd!.loadAd();
    } catch (e) {
      _loading = false;

      debugPrint(
        'LevelPlay rewarded load error: $e',
      );
    }
  }

  // ============================================================
  // CHECK REWARDED AD READY
  // ============================================================

  Future<bool> isRewardedAdReady() async {
    if (!_initialized || _rewardedAd == null) {
      return false;
    }

    try {
      return await _rewardedAd!.isAdReady();
    } catch (e) {
      debugPrint(
        'LevelPlay ready check error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // SHOW REWARDED AD
  // ============================================================

  Future<bool> showRewardedAd({
    VoidCallback? onRewarded,
    VoidCallback? onAdClosed,
  }) async {
    if (_showing) {
      debugPrint(
        'LevelPlay: rewarded ad is already showing.',
      );
      return false;
    }

    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      return false;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    try {
      final ready =
          await _rewardedAd!.isAdReady();

      if (!ready) {
        await loadRewardedAd();

        debugPrint(
          'LevelPlay: rewarded ad is not ready yet.',
        );

        return false;
      }

      final user =
          SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: cannot show rewarded ad '
          'without user ID.',
        );

        return false;
      }

      /*
       * IMPORTANT:
       *
       * Capture the current server-side ads_watched count
       * BEFORE showing the ad.
       *
       * LevelPlay will later send the reward to the backend
       * through S2S. We use this value to confirm that the
       * server actually received and recorded the new reward.
       */
      try {
        final mining =
            await MiningService.instance.getActiveMining();

        _adsWatchedBeforeCurrentAd =
            _extractAdsWatched(mining);

        debugPrint(
          'LevelPlay: ads watched before current ad: '
          '$_adsWatchedBeforeCurrentAd',
        );
      } catch (e) {
        _adsWatchedBeforeCurrentAd = null;

        debugPrint(
          'LevelPlay: could not read current ads_watched '
          'before showing ad: $e',
        );
      }

      await LevelPlay.setDynamicUserId(userId);

      _onRewarded = onRewarded;
      _onAdClosed = onAdClosed;

      _showing = true;

      _rewardProcessing = false;
      _rewardGrantedForCurrentAd = false;

      _rewardedAd!.showAd();

      return true;
    } catch (e) {
      _showing = false;
      _rewardProcessing = false;
      _adsWatchedBeforeCurrentAd = null;

      debugPrint(
        'LevelPlay show rewarded error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // CREATE REWARDED AD
  // ============================================================

  void _createRewardedAd() {
    _rewardedAd = LevelPlayRewardedAd(
      adUnitId: rewardedAdUnitId,
    );

    _rewardedAd!.setListener(this);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _rewardedAd = null;

    _onRewarded = null;
    _onAdClosed = null;

    _initialized = false;
    _loading = false;
    _showing = false;

    _rewardProcessing = false;
    _rewardGrantedForCurrentAd = false;
    _adsWatchedBeforeCurrentAd = null;
  }

  // ============================================================
  // LEVELPLAY INITIALIZATION LISTENER
  // ============================================================

  @override
  void onInitSuccess(
    LevelPlayConfiguration configuration,
  ) {
    _initialized = true;

    debugPrint(
      'LevelPlay initialized successfully.',
    );

    _createRewardedAd();

    loadRewardedAd();
  }

  @override
  void onInitFailed(
    LevelPlayInitError error,
  ) {
    _initialized = false;
    _loading = false;

    debugPrint(
      'LevelPlay initialization failed: $error',
    );
  }

  // ============================================================
  // REWARDED AD LISTENER
  // ============================================================

  @override
  void onAdLoaded(
    LevelPlayAdInfo adInfo,
  ) {
    _loading = false;

    debugPrint(
      'LevelPlay rewarded ad loaded: $adInfo',
    );
  }

  @override
  void onAdLoadFailed(
    LevelPlayAdError error,
  ) {
    _loading = false;

    debugPrint(
      'LevelPlay rewarded ad load failed: $error',
    );
  }

  @override
  void onAdDisplayed(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded ad displayed: $adInfo',
    );
  }

  @override
  void onAdDisplayFailed(
    LevelPlayAdError error,
    LevelPlayAdInfo adInfo,
  ) {
    _showing = false;
    _rewardProcessing = false;

    debugPrint(
      'LevelPlay rewarded ad display failed: '
      '$error | $adInfo',
    );

    _onAdClosed?.call();

    _onRewarded = null;
    _onAdClosed = null;

    _rewardGrantedForCurrentAd = false;
    _adsWatchedBeforeCurrentAd = null;

    loadRewardedAd();
  }

  // ============================================================
  // REWARDED EVENT
  // ============================================================

  @override
  void onAdRewarded(
    LevelPlayReward reward,
    LevelPlayAdInfo adInfo,
  ) async {
    debugPrint(
      'LevelPlay reward received: '
      '$reward | $adInfo',
    );

    if (_rewardProcessing ||
        _rewardGrantedForCurrentAd) {
      debugPrint(
        'LevelPlay: duplicate reward event ignored.',
      );
      return;
    }

    _rewardProcessing = true;

    try {
      /*
       * IMPORTANT:
       *
       * The phone does NOT create the FAN reward.
       *
       * LevelPlay sends the reward to the Supabase
       * LevelPlay S2S endpoint.
       *
       * Supabase validates the callback and calls the
       * trusted record_levelplay_reward() RPC.
       *
       * The client only waits until ads_watched increases.
       *
       * This prevents the mobile application from directly
       * creating or verifying rewarded-ad rewards.
       */

      final previousAdsWatched =
          _adsWatchedBeforeCurrentAd;

      if (previousAdsWatched == null) {
        throw Exception(
          'Cannot confirm S2S reward because the '
          'previous ads_watched count is unavailable.',
        );
      }

      final confirmed =
          await _waitForS2SRewardConfirmation(
        previousAdsWatched: previousAdsWatched,
      );

      if (!confirmed) {
        throw Exception(
          'LevelPlay S2S reward was not confirmed '
          'by Supabase within the timeout.',
        );
      }

      /*
       * KYC DAILY BOOST
       *
       * Only record the boost day AFTER the
       * S2S reward has been confirmed by the server.
       *
       * The database prevents duplicate boost
       * records for the same day.
       */
      try {
        await KycService().recordDailyBoost();

        debugPrint(
          'KYC: daily boost recorded successfully.',
        );
      } catch (e) {
        /*
         * Do not undo the mining reward if the
         * KYC progress refresh fails.
         *
         * The S2S reward has already been confirmed
         * by the mining backend.
         */
        debugPrint(
          'KYC daily boost recording failed: $e',
        );
      }

      _rewardGrantedForCurrentAd = true;

      _onRewarded?.call();

      debugPrint(
        'LevelPlay: S2S server reward confirmed successfully.',
      );
    } catch (e) {
      debugPrint(
        'LevelPlay S2S reward confirmation failed: $e',
      );
    } finally {
      _rewardProcessing = false;
    }
  }

  // ============================================================
  // WAIT FOR S2S REWARD CONFIRMATION
  // ============================================================

  Future<bool> _waitForS2SRewardConfirmation({
    required int previousAdsWatched,
  }) async {
    const Duration timeout =
        Duration(seconds: 20);

    const Duration pollInterval =
        Duration(milliseconds: 500);

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final mining =
            await MiningService.instance.getActiveMining();

        final currentAdsWatched =
            _extractAdsWatched(mining);

        debugPrint(
          'LevelPlay S2S confirmation: '
          'previous=$previousAdsWatched '
          'current=$currentAdsWatched',
        );

        if (currentAdsWatched >
            previousAdsWatched) {
          return true;
        }
      } catch (e) {
        /*
         * A temporary network/read error should not
         * immediately fail the reward confirmation.
         *
         * Continue polling until the timeout.
         */
        debugPrint(
          'LevelPlay S2S confirmation poll failed: $e',
        );
      }

      await Future<void>.delayed(
        pollInterval,
      );
    }

    return false;
  }

  // ============================================================
  // EXTRACT ADS WATCHED
  // ============================================================

  int _extractAdsWatched(
    Map<String, dynamic> mining,
  ) {
    final value = mining['ads_watched'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value != null) {
      return int.tryParse(
            value.toString(),
          ) ??
          0;
    }

    return 0;
  }

  @override
  void onAdClicked(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded ad clicked: $adInfo',
    );
  }

  // ============================================================
  // AD CLOSED
  // ============================================================

  @override
  void onAdClosed(
    LevelPlayAdInfo adInfo,
  ) {
    _showing = false;

    debugPrint(
      'LevelPlay rewarded ad closed: $adInfo',
    );

    _onAdClosed?.call();

    _onRewarded = null;
    _onAdClosed = null;

    _rewardProcessing = false;
    _rewardGrantedForCurrentAd = false;
    _adsWatchedBeforeCurrentAd = null;

    loadRewardedAd();
  }

  // ============================================================
  // AD INFO CHANGED
  // ============================================================

  @override
  void onAdInfoChanged(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded ad info changed: $adInfo',
    );
  }
}
