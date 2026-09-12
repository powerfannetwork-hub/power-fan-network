import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../services/supabase_service.dart';

enum _RewardedAdMode {
  boost,
  activation,
}

class LevelPlayAdsService
    implements LevelPlayInitListener, LevelPlayRewardedAdListener {
  LevelPlayAdsService._();

  static final LevelPlayAdsService instance =
      LevelPlayAdsService._();

  static const String appKey = '27f58cf85';
  static const String rewardedAdUnitId = 'z69e4fg6emi98mbu';
  static const String placementName = 'Default';

  static const int maxAdsPerSession = 7;

  static const Duration _showTimeout =
      Duration(seconds: 90);

  static const Duration _initTimeout =
      Duration(seconds: 30);

  final SupabaseClient _supabase =
      SupabaseService.client;

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;

  Completer<bool>? _initCompleter;
  Completer<bool>? _showCompleter;

  _RewardedAdMode? _currentMode;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  bool _rewardGrantedForCurrentAd = false;
  bool _adClosed = false;
  bool _rewardProcessing = false;

  // ------------------------------------------------------------
  // INITIALIZE
  // ------------------------------------------------------------

  Future<bool> initialize() async {
    if (_disposed) {
      return false;
    }

    if (_initialized) {
      return true;
    }

    if (_initializing) {
      final existing = _initCompleter;

      if (existing != null) {
        try {
          return await existing.future.timeout(
            _initTimeout,
            onTimeout: () => false,
          );
        } catch (_) {
          return false;
        }
      }

      return false;
    }

    _initializing = true;
    _initCompleter = Completer<bool>();

    try {
      debugPrint(
        'LEVELPLAY: initializing SDK...',
      );

      final initRequest =
          LevelPlayInitRequest.builder(appKey)
              .build();

      await LevelPlay.init(
        initRequest: initRequest,
        initListener: this,
      );

      bool result;

      try {
        result = await _initCompleter!.future.timeout(
          _initTimeout,
          onTimeout: () {
            debugPrint(
              'LEVELPLAY: initialization timeout.',
            );

            return false;
          },
        );
      } catch (e) {
        debugPrint(
          'LEVELPLAY: initialization completer error: $e',
        );

        result = false;
      }

      return result;
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY INIT ERROR: $e',
      );
      debugPrint('$st');

      _initialized = false;

      if (_initCompleter != null &&
          !_initCompleter!.isCompleted) {
        _initCompleter!.complete(false);
      }

      return false;
    } finally {
      _initializing = false;
    }
  }

  // ------------------------------------------------------------
  // LEVELPLAY INIT LISTENER
  // ------------------------------------------------------------

  @override
  void onInitSuccess(
    LevelPlayConfiguration configuration,
  ) {
    if (_disposed) {
      return;
    }

    debugPrint(
      'LEVELPLAY: SDK initialized successfully.',
    );

    _initialized = true;

    if (_initCompleter != null &&
        !_initCompleter!.isCompleted) {
      _initCompleter!.complete(true);
    }

    _createRewardedAd();
  }

  @override
  void onInitFailed(
    LevelPlayInitError error,
  ) {
    debugPrint(
      'LEVELPLAY INIT FAILED: '
      '${error.errorCode} - ${error.errorMessage}',
    );

    _initialized = false;

    if (_initCompleter != null &&
        !_initCompleter!.isCompleted) {
      _initCompleter!.complete(false);
    }
  }

  // ------------------------------------------------------------
  // CREATE REWARDED AD
  // ------------------------------------------------------------

  void _createRewardedAd() {
    if (_disposed) {
      return;
    }

    if (_rewardedAd != null) {
      return;
    }

    try {
      final ad =
          LevelPlayRewardedAd(
        adUnitId: rewardedAdUnitId,
      );

      ad.setListener(this);

      _rewardedAd = ad;

      debugPrint(
        'LEVELPLAY: rewarded ad created.',
      );

      unawaited(
        _loadRewardedAdInternal(),
      );
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY REWARDED CREATE ERROR: $e',
      );
      debugPrint('$st');
    }
  }

  // ------------------------------------------------------------
  // LOAD REWARDED AD
  // ------------------------------------------------------------

  Future<void> _loadRewardedAdInternal() async {
    if (_disposed) {
      return;
    }

    final ad = _rewardedAd;

    if (ad == null) {
      return;
    }

    try {
      debugPrint(
        'LEVELPLAY: loading rewarded ad...',
      );

      await ad.loadAd();
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY LOAD ERROR: $e',
      );
      debugPrint('$st');
    }
  }

  /// Public method kept for BoostAdsCard/HomeScreen.
  Future<void> loadRewardedAd() async {
    if (_disposed) {
      return;
    }

    if (!_initialized) {
      final initialized = await initialize();

      if (!initialized) {
        return;
      }
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    await _loadRewardedAdInternal();
  }

  // ------------------------------------------------------------
  // CHECK READY
  // ------------------------------------------------------------

  /// Public method kept as a method because BoostAdsCard calls:
  ///
  /// await _ads.isRewardedAdReady();
  Future<bool> isRewardedAdReady() async {
    if (_disposed) {
      return false;
    }

    if (!_initialized) {
      return false;
    }

    final ad = _rewardedAd;

    if (ad == null) {
      return false;
    }

    try {
      return await ad.isAdReady();
    } catch (e) {
      debugPrint(
        'LEVELPLAY READY CHECK ERROR: $e',
      );

      return false;
    }
  }

  // ------------------------------------------------------------
  // BOOST AD
  // ------------------------------------------------------------

  Future<bool> showRewardedAd({
    VoidCallback? onRewarded,
    VoidCallback? onAdClosed,
  }) async {
    return _showRewardedAd(
      mode: _RewardedAdMode.boost,
      onRewarded: onRewarded,
      onAdClosed: onAdClosed,
    );
  }

  // ------------------------------------------------------------
  // ACTIVATION AD
  // ------------------------------------------------------------

  Future<bool> showActivationAd({
    VoidCallback? onRewarded,
    VoidCallback? onAdClosed,
  }) async {
    return _showRewardedAd(
      mode: _RewardedAdMode.activation,
      onRewarded: onRewarded,
      onAdClosed: onAdClosed,
    );
  }

  // ------------------------------------------------------------
  // SHOW REWARDED AD
  // ------------------------------------------------------------

  Future<bool> _showRewardedAd({
    required _RewardedAdMode mode,
    VoidCallback? onRewarded,
    VoidCallback? onAdClosed,
  }) async {
    if (_disposed) {
      return false;
    }

    final initialized = await initialize();

    if (!initialized) {
      debugPrint(
        'LEVELPLAY: cannot show ad. SDK not initialized.',
      );

      return false;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'LEVELPLAY: user is not authenticated.',
      );

      return false;
    }

    // ----------------------------------------------------------
    // BOOST AD VALIDATION
    // ----------------------------------------------------------

    if (mode == _RewardedAdMode.boost) {
      final mining = await _getActiveMining();

      if (mining == null) {
        debugPrint(
          'LEVELPLAY: Boost Ad blocked. '
          'No active mining session.',
        );

        return false;
      }

      if (!_isMiningActive(mining)) {
        debugPrint(
          'LEVELPLAY: Boost Ad blocked. '
          'Mining is not active.',
        );

        return false;
      }

      final adsWatched = _readInt(
        mining,
        const [
          'ads_watched',
          'ad_count',
          'ads_count',
          'daily_ads_watched',
        ],
      );

      if (adsWatched >= maxAdsPerSession) {
        debugPrint(
          'LEVELPLAY: Boost Ad limit reached: '
          '$adsWatched/$maxAdsPerSession',
        );

        return false;
      }
    }

    // ----------------------------------------------------------
    // ACTIVATION AD
    // ----------------------------------------------------------

    if (mode == _RewardedAdMode.activation) {
      debugPrint(
        'LEVELPLAY: Activation Ad requested.',
      );

      // IMPORTANT:
      // We intentionally DO NOT require an active mining session.
      //
      // Activation Ad is what authorizes starting a new session.
    }

    if (_showCompleter != null &&
        !_showCompleter!.isCompleted) {
      debugPrint(
        'LEVELPLAY: another rewarded ad is already showing.',
      );

      return false;
    }

    final ad = _rewardedAd;

    if (ad == null) {
      debugPrint(
        'LEVELPLAY: rewarded ad object is not available.',
      );

      _createRewardedAd();

      return false;
    }

    bool ready = false;

    try {
      ready = await ad.isAdReady();
    } catch (e) {
      debugPrint(
        'LEVELPLAY ready check before show failed: $e',
      );
    }

    if (!ready) {
      debugPrint(
        'LEVELPLAY: rewarded ad is not ready.',
      );

      unawaited(
        _loadRewardedAdInternal(),
      );

      return false;
    }

    // ----------------------------------------------------------
    // PREPARE STATE
    // ----------------------------------------------------------

    _currentMode = mode;

    _rewardGrantedForCurrentAd = false;
    _adClosed = false;
    _rewardProcessing = false;

    _onRewarded = onRewarded;
    _onAdClosed = onAdClosed;

    _showCompleter = Completer<bool>();

    try {
      debugPrint(
        'LEVELPLAY: showing '
        '${mode == _RewardedAdMode.activation ? 'Activation' : 'Boost'} Ad.',
      );

      await ad.showAd(
        placementName: placementName,
      );

      final completer = _showCompleter;

      if (completer == null) {
        return false;
      }

      final result =
          await completer.future.timeout(
        _showTimeout,
        onTimeout: () {
          debugPrint(
            'LEVELPLAY: show timeout.',
          );

          _clearAdState();

          return false;
        },
      );

      return result;
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY SHOW ERROR: $e',
      );
      debugPrint('$st');

      _clearAdState();

      return false;
    }
  }

  // ------------------------------------------------------------
  // REWARDED CALLBACK
  // ------------------------------------------------------------

  @override
  void onAdRewarded(
    LevelPlayReward reward,
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: reward received. '
      'reward=${reward.amount}',
    );

    if (_disposed) {
      return;
    }

    if (_currentMode == null) {
      debugPrint(
        'LEVELPLAY: reward received without active mode.',
      );

      return;
    }

    if (_rewardGrantedForCurrentAd) {
      debugPrint(
        'LEVELPLAY: duplicate reward callback ignored.',
      );

      return;
    }

    _rewardGrantedForCurrentAd = true;

    unawaited(
      _processReward(),
    );
  }

  // ------------------------------------------------------------
  // PROCESS REWARD
  // ------------------------------------------------------------

  Future<void> _processReward() async {
    if (_disposed) {
      return;
    }

    if (_rewardProcessing) {
      return;
    }

    _rewardProcessing = true;

    try {
      final mode = _currentMode;

      if (mode == null) {
        return;
      }

      // --------------------------------------------------------
      // ACTIVATION AD
      // --------------------------------------------------------

      if (mode == _RewardedAdMode.activation) {
        debugPrint(
          'LEVELPLAY: Activation Ad completed.',
        );

        debugPrint(
          'LEVELPLAY: Activation Ad does NOT record a Boost reward.',
        );

        debugPrint(
          'LEVELPLAY: Activation Ad does NOT increase mining rate.',
        );

        final callback = _onRewarded;

        if (callback != null) {
          try {
            callback();
          } catch (e) {
            debugPrint(
              'LEVELPLAY activation callback error: $e',
            );
          }
        }

        return;
      }

      // --------------------------------------------------------
      // BOOST AD
      // --------------------------------------------------------

      await _processBoostReward();
    } finally {
      _rewardProcessing = false;

      _tryFinishCurrentAd();
    }
  }

  // ------------------------------------------------------------
  // BOOST SERVER REWARD
  // ------------------------------------------------------------

  Future<void> _processBoostReward() async {
    if (_disposed) {
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'LEVELPLAY: cannot record Boost Ad. '
        'User is not authenticated.',
      );

      return;
    }

    try {
      debugPrint(
        'LEVELPLAY: recording Boost Ad on server...',
      );

      final recordResponse =
          await _supabase.rpc(
        'record_rewarded_ad',
        params: {
          'p_ad_reference':
              'levelplay_${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      debugPrint(
        'LEVELPLAY record_rewarded_ad response: '
        '$recordResponse',
      );

      if (_responseIsFailure(recordResponse)) {
        debugPrint(
          'LEVELPLAY: server rejected Boost Ad.',
        );

        return;
      }

      final adId =
          _extractAdId(recordResponse);

      if (adId == null) {
        debugPrint(
          'LEVELPLAY: server did not return ad_id. '
          'Boost verification skipped.',
        );

        return;
      }

      // --------------------------------------------------------
      // VERIFY
      // --------------------------------------------------------

      debugPrint(
        'LEVELPLAY: verifying Boost Ad...',
      );

      final verifyResponse =
          await _supabase.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': adId,
        },
      );

      debugPrint(
        'LEVELPLAY verify_rewarded_ad response: '
        '$verifyResponse',
      );

      if (_responseIsFailure(verifyResponse)) {
        debugPrint(
          'LEVELPLAY: Boost verification failed.',
        );

        return;
      }

      final callback = _onRewarded;

      if (callback != null) {
        try {
          callback();
        } catch (e) {
          debugPrint(
            'LEVELPLAY Boost callback error: $e',
          );
        }
      }
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY BOOST SERVER ERROR: $e',
      );
      debugPrint('$st');
    }
  }

  // ------------------------------------------------------------
  // RESPONSE FAILURE
  // ------------------------------------------------------------

  bool _responseIsFailure(dynamic response) {
    if (response is Map) {
      final success = response['success'];

      if (success is bool) {
        return !success;
      }

      final status = response['status']
          ?.toString()
          .toLowerCase();

      if (status == 'error' ||
          status == 'failed' ||
          status == 'failure') {
        return true;
      }
    }

    return false;
  }

  // ------------------------------------------------------------
  // ACTIVE MINING
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> _getActiveMining() async {
    try {
      final response =
          await _supabase.rpc(
        'get_active_mining',
      );

      if (response == null) {
        return null;
      }

      if (response is Map<String, dynamic>) {
        return response;
      }

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
      }

      if (response is List &&
          response.isNotEmpty) {
        final first = response.first;

        if (first is Map<String, dynamic>) {
          return first;
        }

        if (first is Map) {
          return Map<String, dynamic>.from(
            first,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint(
        'LEVELPLAY get_active_mining ERROR: $e',
      );

      return null;
    }
  }

  // ------------------------------------------------------------
  // MINING ACTIVE CHECK
  // ------------------------------------------------------------

  bool _isMiningActive(
    Map<String, dynamic> mining,
  ) {
    final now =
        DateTime.now().toUtc();

    final startedAt =
        _readDateTime(
      mining,
      const [
        'started_at',
        'start_time',
        'started',
        'mining_started_at',
      ],
    );

    final endsAt =
        _readDateTime(
      mining,
      const [
        'ends_at',
        'end_time',
        'expires_at',
        'ended_at',
        'mining_ends_at',
      ],
    );

    if (startedAt != null &&
        endsAt != null) {
      return startedAt.isBefore(now) &&
          endsAt.isAfter(now);
    }

    final status =
        mining['status']
            ?.toString()
            .toLowerCase()
            .trim();

    if (status == 'active') {
      return true;
    }

    final active =
        mining['active'];

    if (active is bool) {
      return active;
    }

    final miningActive =
        mining['mining_active'];

    if (miningActive is bool) {
      return miningActive;
    }

    return false;
  }

  // ------------------------------------------------------------
  // EXTRACT AD ID
  // ------------------------------------------------------------

  dynamic _extractAdId(
    dynamic response,
  ) {
    if (response is Map) {
      final direct =
          response['ad_id'] ??
          response['id'];

      if (direct != null) {
        return direct;
      }

      final data =
          response['data'];

      if (data is Map) {
        return data['ad_id'] ??
            data['id'];
      }
    }

    return null;
  }

  // ------------------------------------------------------------
  // READ INT
  // ------------------------------------------------------------

  int _readInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      if (value != null) {
        final parsed =
            int.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  // ------------------------------------------------------------
  // READ DATETIME
  // ------------------------------------------------------------

  DateTime? _readDateTime(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is DateTime) {
        return value.toUtc();
      }

      if (value != null) {
        final parsed =
            DateTime.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed.toUtc();
        }
      }
    }

    return null;
  }

  // ------------------------------------------------------------
  // TRY FINISH
  // ------------------------------------------------------------

  void _tryFinishCurrentAd() {
    if (_disposed) {
      return;
    }

    final completer =
        _showCompleter;

    if (completer == null ||
        completer.isCompleted) {
      return;
    }

    /*
     * We finish only after:
     *
     * 1. LevelPlay has closed the ad
     * 2. Reward callback has been processed
     *
     * This prevents Boost server verification from being
     * cancelled/cleared before record_rewarded_ad finishes.
     */
    if (!_adClosed) {
      return;
    }

    if (!_rewardGrantedForCurrentAd) {
      completer.complete(false);
      _resetAfterAd();

      return;
    }

    if (_rewardProcessing) {
      return;
    }

    completer.complete(true);

    _resetAfterAd();
  }

  // ------------------------------------------------------------
  // AD CLOSED
  // ------------------------------------------------------------

  @override
  void onAdClosed(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad closed.',
    );

    _adClosed = true;

    final callback =
        _onAdClosed;

    if (callback != null) {
      try {
        callback();
      } catch (e) {
        debugPrint(
          'LEVELPLAY onAdClosed callback error: $e',
        );
      }
    }

    _tryFinishCurrentAd();
  }

  // ------------------------------------------------------------
  // AD LOADED
  // ------------------------------------------------------------

  @override
  void onAdLoaded(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad loaded.',
    );
  }

  // ------------------------------------------------------------
  // AD LOAD FAILED
  // ------------------------------------------------------------

  @override
  void onAdLoadFailed(
    LevelPlayAdError error,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad load failed: '
      '${error.errorCode} - ${error.errorMessage}',
    );
  }

  // ------------------------------------------------------------
  // AD DISPLAYED
  // ------------------------------------------------------------

  @override
  void onAdDisplayed(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad displayed.',
    );
  }

  // ------------------------------------------------------------
  // AD DISPLAY FAILED
  // ------------------------------------------------------------

  @override
  void onAdDisplayFailed(
    LevelPlayAdError error,
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad display failed: '
      '${error.errorCode} - ${error.errorMessage}',
    );

    final completer =
        _showCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete(false);
    }

    _resetAfterAd();

    unawaited(
      _loadRewardedAdInternal(),
    );
  }

  // ------------------------------------------------------------
  // AD CLICKED
  // ------------------------------------------------------------

  @override
  void onAdClicked(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad clicked.',
    );
  }

  // ------------------------------------------------------------
  // AD INFO CHANGED
  // ------------------------------------------------------------

  @override
  void onAdInfoChanged(
    LevelPlayAdInfo adInfo,
  ) {
    debugPrint(
      'LEVELPLAY: rewarded ad info changed.',
    );
  }

  // ------------------------------------------------------------
  // PRELOAD
  // ------------------------------------------------------------

  Future<void> preloadRewardedAd() async {
    if (_disposed) {
      return;
    }

    final initialized =
        await initialize();

    if (!initialized) {
      return;
    }

    final ready =
        await isRewardedAdReady();

    if (!ready) {
      await loadRewardedAd();
    }
  }

  // ------------------------------------------------------------
  // REFRESH
  // ------------------------------------------------------------

  Future<void> refreshRewardedAd() async {
    if (_disposed) {
      return;
    }

    final initialized =
        await initialize();

    if (!initialized) {
      return;
    }

    await loadRewardedAd();
  }

  // ------------------------------------------------------------
  // APP RESUMED
  // ------------------------------------------------------------

  void onAppResumed() {
    if (_disposed) {
      return;
    }

    debugPrint(
      'LEVELPLAY: app resumed.',
    );

    unawaited(
      preloadRewardedAd(),
    );
  }

  // ------------------------------------------------------------
  // APP PAUSED
  // ------------------------------------------------------------

  void onAppPaused() {
    if (_disposed) {
      return;
    }

    debugPrint(
      'LEVELPLAY: app paused.',
    );
  }

  // ------------------------------------------------------------
  // RESET AFTER AD
  // ------------------------------------------------------------

  void _resetAfterAd() {
    _showCompleter = null;

    _currentMode = null;

    _rewardGrantedForCurrentAd = false;
    _adClosed = false;
    _rewardProcessing = false;

    _onRewarded = null;
    _onAdClosed = null;

    /*
     * Load next rewarded ad after the current ad has finished.
     */
    Future<void>.delayed(
      const Duration(milliseconds: 500),
      () {
        if (!_disposed) {
          unawaited(
            _loadRewardedAdInternal(),
          );
        }
      },
    );
  }

  // ------------------------------------------------------------
  // CLEAR STATE
  // ------------------------------------------------------------

  void _clearAdState() {
    final completer =
        _showCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete(false);
    }

    _showCompleter = null;

    _currentMode = null;

    _rewardGrantedForCurrentAd = false;
    _adClosed = false;
    _rewardProcessing = false;

    _onRewarded = null;
    _onAdClosed = null;
  }

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _clearAdState();

    final ad =
        _rewardedAd;

    _rewardedAd = null;

    if (ad != null) {
      unawaited(
        ad.dispose().catchError(
          (Object error) {
            debugPrint(
              'LEVELPLAY rewarded dispose error: $error',
            );
          },
        ),
      );
    }

    _initialized = false;
    _initializing = false;
  }
}

Wannan ya yi daidai da API ɗin "unity_levelplay_mediation" na yanzu: "LevelPlay.init(initRequest: ..., initListener: ...)", "LevelPlayRewardedAd.setListener(this)", "loadAd()", "isAdReady()", da "showAd(placementName: ...)".

"boost_ads_card.dart" ɗinka kuma kada ka canza shi yanzu. Sabon service ɗin da ke sama ya samar da waɗannan methods ɗin da card ɗin naka yake kira:

- "initialize()"
- "isRewardedAdReady()"
- "loadRewardedAd()"
- "showRewardedAd()"
- "showActivationAd()"

Saboda haka errors ɗin "loadRewardedAd isn't defined" da "expression doesn't evaluate to a function" ya kamata su tafi.

Bayan ka paste

Run:

flutter analyze

Kada ka canza wani file tukuna. Idan analyzer ya ba da errors, turo min sabbin errors ɗin kawai. Sai mu gyara abin da ya rage bisa ainihin package ɗinka, ba guess ba.
