import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

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

  // Prevent duplicate processing of the same rewarded-ad event.
  bool _rewardProcessing = false;
  bool _rewardGrantedForCurrentAd = false;

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

      // Set the authenticated Supabase user as
      // LevelPlay dynamic user ID.
      await LevelPlay.setDynamicUserId(userId);

      _onRewarded = onRewarded;
      _onAdClosed = onAdClosed;

      _showing = true;

      // Reset reward-processing state for this ad.
      _rewardProcessing = false;
      _rewardGrantedForCurrentAd = false;

      _rewardedAd!.showAd();

      return true;
    } catch (e) {
      _showing = false;
      _rewardProcessing = false;

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

    // Start loading the first rewarded ad.
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

    // Protect against duplicate reward callbacks.
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
       * FAN is NOT added directly on the device.
       *
       * Supabase is responsible for recording the ad
       * and calculating the mining boost.
       *
       * Base rate:
       *   0.20 FAN/H
       *
       * Ad boost:
       *   +0.10 FAN/H
       *
       * Referral boost:
       *   +0.02 FAN/H per active referral
       *
       * Maximum:
       *   7 rewarded ads per mining session.
       */

      await MiningService.instance
          .recordAndVerifyRewardedAd();

      _rewardGrantedForCurrentAd = true;

      _onRewarded?.call();

      debugPrint(
        'LevelPlay: server reward processed successfully.',
      );
    } catch (e) {
      debugPrint(
        'LevelPlay server reward processing failed: $e',
      );
    } finally {
      _rewardProcessing = false;
    }
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

    // Load the next rewarded ad.
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
