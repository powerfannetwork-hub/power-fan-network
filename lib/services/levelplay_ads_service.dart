import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'mining_service.dart';
import 'supabase_service.dart';

class LevelPlayAdsService
    implements LevelPlayInitListener, LevelPlayRewardedAdListener {
  LevelPlayAdsService._();

  static final LevelPlayAdsService instance = LevelPlayAdsService._();

  static const String appKeyAndroid = '27f58cf85';
  static const String rewardedAdUnitId = 'z69e4f6g6emi98mbu';

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _loading = false;
  bool _showing = false;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  bool get isInitialized => _initialized;

  bool get isLoading => _loading;

  bool get isShowing => _showing;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final user = SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: user is not authenticated yet.',
        );
        return;
      }

      final initRequest = LevelPlayInitRequest
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

    if (await _rewardedAd!.isAdReady()) {
      return;
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

  Future<bool> showRewardedAd({
    VoidCallback? onRewarded,
    VoidCallback? onAdClosed,
  }) async {
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
      final ready = await _rewardedAd!.isAdReady();

      if (!ready) {
        await loadRewardedAd();

        return false;
      }

      final user = SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: cannot show rewarded ad without user ID.',
        );

        return false;
      }

      /*
       * Dynamic User ID is used by LevelPlay server-to-server
       * reward callbacks to identify the authenticated user.
       */
      await LevelPlay.setDynamicUserId(
        userId,
      );

      _onRewarded = onRewarded;
      _onAdClosed = onAdClosed;
      _showing = true;

      _rewardedAd!.showAd();

      return true;
    } catch (e) {
      _showing = false;

      debugPrint(
        'LevelPlay show rewarded error: $e',
      );

      return false;
    }
  }

  void _createRewardedAd() {
    _rewardedAd = LevelPlayRewardedAd(
      adUnitId: rewardedAdUnitId,
    );

    _rewardedAd!.setListener(this);
  }

  void dispose() {
    _rewardedAd = null;
    _onRewarded = null;
    _onAdClosed = null;

    _initialized = false;
    _loading = false;
    _showing = false;
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

    debugPrint(
      'LevelPlay rewarded ad display failed: '
      '$error | $adInfo',
    );

    _onAdClosed?.call();

    _onRewarded = null;
    _onAdClosed = null;

    loadRewardedAd();
  }

  @override
  void onAdRewarded(
    LevelPlayReward reward,
    LevelPlayAdInfo adInfo,
  ) async {
    debugPrint(
      'LevelPlay reward received: '
      '$reward | $adInfo',
    );

    /*
     * IMPORTANT:
     * Do NOT add FAN directly on the client.
     *
     * The authenticated Supabase RPC is responsible for
     * recording the rewarded ad and recalculating:
     *
     * Base: 0.20 FAN/H
     * Referral: +0.02 FAN/H per active referral
     * Ad: +0.10 FAN/H per completed ad
     *
     * Maximum ads per session = 7.
     */
    try {
      await MiningService.instance
          .recordAndVerifyRewardedAd();

      _onRewarded?.call();
    } catch (e) {
      debugPrint(
        'LevelPlay server reward processing failed: $e',
      );
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

    /*
     * Load the next rewarded ad.
     */
    loadRewardedAd();
  }

  @override
  void onAdInfoChanged(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded ad info changed: $adInfo',
    );
  }
}
