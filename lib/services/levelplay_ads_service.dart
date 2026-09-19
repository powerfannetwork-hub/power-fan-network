import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

class LevelPlayAdsService with LevelPlayInitListener {
  LevelPlayAdsService._();

  static final LevelPlayAdsService instance = LevelPlayAdsService._();

  static const String appKey = '27f58cf85';
  static const String rewardedAdUnitId = 'z69e4fg6emi98mbu';
  static const String placementName = 'Default';

  final SupabaseClient _supabase = Supabase.instance.client;

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _initializing = false;
  bool _loadingAd = false;
  bool _showingAd = false;

  Future<void>? _initializeFuture;
  Completer<bool>? _adLoadCompleter;

  FutureOr<void> Function()? _onRewarded;
  FutureOr<void> Function()? _onAdClosed;

  bool get isInitialized => _initialized;
  bool get isLoading => _loadingAd;
  bool get isShowing => _showingAd;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (_initializeFuture != null) {
      return _initializeFuture!;
    }

    _initializeFuture = _initializeInternal();

    try {
      await _initializeFuture!;
    } finally {
      if (!_initialized) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (_initializing || _initialized) {
      return;
    }

    _initializing = true;

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'User must be signed in before LevelPlay initialization.',
        );
      }

      /*
       * Enable adapter debug logs and integration validation only
       * during debug builds. These are useful while testing the
       * mediation setup and should not remain enabled in release.
       */
      if (kDebugMode) {
        await LevelPlay.setAdaptersDebug(true);
        LevelPlay.validateIntegration();
      }

      final initRequest = LevelPlayInitRequest.builder(appKey)
          .withUserId(user.id)
          .build();

      await LevelPlay.init(
        initRequest: initRequest,
        initListener: this,
      );

      /*
       * Keep the Dynamic User ID configured before any rewarded ad
       * is shown. The UUID hyphens are removed because LevelPlay
       * requires an alphanumeric value with a maximum of 64 chars.
       */
      await _setDynamicUserId(user.id);

      _createRewardedAd();

      _initialized = true;

      await loadRewardedAd();
    } catch (e, st) {
      _initialized = false;

      debugPrint(
        'LevelPlay initialization error: $e',
      );
      debugPrint('$st');

      rethrow;
    } finally {
      _initializing = false;
    }
  }

  Future<void> _setDynamicUserId(String userId) async {
    final dynamicUserId = userId.replaceAll('-', '');

    if (dynamicUserId.isEmpty) {
      throw Exception(
        'LevelPlay Dynamic User ID cannot be empty.',
      );
    }

    if (dynamicUserId.length > 64) {
      throw Exception(
        'LevelPlay Dynamic User ID cannot exceed 64 characters.',
      );
    }

    await LevelPlay.setDynamicUserId(
      dynamicUserId,
    );

    debugPrint(
      'LevelPlay Dynamic User ID configured.',
    );
  }

  void _createRewardedAd() {
    _rewardedAd = LevelPlayRewardedAd(
      adUnitId: rewardedAdUnitId,
    );

    _rewardedAd!.setListener(
      _RewardedAdListener(this),
    );
  }

  Future<bool> loadRewardedAd() async {
    try {
      if (!_initialized) {
        /*
         * During initialization, _initialized is set after
         * LevelPlay.init succeeds and before this method is called.
         */
        await initialize();
      }

      if (!_initialized) {
        return false;
      }

      if (_rewardedAd == null) {
        _createRewardedAd();
      }

      /*
       * Do not start a second load while one is already running.
       * Wait for the existing load callback instead.
       */
      if (_loadingAd) {
        final existingLoad = _adLoadCompleter?.future;

        if (existingLoad == null) {
          return false;
        }

        try {
          return await existingLoad.timeout(
            const Duration(seconds: 15),
          );
        } catch (_) {
          return false;
        }
      }

      _loadingAd = true;

      final completer = Completer<bool>();
      _adLoadCompleter = completer;

      try {
        await _rewardedAd!.loadAd();

        /*
         * LevelPlay reports the real result through
         * onAdLoaded / onAdLoadFailed. Do not assume that
         * loadAd() returning means the ad is ready.
         */
        return await completer.future.timeout(
          const Duration(seconds: 15),
        );
      } catch (e, st) {
        _loadingAd = false;

        if (!completer.isCompleted) {
          completer.complete(false);
        }

        if (identical(_adLoadCompleter, completer)) {
          _adLoadCompleter = null;
        }

        debugPrint(
          'LevelPlay loadRewardedAd error: $e',
        );
        debugPrint('$st');

        return false;
      }
    } catch (e, st) {
      _loadingAd = false;

      debugPrint(
        'LevelPlay loadRewardedAd error: $e',
      );
      debugPrint('$st');

      return false;
    }
  }

  Future<bool> isRewardedAdReady() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      if (!_initialized) {
        return false;
      }

      if (_rewardedAd == null) {
        _createRewardedAd();
      }

      return await _rewardedAd!.isAdReady();
    } catch (e, st) {
      debugPrint(
        'LevelPlay isRewardedAdReady error: $e',
      );
      debugPrint('$st');

      return false;
    }
  }

  Future<bool> showRewardedAd({
    FutureOr<void> Function()? onRewarded,
    FutureOr<void> Function()? onAdClosed,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      if (!_initialized) {
        return false;
      }

      if (_showingAd) {
        debugPrint(
          'LevelPlay rewarded ad is already showing.',
        );
        return false;
      }

      final user = _supabase.auth.currentUser;

      if (user == null) {
        debugPrint(
          'LevelPlay rewarded ad cannot show without an authenticated user.',
        );
        return false;
      }

      /*
       * Set the Dynamic User ID immediately before showing the ad.
       * This keeps the S2S user mapping correct even after a session
       * change or re-authentication.
       */
      await _setDynamicUserId(user.id);

      if (_rewardedAd == null) {
        _createRewardedAd();
      }

      var ready = await _rewardedAd!.isAdReady();

      if (!ready) {
        /*
         * Wait for the actual LevelPlay load callback instead of
         * waiting an arbitrary 500 ms.
         */
        final loaded = await loadRewardedAd();

        if (!loaded) {
          debugPrint(
            'LevelPlay rewarded ad did not finish loading.',
          );
          return false;
        }

        ready = await _rewardedAd!.isAdReady();
      }

      if (!ready) {
        debugPrint(
          'LevelPlay rewarded ad is still not ready after loading.',
        );
        return false;
      }

      _onRewarded = onRewarded;
      _onAdClosed = onAdClosed;

      _showingAd = true;

      await _rewardedAd!.showAd(
        placementName: placementName,
      );

      return true;
    } catch (e, st) {
      _showingAd = false;
      _onRewarded = null;
      _onAdClosed = null;

      debugPrint(
        'LevelPlay showRewardedAd error: $e',
      );
      debugPrint('$st');

      unawaited(loadRewardedAd());

      return false;
    }
  }

  Future<bool> showActivationAd({
    FutureOr<void> Function()? onRewarded,
    FutureOr<void> Function()? onAdClosed,
  }) {
    return showRewardedAd(
      onRewarded: onRewarded,
      onAdClosed: onAdClosed,
    );
  }

  Future<void> reloadRewardedAd() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      return;
    }

    await loadRewardedAd();
  }

  Future<bool> isAdReady() async {
    return isRewardedAdReady();
  }

  Future<bool> showRewarded() async {
    return showRewardedAd();
  }

  Future<bool> _recordAdRewardForKyc(
    LevelPlayReward reward,
  ) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        debugPrint(
          'KYC ad reward record skipped: user is not authenticated.',
        );
        return false;
      }

      final rawAmount = reward.amount;
      final double amount = rawAmount.toDouble();

      final response = await _supabase.rpc(
        'record_ad_reward_for_kyc',
        params: {
          'p_reward_amount': amount,
          'p_watched_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      final success = data['success'] == true;

      if (!success) {
        debugPrint(
          'KYC ad reward record failed: $data',
        );
        return false;
      }

      debugPrint(
        'KYC ad reward recorded successfully.',
      );

      return true;
    } catch (e, st) {
      debugPrint(
        'KYC ad reward record error: $e',
      );
      debugPrint('$st');

      return false;
    }
  }

  void _handleAdLoaded(
    LevelPlayAdInfo adInfo,
  ) {
    _loadingAd = false;

    final completer = _adLoadCompleter;

    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }

    _adLoadCompleter = null;

    debugPrint(
      'LevelPlay rewarded ad loaded: ${adInfo.adUnitId}',
    );
  }

  void _handleAdLoadFailed(
    LevelPlayAdError error,
  ) {
    _loadingAd = false;

    final completer = _adLoadCompleter;

    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }

    _adLoadCompleter = null;

    debugPrint(
      'LevelPlay rewarded ad load failed: '
      '${error.errorCode} - ${error.errorMessage}',
    );
  }

  void _handleAdDisplayed(
    LevelPlayAdInfo adInfo,
  ) {
    _showingAd = true;

    debugPrint(
      'LevelPlay rewarded ad displayed: ${adInfo.adUnitId}',
    );
  }

  void _handleAdDisplayFailed(
    LevelPlayAdError error,
    LevelPlayAdInfo adInfo,
  ) {
    _showingAd = false;

    debugPrint(
      'LevelPlay rewarded ad display failed: '
      '${error.errorCode} - ${error.errorMessage}',
    );

    final closedCallback = _onAdClosed;

    _onRewarded = null;
    _onAdClosed = null;

    if (closedCallback != null) {
      unawaited(_runCallback(closedCallback));
    }

    unawaited(loadRewardedAd());
  }

  void _handleAdClicked(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded ad clicked: ${adInfo.adUnitId}',
    );
  }

  void _handleAdClosed(
    LevelPlayAdInfo adInfo,
  ) {
    _showingAd = false;

    debugPrint(
      'LevelPlay rewarded ad closed: ${adInfo.adUnitId}',
    );

    final closedCallback = _onAdClosed;

    _onAdClosed = null;

    if (closedCallback != null) {
      unawaited(_runCallback(closedCallback));
    }

    /*
     * Reuse the same rewarded ad object and load the next ad after
     * the current one is closed.
     */
    unawaited(loadRewardedAd());
  }

  void _handleAdRewarded(
    LevelPlayReward reward,
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded event received: '
      'amount=${reward.amount}, name=${reward.name}',
    );

    /*
     * IMPORTANT:
     *
     * This record is created before the existing onRewarded callback.
     *
     * Current application chain:
     *
     * LevelPlay reward
     *      ↓
     * record_ad_reward_for_kyc()
     *      ↓
     * KYC daily boost tracking
     *
     * Keep this call unchanged until the backend/S2S reward path
     * has been checked for possible duplicate reward crediting.
     */
    unawaited(
      _recordAdRewardForKyc(reward).then((recorded) {
        if (!recorded) {
          debugPrint(
            'KYC ad reward was not recorded.',
          );
        }
      }),
    );

    final rewardedCallback = _onRewarded;

    _onRewarded = null;

    if (rewardedCallback != null) {
      unawaited(_runCallback(rewardedCallback));
    }
  }

  void _handleAdInfoChanged(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay rewarded ad info changed: ${adInfo.adUnitId}',
    );
  }

  Future<void> _runCallback(
    FutureOr<void> Function() callback,
  ) async {
    try {
      await callback();
    } catch (e, st) {
      debugPrint(
        'LevelPlay callback error: $e',
      );
      debugPrint('$st');
    }
  }

  @override
  void onInitSuccess(
    LevelPlayConfiguration configuration,
  ) {
    _initialized = true;

    debugPrint(
      'LevelPlay initialization successful.',
    );
  }

  @override
  void onInitFailed(
    LevelPlayInitError error,
  ) {
    _initialized = false;

    debugPrint(
      'LevelPlay initialization failed: '
      '${error.errorCode} - ${error.errorMessage}',
    );
  }

  void dispose() {
    _rewardedAd = null;

    _initialized = false;
    _initializing = false;
    _loadingAd = false;
    _showingAd = false;

    _initializeFuture = null;
    _adLoadCompleter = null;

    _onRewarded = null;
    _onAdClosed = null;
  }
}

class _RewardedAdListener with LevelPlayRewardedAdListener {
  _RewardedAdListener(this._service);

  final LevelPlayAdsService _service;

  @override
  void onAdLoaded(
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdLoaded(adInfo);
  }

  @override
  void onAdLoadFailed(
    LevelPlayAdError error,
  ) {
    _service._handleAdLoadFailed(error);
  }

  @override
  void onAdDisplayed(
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdDisplayed(adInfo);
  }

  @override
  void onAdDisplayFailed(
    LevelPlayAdError error,
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdDisplayFailed(
      error,
      adInfo,
    );
  }

  @override
  void onAdClicked(
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdClicked(
      adInfo,
    );
  }

  @override
  void onAdClosed(
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdClosed(
      adInfo,
    );
  }

  @override
  void onAdRewarded(
    LevelPlayReward reward,
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdRewarded(
      reward,
      adInfo,
    );
  }

  @override
  void onAdInfoChanged(
    LevelPlayAdInfo adInfo,
  ) {
    _service._handleAdInfoChanged(
      adInfo,
    );
  }
}

