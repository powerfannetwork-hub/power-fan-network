import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'mining_service.dart';
import 'supabase_service.dart';

class LevelPlayAdsService
    implements LevelPlayInitListener, LevelPlayRewardedAdListener {
  static final LevelPlayAdsService instance =
      LevelPlayAdsService._internal();

  LevelPlayAdsService._internal();

  factory LevelPlayAdsService() => instance;

  // ============================================================
  // CONFIG
  // ============================================================

  static const String appKeyAndroid = '27f58cf85';

  static const String rewardedAdUnitId = 'z69e4f6g6emi98mbu';

  static const String rewardedPlacementName = 'Default';

  static const int maxAdsPerSession = 7;

  static const Duration initTimeout = Duration(seconds: 20);

  static const Duration adLoadTimeout = Duration(seconds: 20);

  static const Duration adReadyPollInterval =
      Duration(milliseconds: 500);

  // ============================================================
  // STATE
  // ============================================================

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _initializing = false;
  bool _loading = false;
  bool _showing = false;
  bool _rewardProcessing = false;
  bool _rewardGrantedForCurrentAd = false;

  int _adsWatchedBeforeCurrentAd = 0;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  Completer<void>? _initCompleter;
  Completer<bool>? _loadCompleter;

  String? _lastAdLoadError;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (_initializing) {
      final completer = _initCompleter;

      if (completer != null) {
        try {
          await completer.future.timeout(initTimeout);
        } catch (_) {}
      }

      return;
    }

    final user = SupabaseService.client.auth.currentUser;

    final userId = user?.id;

    if (userId == null || userId.isEmpty) {
      debugPrint(
        'LevelPlay: user is not authenticated.',
      );

      return;
    }

    _initializing = true;

    final completer = Completer<void>();

    _initCompleter = completer;

    try {
      final initRequest = LevelPlayInitRequest
          .builder(appKeyAndroid)
          .withUserId(userId)
          .build();

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: INITIALIZING',
      );

      debugPrint(
        'LevelPlay: app key = $appKeyAndroid',
      );

      debugPrint(
        'LevelPlay: rewarded ad unit = $rewardedAdUnitId',
      );

      debugPrint(
        '================================================',
      );

      await LevelPlay.init(
        initRequest: initRequest,
        initListener: this,
      );

      try {
        await completer.future.timeout(initTimeout);
      } catch (_) {
        debugPrint(
          'LevelPlay: initialization timeout.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: initialization error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _initialized = false;

      if (!completer.isCompleted) {
        completer.complete();
      }
    } finally {
      _initializing = false;

      if (identical(_initCompleter, completer)) {
        _initCompleter = null;
      }
    }
  }

  // ============================================================
  // PUBLIC READY CHECK
  // ============================================================

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

      final ad = _rewardedAd;

      if (ad == null) {
        return false;
      }

      final ready = await ad.isAdReady();

      debugPrint(
        'LevelPlay: isRewardedAdReady = $ready',
      );

      return ready;
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: isRewardedAdReady ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return false;
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
      debugPrint(
        'LevelPlay: cannot load because SDK is not initialized.',
      );

      return;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    final ad = _rewardedAd;

    if (ad == null) {
      debugPrint(
        'LevelPlay: rewarded ad object is NULL.',
      );

      return;
    }

    if (_loading) {
      debugPrint(
        'LevelPlay: ad loading already in progress.',
      );

      return;
    }

    try {
      final ready = await ad.isAdReady();

      if (ready) {
        debugPrint(
          'LevelPlay: rewarded ad already READY.',
        );

        return;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: initial ready check failed: $e',
      );
    }

    _loading = true;

    _lastAdLoadError = null;

    final completer = Completer<bool>();

    _loadCompleter = completer;

    try {
      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: LOADING REWARDED AD',
      );

      debugPrint(
        'LevelPlay: ad unit = $rewardedAdUnitId',
      );

      debugPrint(
        '================================================',
      );

      await ad.loadAd();

      debugPrint(
        'LevelPlay: loadAd() request sent.',
      );

      bool loaded = false;

      try {
        loaded = await completer.future.timeout(
          adLoadTimeout,
          onTimeout: () => false,
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: load completer error: $e',
        );
      }

      if (loaded) {
        debugPrint(
          '================================================',
        );

        debugPrint(
          'LevelPlay: REWARDED AD LOAD CONFIRMED',
        );

        debugPrint(
          '================================================',
        );
      } else {
        debugPrint(
          '================================================',
        );

        debugPrint(
          'LevelPlay: REWARDED AD DID NOT LOAD',
        );

        if (_lastAdLoadError != null) {
          debugPrint(
            'LevelPlay ERROR: $_lastAdLoadError',
          );
        }

        debugPrint(
          '================================================',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: loadAd() ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!completer.isCompleted) {
        completer.complete(false);
      }
    } finally {
      _loading = false;

      if (identical(_loadCompleter, completer)) {
        _loadCompleter = null;
      }
    }
  }

  // ============================================================
  // ENSURE AD READY
  // ============================================================

  Future<bool> _ensureRewardedAdReady() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      debugPrint(
        'LevelPlay: SDK is NOT initialized.',
      );

      return false;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    final ad = _rewardedAd;

    if (ad == null) {
      debugPrint(
        'LevelPlay: rewarded ad object is NULL.',
      );

      return false;
    }

    // ----------------------------------------------------------
    // CHECK CURRENT STATE
    // ----------------------------------------------------------

    try {
      final ready = await ad.isAdReady();

      debugPrint(
        'LevelPlay: CURRENT READY = $ready',
      );

      if (ready) {
        return true;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: ready check failed: $e',
      );
    }

    // ----------------------------------------------------------
    // LOAD ONCE
    // ----------------------------------------------------------

    await loadRewardedAd();

    // ----------------------------------------------------------
    // POLL
    // ----------------------------------------------------------

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < adLoadTimeout) {
      try {
        final ready = await ad.isAdReady();

        if (ready) {
          debugPrint(
            '================================================',
          );

          debugPrint(
            'LevelPlay: REWARDED AD IS READY',
          );

          debugPrint(
            '================================================',
          );

          return true;
        }
      } catch (e) {
        debugPrint(
          'LevelPlay: readiness check error: $e',
        );
      }

      await Future<void>.delayed(
        adReadyPollInterval,
      );
    }

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: NO READY REWARDED AD',
    );

    if (_lastAdLoadError != null) {
      debugPrint(
        'LevelPlay FINAL LOAD ERROR: $_lastAdLoadError',
      );
    }

    debugPrint(
      '================================================',
    );

    return false;
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
        'LevelPlay: another ad is already showing.',
      );

      return false;
    }

    try {
      // --------------------------------------------------------
      // INITIALIZE
      // --------------------------------------------------------

      if (!_initialized) {
        await initialize();
      }

      if (!_initialized) {
        debugPrint(
          'LevelPlay: initialization failed.',
        );

        return false;
      }

      // --------------------------------------------------------
      // AUTH
      // --------------------------------------------------------

      final user = SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: user is NOT authenticated.',
        );

        return false;
      }

      // --------------------------------------------------------
      // GET ACTIVE MINING
      // --------------------------------------------------------

      final mining =
          await MiningService.instance.getActiveMining();

      if (mining.isEmpty) {
        debugPrint(
          'LevelPlay: no mining data.',
        );

        return false;
      }

      final active = _isMiningActive(mining);

      if (!active) {
        debugPrint(
          'LevelPlay: mining session is NOT active.',
        );

        return false;
      }

      final adsWatched = _extractAdsWatched(mining);

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: WATCH AD REQUEST',
      );

      debugPrint(
        'LevelPlay: active = $active',
      );

      debugPrint(
        'LevelPlay: ads watched = $adsWatched',
      );

      debugPrint(
        'LevelPlay: max ads = $maxAdsPerSession',
      );

      debugPrint(
        '================================================',
      );

      // --------------------------------------------------------
      // MAX ADS
      // --------------------------------------------------------

      if (adsWatched >= maxAdsPerSession) {
        debugPrint(
          'LevelPlay: maximum 7 ads reached.',
        );

        return false;
      }

      // --------------------------------------------------------
      // GET REAL AD
      // --------------------------------------------------------

      final ready = await _ensureRewardedAdReady();

      if (!ready) {
        debugPrint(
          'LevelPlay: rewarded ad is NOT ready.',
        );

        return false;
      }

      // --------------------------------------------------------
      // SAVE STATE
      // --------------------------------------------------------

      _adsWatchedBeforeCurrentAd = adsWatched;

      _rewardProcessing = false;

      _rewardGrantedForCurrentAd = false;

      _onRewarded = onRewarded;

      _onAdClosed = onAdClosed;

      // --------------------------------------------------------
      // DYNAMIC USER ID
      // --------------------------------------------------------

      try {
        await LevelPlay.setDynamicUserId(userId);

        debugPrint(
          'LevelPlay: dynamic user ID set.',
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: setDynamicUserId failed: $e',
        );
      }

      // --------------------------------------------------------
      // FINAL READY CHECK
      // --------------------------------------------------------

      final ad = _rewardedAd;

      if (ad == null) {
        debugPrint(
          'LevelPlay: rewarded ad object is NULL before show.',
        );

        _clearCurrentAdState();

        return false;
      }

      final finalReady = await ad.isAdReady();

      if (!finalReady) {
        debugPrint(
          'LevelPlay: ad became NOT READY before show.',
        );

        _clearCurrentAdState();

        unawaited(
          loadRewardedAd(),
        );

        return false;
      }

      // --------------------------------------------------------
      // SHOW
      // --------------------------------------------------------

      _showing = true;

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: SHOWING REWARDED AD',
      );

      debugPrint(
        'LevelPlay: placement = $rewardedPlacementName',
      );

      debugPrint(
        'LevelPlay: previous ads = '
        '$_adsWatchedBeforeCurrentAd',
      );

      debugPrint(
        '================================================',
      );

      await ad.showAd(
        placementName: rewardedPlacementName,
      );

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: showRewardedAd ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _showing = false;
      _rewardProcessing = false;

      _clearCurrentAdState();

      unawaited(
        loadRewardedAd(),
      );

      return false;
    }
  }

  // ============================================================
  // CREATE REWARDED AD
  // ============================================================

  void _createRewardedAd() {
    if (_rewardedAd != null) {
      return;
    }

    try {
      final ad = LevelPlayRewardedAd(
        adUnitId: rewardedAdUnitId,
      );

      ad.setListener(this);

      _rewardedAd = ad;

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: REWARDED AD OBJECT CREATED',
      );

      debugPrint(
        'LevelPlay: ad unit = $rewardedAdUnitId',
      );

      debugPrint(
        '================================================',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: failed to create rewarded ad: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _rewardedAd = null;
    }
  }

  // ============================================================
  // INIT SUCCESS
  // ============================================================

  @override
  void onInitSuccess(
    LevelPlayConfiguration configuration,
  ) {
    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: INIT SUCCESS',
    );

    debugPrint(
      'Configuration: $configuration',
    );

    debugPrint(
      '================================================',
    );

    _initialized = true;

    _createRewardedAd();

    final completer = _initCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete();
    }

    // Load the first rewarded ad immediately.
    unawaited(
      loadRewardedAd(),
    );
  }

  // ============================================================
  // INIT FAILED
  // ============================================================

  @override
  void onInitFailed(
    LevelPlayInitError error,
  ) {
    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: INIT FAILED',
    );

    debugPrint(
      'LevelPlay INIT ERROR: $error',
    );

    debugPrint(
      '================================================',
    );

    _initialized = false;
    _loading = false;

    final completer = _initCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete();
    }
  }

  // ============================================================
  // AD LOADED
  // ============================================================

  @override
  void onAdLoaded(
    LevelPlayAdInfo adInfo,
  ) {
    _loading = false;

    _lastAdLoadError = null;

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: REWARDED AD LOADED SUCCESSFULLY',
    );

    debugPrint(
      'Ad info: $adInfo',
    );

    debugPrint(
      '================================================',
    );

    final completer = _loadCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete(true);
    }
  }

  // ============================================================
  // AD LOAD FAILED
  // ============================================================

  @override
  void onAdLoadFailed(
    LevelPlayAdError error,
  ) {
    _loading = false;

    _lastAdLoadError = error.toString();

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: REWARDED AD LOAD FAILED',
    );

    debugPrint(
      'ERROR: $error',
    );

    debugPrint(
      '================================================',
    );

    final completer = _loadCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete(false);
    }
  }

  // ============================================================
  // AD DISPLAYED
  // ============================================================

  @override
  void onAdDisplayed(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay: REWARDED AD DISPLAYED.',
    );

    debugPrint(
      '$adInfo',
    );
  }

  // ============================================================
  // AD DISPLAY FAILED
  // ============================================================

  @override
  void onAdDisplayFailed(
    LevelPlayAdError error,
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: AD DISPLAY FAILED',
    );

    debugPrint(
      'ERROR: $error',
    );

    debugPrint(
      'AD INFO: $adInfo',
    );

    debugPrint(
      '================================================',
    );

    _showing = false;
    _rewardProcessing = false;

    final callback = _onAdClosed;

    _clearCurrentAdState();

    callback?.call();

    unawaited(
      loadRewardedAd(),
    );
  }

  // ============================================================
  // AD REWARDED
  // ============================================================

  @override
  void onAdRewarded(
    LevelPlayReward reward,
    LevelPlayAdInfo adInfo,
  ) {
    if (_rewardProcessing) {
      debugPrint(
        'LevelPlay: duplicate reward ignored.',
      );

      return;
    }

    if (_rewardGrantedForCurrentAd) {
      debugPrint(
        'LevelPlay: reward already granted.',
      );

      return;
    }

    _rewardProcessing = true;

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: REWARDED CALLBACK RECEIVED',
    );

    debugPrint(
      'Reward name: ${reward.name}',
    );

    debugPrint(
      'Reward amount: ${reward.amount}',
    );

    debugPrint(
      'Ad info: $adInfo',
    );

    debugPrint(
      '================================================',
    );

    unawaited(
      _processMiningAdReward(),
    );
  }

  // ============================================================
  // PROCESS MINING REWARD
  // ============================================================

  Future<void> _processMiningAdReward() async {
    try {
      final response =
          await SupabaseService.client.rpc(
        'record_rewarded_ad',
        params: {
          'p_ad_reference': 'levelplay',
        },
      );

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: record_rewarded_ad RESPONSE',
      );

      debugPrint(
        '$response',
      );

      debugPrint(
        '================================================',
      );

      final success = _extractBool(
        response,
        const [
          'success',
        ],
      );

      if (success != true) {
        debugPrint(
          'LevelPlay: record_rewarded_ad FAILED.',
        );

        _rewardProcessing = false;

        return;
      }

      final adId = _extractString(
        response,
        const [
          'ad_id',
          'adId',
          'id',
        ],
      );

      if (adId == null || adId.isEmpty) {
        debugPrint(
          'LevelPlay: record_rewarded_ad returned no ad_id.',
        );

        _rewardProcessing = false;

        return;
      }

      // --------------------------------------------------------
      // VERIFY THE AD
      // --------------------------------------------------------

      final verifyResponse =
          await SupabaseService.client.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': adId,
        },
      );

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: verify_rewarded_ad RESPONSE',
      );

      debugPrint(
        '$verifyResponse',
      );

      debugPrint(
        '================================================',
      );

      final verified = _extractBool(
        verifyResponse,
        const [
          'success',
        ],
      );

      if (verified != true) {
        debugPrint(
          'LevelPlay: verify_rewarded_ad FAILED.',
        );

        _rewardProcessing = false;

        return;
      }

      final newRate =
          _extractNumber(
        verifyResponse,
        const [
          'rate',
          'mining_rate',
          'new_rate',
        ],
      );

      final adsWatched =
          _extractNumber(
        verifyResponse,
        const [
          'ads_watched',
          'ad_count',
        ],
      );

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: REWARD VERIFIED SUCCESSFULLY',
      );

      debugPrint(
        'LevelPlay: ad id = $adId',
      );

      debugPrint(
        'LevelPlay: ads watched = $adsWatched',
      );

      debugPrint(
        'LevelPlay: new rate = $newRate',
      );

      debugPrint(
        '================================================',
      );

      _rewardGrantedForCurrentAd = true;

      final callback = _onRewarded;

      callback?.call();

      _rewardProcessing = false;

      if (!_showing) {
        _clearCurrentAdState();
      }
    } catch (e, stackTrace) {
      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: REWARD PROCESSING ERROR',
      );

      debugPrint(
        '$e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        '================================================',
      );

      _rewardProcessing = false;
    }
  }

  // ============================================================
  // AD CLICKED
  // ============================================================

  @override
  void onAdClicked(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay: AD CLICKED.',
    );
  }

  // ============================================================
  // AD CLOSED
  // ============================================================

  @override
  void onAdClosed(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay: AD CLOSED.',
    );

    _showing = false;

    final callback = _onAdClosed;

    callback?.call();

    // Do not destroy reward state if verification
    // is still processing.
    if (!_rewardProcessing) {
      _clearCurrentAdState();
    }

    // Load the next rewarded ad.
    unawaited(
      loadRewardedAd(),
    );
  }

  // ============================================================
  // AD INFO CHANGED
  // ============================================================

  @override
  void onAdInfoChanged(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LevelPlay: AD INFO CHANGED.',
    );

    debugPrint(
      '$adInfo',
    );
  }

  // ============================================================
  // EXTRACT ADS WATCHED
  // ============================================================

  int _extractAdsWatched(
    Map<String, dynamic> data,
  ) {
    const keys = [
      'ads_watched',
      'ad_count',
      'ads_count',
      'daily_ads_watched',
    ];

    for (final key in keys) {
      final value = data[key];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
    }

    return 0;
  }

  // ============================================================
  // EXTRACT NUMBER
  // ============================================================

  double? _extractNumber(
    dynamic response,
    List<String> keys,
  ) {
    if (response is Map) {
      for (final key in keys) {
        final value = response[key];

        if (value is num) {
          return value.toDouble();
        }

        if (value is String) {
          final parsed = double.tryParse(value);

          if (parsed != null) {
            return parsed;
          }
        }
      }

      final nested = response['data'];

      if (nested is Map) {
        return _extractNumber(
          nested,
          keys,
        );
      }
    }

    if (response is List &&
        response.isNotEmpty) {
      return _extractNumber(
        response.first,
        keys,
      );
    }

    return null;
  }

  // ============================================================
  // EXTRACT STRING
  // ============================================================

  String? _extractString(
    dynamic response,
    List<String> keys,
  ) {
    if (response is Map) {
      for (final key in keys) {
        final value = response[key];

        if (value != null) {
          final text = value.toString().trim();

          if (text.isNotEmpty) {
            return text;
          }
        }
      }

      final nested = response['data'];

      if (nested is Map) {
        return _extractString(
          nested,
          keys,
        );
      }
    }

    if (response is List &&
        response.isNotEmpty) {
      return _extractString(
        response.first,
        keys,
      );
    }

    if (response is String) {
      final text = response.trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  // ============================================================
  // EXTRACT BOOL
  // ============================================================

  bool? _extractBool(
    dynamic response,
    List<String> keys,
  ) {
    if (response is Map) {
      for (final key in keys) {
        final value = response[key];

        if (value is bool) {
          return value;
        }

        if (value is num) {
          return value != 0;
        }

        if (value is String) {
          final normalized =
              value.toLowerCase().trim();

          if (normalized == 'true' ||
              normalized == '1' ||
              normalized == 'yes' ||
              normalized == 'success' ||
              normalized == 'verified' ||
              normalized == 'approved' ||
              normalized == 'confirmed') {
            return true;
          }

          if (normalized == 'false' ||
              normalized == '0' ||
              normalized == 'no' ||
              normalized == 'failed' ||
              normalized == 'rejected') {
            return false;
          }
        }
      }

      final nested = response['data'];

      if (nested is Map) {
        return _extractBool(
          nested,
          keys,
        );
      }
    }

    if (response is List &&
        response.isNotEmpty) {
      return _extractBool(
        response.first,
        keys,
      );
    }

    return null;
  }

  // ============================================================
  // MINING ACTIVE
  // ============================================================

  bool _isMiningActive(
    Map<String, dynamic> data,
  ) {
    final active = _extractBool(
      data,
      const [
        'active',
        'mining_active',
        'is_active',
      ],
    );

    if (active == true) {
      return true;
    }

    final status = _extractString(
      data,
      const [
        'status',
      ],
    );

    if (status != null) {
      final normalized =
          status.toLowerCase().trim();

      if (normalized == 'active' ||
          normalized == 'mining' ||
          normalized == 'running') {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // CLEAR STATE
  // ============================================================

  void _clearCurrentAdState() {
    _adsWatchedBeforeCurrentAd = 0;

    _rewardProcessing = false;

    _rewardGrantedForCurrentAd = false;

    _onRewarded = null;

    _onAdClosed = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _showing = false;
    _loading = false;
    _rewardProcessing = false;

    final initCompleter = _initCompleter;

    if (initCompleter != null &&
        !initCompleter.isCompleted) {
      initCompleter.complete();
    }

    _initCompleter = null;

    final loadCompleter = _loadCompleter;

    if (loadCompleter != null &&
        !loadCompleter.isCompleted) {
      loadCompleter.complete(false);
    }

    _loadCompleter = null;

    final ad = _rewardedAd;

    _rewardedAd = null;

    if (ad != null) {
      unawaited(
        ad.dispose(),
      );
    }

    _clearCurrentAdState();

    _lastAdLoadError = null;

    _initialized = false;
    _initializing = false;
  }
}
