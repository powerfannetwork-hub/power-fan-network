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

  static const Duration initTimeout =
      Duration(seconds: 20);

  static const Duration adLoadTimeout =
      Duration(seconds: 20);

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
  String? _lastInitError;

  // ============================================================
  // PUBLIC DIAGNOSTIC INFORMATION
  // ============================================================

  String? get lastAdLoadError => _lastAdLoadError;

  String? get lastInitError => _lastInitError;

  bool get isInitialized => _initialized;

  bool get isLoading => _loading;

  bool get isShowing => _showing;

  String get diagnosticMessage {
    if (!_initialized) {
      if (_lastInitError != null) {
        return 'LevelPlay SDK is not initialized.\n'
            'Error: $_lastInitError';
      }

      return 'LevelPlay SDK is not initialized.';
    }

    if (_lastAdLoadError != null) {
      return 'Rewarded ad failed to load.\n'
          'Error: $_lastAdLoadError';
    }

    if (_rewardedAd == null) {
      return 'Rewarded ad object was not created.';
    }

    if (_loading) {
      return 'Rewarded ad is currently loading.';
    }

    return 'LevelPlay initialized, but no rewarded ad is ready.';
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint(
        'LevelPlay: already initialized.',
      );

      return;
    }

    if (_initializing) {
      debugPrint(
        'LevelPlay: initialization already in progress.',
      );

      final completer = _initCompleter;

      if (completer != null) {
        try {
          await completer.future.timeout(
            initTimeout,
          );
        } catch (_) {
          debugPrint(
            'LevelPlay: waiting for existing initialization timed out.',
          );
        }
      }

      return;
    }

    final user = SupabaseService.client.auth.currentUser;

    final userId = user?.id;

    if (userId == null || userId.isEmpty) {
      _lastInitError =
          'User is not authenticated.';

      debugPrint(
        'LevelPlay: $_lastInitError',
      );

      return;
    }

    _initializing = true;

    _lastInitError = null;

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
        'LEVELPLAY DIAGNOSTIC START',
      );

      debugPrint(
        'LevelPlay: INITIALIZING',
      );

      debugPrint(
        'LevelPlay: Android App Key = $appKeyAndroid',
      );

      debugPrint(
        'LevelPlay: Rewarded Ad Unit = $rewardedAdUnitId',
      );

      debugPrint(
        'LevelPlay: Placement = $rewardedPlacementName',
      );

      debugPrint(
        'LevelPlay: User ID = $userId',
      );

      debugPrint(
        '================================================',
      );

      await LevelPlay.init(
        initRequest: initRequest,
        initListener: this,
      );

      try {
        await completer.future.timeout(
          initTimeout,
        );
      } catch (_) {
        debugPrint(
          'LevelPlay: initialization callback timeout.',
        );
      }
    } catch (e, stackTrace) {
      _initialized = false;

      _lastInitError = e.toString();

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: INITIALIZATION EXCEPTION',
      );

      debugPrint(
        'ERROR: $_lastInitError',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        '================================================',
      );

      if (!completer.isCompleted) {
        completer.complete();
      }
    } finally {
      _initializing = false;

      if (identical(
        _initCompleter,
        completer,
      )) {
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
        debugPrint(
          'LevelPlay: READY CHECK FAILED - SDK not initialized.',
        );

        return false;
      }

      if (_rewardedAd == null) {
        _createRewardedAd();
      }

      final ad = _rewardedAd;

      if (ad == null) {
        debugPrint(
          'LevelPlay: READY CHECK FAILED - ad object is null.',
        );

        return false;
      }

      final ready = await ad.isAdReady();

      debugPrint(
        'LevelPlay: isRewardedAdReady = $ready',
      );

      return ready;
    } catch (e, stackTrace) {
      _lastAdLoadError = e.toString();

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LevelPlay: READY CHECK ERROR',
      );

      debugPrint(
        'ERROR: $_lastAdLoadError',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        '================================================',
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
        'LevelPlay: cannot load rewarded ad.',
      );

      debugPrint(
        'LevelPlay diagnostic: $diagnosticMessage',
      );

      return;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    final ad = _rewardedAd;

    if (ad == null) {
      _lastAdLoadError =
          'Rewarded ad object is null.';

      debugPrint(
        'LevelPlay: $_lastAdLoadError',
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

      debugPrint(
        'LevelPlay: LOAD CHECK - already ready = $ready',
      );

      if (ready) {
        debugPrint(
          'LevelPlay: rewarded ad already READY.',
        );

        return;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: initial ready check exception: $e',
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
        'LEVELPLAY REWARDED AD LOAD START',
      );

      debugPrint(
        'Ad Unit ID: $rewardedAdUnitId',
      );

      debugPrint(
        'Placement: $rewardedPlacementName',
      );

      debugPrint(
        '================================================',
      );

      await ad.loadAd();

      debugPrint(
        'LevelPlay: loadAd() REQUEST SENT.',
      );

      bool loaded = false;

      try {
        loaded = await completer.future.timeout(
          adLoadTimeout,
          onTimeout: () {
            debugPrint(
              'LevelPlay: LOAD TIMEOUT after '
              '${adLoadTimeout.inSeconds} seconds.',
            );

            return false;
          },
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: load completer exception: $e',
        );
      }

      if (loaded) {
        debugPrint(
          '================================================',
        );

        debugPrint(
          'LEVELPLAY RESULT: REWARDED AD LOADED',
        );

        debugPrint(
          'The ad should now be ready.',
        );

        debugPrint(
          '================================================',
        );
      } else {
        final error =
            _lastAdLoadError ??
                'No LevelPlay load error was returned.';

        debugPrint(
          '================================================',
        );

        debugPrint(
          'LEVELPLAY RESULT: REWARDED AD DID NOT LOAD',
        );

        debugPrint(
          'LOAD ERROR: $error',
        );

        debugPrint(
          '================================================',
        );
      }
    } catch (e, stackTrace) {
      _lastAdLoadError = e.toString();

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LEVELPLAY loadAd() EXCEPTION',
      );

      debugPrint(
        'ERROR: $_lastAdLoadError',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        '================================================',
      );

      if (!completer.isCompleted) {
        completer.complete(false);
      }
    } finally {
      _loading = false;

      if (identical(
        _loadCompleter,
        completer,
      )) {
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
      _lastAdLoadError =
          'Rewarded ad object is null.';

      return false;
    }

    // ----------------------------------------------------------
    // CURRENT READY CHECK
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
        'LevelPlay: current ready check error: $e',
      );
    }

    // ----------------------------------------------------------
    // LOAD
    // ----------------------------------------------------------

    await loadRewardedAd();

    // ----------------------------------------------------------
    // POLL
    // ----------------------------------------------------------

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < adLoadTimeout) {
      try {
        final ready = await ad.isAdReady();

        debugPrint(
          'LevelPlay: READY POLL = $ready',
        );

        if (ready) {
          debugPrint(
            '================================================',
          );

          debugPrint(
            'LEVELPLAY: REWARDED AD IS READY',
          );

          debugPrint(
            '================================================',
          );

          return true;
        }
      } catch (e) {
        debugPrint(
          'LevelPlay: readiness polling error: $e',
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
      'LEVELPLAY: NO READY REWARDED AD',
    );

    debugPrint(
      'DIAGNOSTIC: $diagnosticMessage',
    );

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

        throw Exception(
          'LevelPlay initialization failed: '
          '${_lastInitError ?? 'unknown error'}',
        );
      }

      // --------------------------------------------------------
      // AUTH
      // --------------------------------------------------------

      final user =
          SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        throw Exception(
          'User is not authenticated.',
        );
      }

      // --------------------------------------------------------
      // GET ACTIVE MINING
      // --------------------------------------------------------

      final mining =
          await MiningService.instance.getActiveMining();

      if (mining.isEmpty) {
        throw Exception(
          'No active mining session was found.',
        );
      }

      final active =
          _isMiningActive(mining);

      if (!active) {
        throw Exception(
          'Mining session is not active.',
        );
      }

      final adsWatched =
          _extractAdsWatched(mining);

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LEVELPLAY WATCH AD REQUEST',
      );

      debugPrint(
        'Active mining: $active',
      );

      debugPrint(
        'Ads watched: $adsWatched',
      );

      debugPrint(
        'Maximum ads: $maxAdsPerSession',
      );

      debugPrint(
        '================================================',
      );

      // --------------------------------------------------------
      // MAX ADS
      // --------------------------------------------------------

      if (adsWatched >= maxAdsPerSession) {
        throw Exception(
          'You have reached the 7 ads limit '
          'for this mining session.',
        );
      }

      // --------------------------------------------------------
      // ENSURE REAL AD
      // --------------------------------------------------------

      final ready =
          await _ensureRewardedAdReady();

      if (!ready) {
        final diagnostic =
            diagnosticMessage;

        debugPrint(
          '================================================',
        );

        debugPrint(
          'LEVELPLAY SHOW BLOCKED',
        );

        debugPrint(
          diagnostic,
        );

        debugPrint(
          '================================================',
        );

        throw Exception(
          diagnostic,
        );
      }

      // --------------------------------------------------------
      // SAVE CALLBACK STATE
      // --------------------------------------------------------

      _adsWatchedBeforeCurrentAd =
          adsWatched;

      _rewardProcessing = false;

      _rewardGrantedForCurrentAd = false;

      _onRewarded = onRewarded;

      _onAdClosed = onAdClosed;

      // --------------------------------------------------------
      // DYNAMIC USER ID
      // --------------------------------------------------------

      try {
        await LevelPlay.setDynamicUserId(
          userId,
        );

        debugPrint(
          'LevelPlay: dynamic user ID set successfully.',
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: dynamic user ID failed: $e',
        );
      }

      // --------------------------------------------------------
      // FINAL READY CHECK
      // --------------------------------------------------------

      final ad = _rewardedAd;

      if (ad == null) {
        throw Exception(
          'Rewarded ad object became null before show.',
        );
      }

      final finalReady =
          await ad.isAdReady();

      debugPrint(
        'LevelPlay: FINAL READY CHECK = $finalReady',
      );

      if (!finalReady) {
        unawaited(
          loadRewardedAd(),
        );

        throw Exception(
          'Rewarded ad became unavailable '
          'immediately before showing.\n'
          '${diagnosticMessage}',
        );
      }

      // --------------------------------------------------------
      // SHOW
      // --------------------------------------------------------

      _showing = true;

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LEVELPLAY: SHOWING REWARDED AD',
      );

      debugPrint(
        'Ad Unit: $rewardedAdUnitId',
      );

      debugPrint(
        'Placement: $rewardedPlacementName',
      );

      debugPrint(
        'Previous ads: $_adsWatchedBeforeCurrentAd',
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
        '================================================',
      );

      debugPrint(
        'LEVELPLAY SHOW ERROR',
      );

      debugPrint(
        'ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        'LAST LOAD ERROR: '
        '${_lastAdLoadError ?? 'none'}',
      );

      debugPrint(
        'LAST INIT ERROR: '
        '${_lastInitError ?? 'none'}',
      );

      debugPrint(
        '================================================',
      );

      _showing = false;
      _rewardProcessing = false;

      _clearCurrentAdState();

      unawaited(
        loadRewardedAd(),
      );

      rethrow;
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
        'LEVELPLAY: REWARDED AD OBJECT CREATED',
      );

      debugPrint(
        'Ad Unit ID: $rewardedAdUnitId',
      );

      debugPrint(
        '================================================',
      );
    } catch (e, stackTrace) {
      _lastAdLoadError = e.toString();

      debugPrint(
        '================================================',
      );

      debugPrint(
        'LEVELPLAY: FAILED TO CREATE REWARDED AD',
      );

      debugPrint(
        'ERROR: $_lastAdLoadError',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        '================================================',
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
      'LEVELPLAY: INIT SUCCESS',
    );

    debugPrint(
      'Configuration: $configuration',
    );

    debugPrint(
      '================================================',
    );

    _initialized = true;
    _lastInitError = null;

    _createRewardedAd();

    final completer =
        _initCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete();
    }

    // Start loading the first rewarded ad.
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
    _initialized = false;
    _loading = false;

    _lastInitError =
        error.toString();

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LEVELPLAY: INIT FAILED',
    );

    debugPrint(
      'INIT ERROR: $_lastInitError',
    );

    debugPrint(
      '================================================',
    );

    final completer =
        _initCompleter;

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
      'LEVELPLAY: REWARDED AD LOADED SUCCESSFULLY',
    );

    debugPrint(
      'AD INFO: $adInfo',
    );

    debugPrint(
      '================================================',
    );

    final completer =
        _loadCompleter;

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

    _lastAdLoadError =
        error.toString();

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LEVELPLAY: REWARDED AD LOAD FAILED',
    );

    debugPrint(
      'FULL LOAD ERROR:',
    );

    debugPrint(
      '$error',
    );

    debugPrint(
      '================================================',
    );

    final completer =
        _loadCompleter;

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
      'Ad Info: $adInfo',
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
      'LEVELPLAY: AD DISPLAY FAILED',
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

    final callback =
        _onAdClosed;

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
      'LEVELPLAY: REWARDED CALLBACK RECEIVED',
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

      final success =
          _extractBool(
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

      final adId =
          _extractString(
        response,
        const [
          'ad_id',
          'adId',
          'id',
        ],
      );

      if (adId == null ||
          adId.isEmpty) {
        debugPrint(
          'LevelPlay: record_rewarded_ad returned no ad_id.',
        );

        _rewardProcessing = false;

        return;
      }

      // --------------------------------------------------------
      // VERIFY
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

      final verified =
          _extractBool(
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
        'LEVELPLAY: REWARD VERIFIED SUCCESSFULLY',
      );

      debugPrint(
        'Ad ID: $adId',
      );

      debugPrint(
        'Ads watched: $adsWatched',
      );

      debugPrint(
        'New mining rate: $newRate',
      );

      debugPrint(
        '================================================',
      );

      _rewardGrantedForCurrentAd = true;

      final callback =
          _onRewarded;

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
        'LEVELPLAY: REWARD PROCESSING ERROR',
      );

      debugPrint(
        'ERROR: $e',
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

    final callback =
        _onAdClosed;

    callback?.call();

    if (!_rewardProcessing) {
      _clearCurrentAdState();
    }

    // Prepare next rewarded ad.
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
          final parsed =
              double.tryParse(value);

          if (parsed != null) {
            return parsed;
          }
        }
      }

      final nested =
          response['data'];

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
          final text =
              value.toString().trim();

          if (text.isNotEmpty) {
            return text;
          }
        }
      }

      final nested =
          response['data'];

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
      final text =
          response.trim();

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

      final nested =
          response['data'];

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
    final active =
        _extractBool(
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

    final status =
        _extractString(
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

    final initCompleter =
        _initCompleter;

    if (initCompleter != null &&
        !initCompleter.isCompleted) {
      initCompleter.complete();
    }

    _initCompleter = null;

    final loadCompleter =
        _loadCompleter;

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
    _lastInitError = null;

    _initialized = false;
    _initializing = false;
  }
}
