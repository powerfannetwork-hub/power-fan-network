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

  // ------------------------------------------------------------
  // GENERAL TIMEOUTS
  // ------------------------------------------------------------

  // Boost Ads MUST find a real rewarded ad.
  // No bypass is allowed for Boost Ads.
  static const Duration _boostAdReadyTimeout =
      Duration(seconds: 30);

  // Activation Ad is optional.
  // We give LevelPlay about 12 seconds to find an ad.
  // If no ad is available after that, showActivationAd()
  // returns false so HomeScreen can continue with mining.
  static const Duration _activationAdReadyTimeout =
      Duration(seconds: 12);

  static const Duration _initTimeout =
      Duration(seconds: 30);

  static const Duration _adReadyPollInterval =
      Duration(milliseconds: 500);

  static const Duration _loadRetryDelay =
      Duration(seconds: 5);

  static const Duration _showTimeout =
      Duration(seconds: 90);

  // Some LevelPlay versions can send onAdClosed before
  // onAdRewarded. Keep the state alive briefly so a late
  // reward callback can still be accepted.
  static const Duration _rewardCallbackGracePeriod =
      Duration(seconds: 8);

  final SupabaseClient _supabase =
      SupabaseService.client;

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;

  bool _loadingAd = false;

  Timer? _retryTimer;
  Timer? _rewardGraceTimer;

  Completer<bool>? _initCompleter;
  Completer<bool>? _showCompleter;

  _RewardedAdMode? _currentMode;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  bool _rewardGrantedForCurrentAd = false;
  bool _adClosed = false;
  bool _rewardProcessing = false;

  // LevelPlay reward was received and our server/client
  // processing was successful.
  bool _rewardProcessingSucceeded = false;

  // Used only to generate a unique reference without
  // depending on the phone's DateTime.
  int _adReferenceCounter = 0;

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
          LevelPlayInitRequest
              .builder(appKey)
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
      final ad = LevelPlayRewardedAd(
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

    if (!_initialized) {
      return;
    }

    final ad = _rewardedAd;

    if (ad == null) {
      return;
    }

    if (_loadingAd) {
      debugPrint(
        'LEVELPLAY: rewarded ad load already in progress.',
      );

      return;
    }

    _loadingAd = true;

    _retryTimer?.cancel();
    _retryTimer = null;

    try {
      final ready =
          await ad.isAdReady();

      if (ready) {
        debugPrint(
          'LEVELPLAY: rewarded ad is already ready.',
        );

        return;
      }
    } catch (e) {
      debugPrint(
        'LEVELPLAY: ready check before load failed: $e',
      );
    }

    try {
      debugPrint(
        'LEVELPLAY: loading rewarded ad...',
      );

      await ad.loadAd();

      debugPrint(
        'LEVELPLAY: rewarded ad load request sent.',
      );
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY LOAD ERROR: $e',
      );

      debugPrint('$st');

      _scheduleLoadRetry();
    } finally {
      _loadingAd = false;
    }
  }

  // ------------------------------------------------------------
  // LOAD RETRY
  // ------------------------------------------------------------

  void _scheduleLoadRetry() {
    if (_disposed) {
      return;
    }

    if (!_initialized) {
      return;
    }

    if (_rewardedAd == null) {
      return;
    }

    if (_retryTimer != null &&
        _retryTimer!.isActive) {
      return;
    }

    debugPrint(
      'LEVELPLAY: scheduling rewarded ad retry '
      'in ${_loadRetryDelay.inSeconds}s.',
    );

    _retryTimer = Timer(
      _loadRetryDelay,
      () {
        _retryTimer = null;

        if (_disposed) {
          return;
        }

        unawaited(
          _loadRewardedAdInternal(),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // PUBLIC LOAD
  // ------------------------------------------------------------

  Future<void> loadRewardedAd() async {
    if (_disposed) {
      return;
    }

    if (!_initialized) {
      final initialized =
          await initialize();

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
  // WAIT FOR REWARDED AD
  // ------------------------------------------------------------

  Future<bool> _waitForRewardedAdReady(
    _RewardedAdMode mode,
  ) async {
    if (_disposed) {
      return false;
    }

    if (!_initialized) {
      final initialized =
          await initialize();

      if (!initialized) {
        debugPrint(
          'LEVELPLAY: SDK could not initialize.',
        );

        return false;
      }
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    final ad = _rewardedAd;

    if (ad == null) {
      debugPrint(
        'LEVELPLAY: rewarded ad object is unavailable.',
      );

      return false;
    }

    final timeout =
        mode == _RewardedAdMode.activation
            ? _activationAdReadyTimeout
            : _boostAdReadyTimeout;

    try {
      final alreadyReady =
          await ad.isAdReady();

      if (alreadyReady) {
        debugPrint(
          'LEVELPLAY: rewarded ad is already READY.',
        );

        return true;
      }
    } catch (e) {
      debugPrint(
        'LEVELPLAY: initial ready check failed: $e',
      );
    }

    debugPrint(
      'LEVELPLAY: rewarded ad is not ready. '
      'Requesting load...',
    );

    unawaited(
      _loadRewardedAdInternal(),
    );

    final stopwatch =
        Stopwatch()..start();

    while (!_disposed &&
        stopwatch.elapsed < timeout) {
      try {
        final ready =
            await ad.isAdReady();

        if (ready) {
          debugPrint(
            'LEVELPLAY: rewarded ad became READY '
            'after ${stopwatch.elapsed.inMilliseconds}ms.',
          );

          return true;
        }
      } catch (e) {
        debugPrint(
          'LEVELPLAY: waiting for ad ready failed: $e',
        );
      }

      await Future.delayed(
        _adReadyPollInterval,
      );
    }

    debugPrint(
      'LEVELPLAY: rewarded ad was NOT ready '
      'after ${timeout.inSeconds}s.',
    );

    return false;
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

    if (_showCompleter != null &&
        !_showCompleter!.isCompleted) {
      debugPrint(
        'LEVELPLAY: another rewarded ad is already showing.',
      );

      return false;
    }

    final initialized =
        await initialize();

    if (!initialized) {
      debugPrint(
        'LEVELPLAY: cannot show ad. SDK not initialized.',
      );

      return false;
    }

    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'LEVELPLAY: user is not authenticated.',
      );

      return false;
    }

    // ----------------------------------------------------------
    // BOOST VALIDATION
    // ----------------------------------------------------------

    if (mode == _RewardedAdMode.boost) {
      final mining =
          await _getActiveMining();

      if (mining == null) {
        debugPrint(
          'LEVELPLAY: Boost Ad blocked. '
          'No active mining session.',
        );

        return false;
      }

      // IMPORTANT:
      //
      // Do NOT use DateTime.now() here.
      //
      // The server's remaining_seconds is authoritative.
      final remainingSeconds =
          _readInt(
        mining,
        const [
          'remaining_seconds',
          'seconds_remaining',
          'remaining',
        ],
      );

      if (remainingSeconds <= 0) {
        debugPrint(
          'LEVELPLAY: Boost Ad blocked. '
          'Server says mining has no remaining time.',
        );

        return false;
      }

      final serverActive =
          mining['active'];

      final status =
          mining['status']
              ?.toString()
              .toLowerCase()
              .trim();

      final miningActive =
          mining['mining_active'];

      final explicitlyInactive =
          serverActive is bool &&
              !serverActive;

      final explicitlyMiningInactive =
          miningActive is bool &&
              !miningActive;

      final explicitlyNonActiveStatus =
          status != null &&
              status.isNotEmpty &&
              status != 'active' &&
              status != 'mining';

      if (explicitlyInactive ||
          explicitlyMiningInactive ||
          explicitlyNonActiveStatus) {
        debugPrint(
          'LEVELPLAY: Boost Ad blocked. '
          'Server mining state is not active.',
        );

        return false;
      }

      final adsWatched =
          _readInt(
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

      debugPrint(
        'LEVELPLAY: Boost Ad allowed. '
        'Server remaining=$remainingSeconds seconds, '
        'ads=$adsWatched/$maxAdsPerSession.',
      );
    }

    // ----------------------------------------------------------
    // ACTIVATION VALIDATION
    // ----------------------------------------------------------

    if (mode == _RewardedAdMode.activation) {
      debugPrint(
        'LEVELPLAY: Activation Ad requested.',
      );

      debugPrint(
        'LEVELPLAY: Activation Ad does not require active mining.',
      );

      debugPrint(
        'LEVELPLAY: Activation Ad does not record Boost reward.',
      );

      debugPrint(
        'LEVELPLAY: Activation Ad does not increase mining rate.',
      );
    }

    // ----------------------------------------------------------
    // WAIT FOR READY
    // ----------------------------------------------------------

    final ready =
        await _waitForRewardedAdReady(
      mode,
    );

    if (!ready) {
      if (mode == _RewardedAdMode.activation) {
        debugPrint(
          'LEVELPLAY: Activation Ad unavailable after '
          '${_activationAdReadyTimeout.inSeconds}s. '
          'Activation is optional; caller may continue mining.',
        );
      } else {
        debugPrint(
          'LEVELPLAY: Boost Ad unavailable after '
          '${_boostAdReadyTimeout.inSeconds}s. '
          'BOOST WILL NOT BE GRANTED.',
        );
      }

      return false;
    }

    final ad = _rewardedAd;

    if (ad == null) {
      debugPrint(
        'LEVELPLAY: rewarded ad object disappeared.',
      );

      return false;
    }

    // ----------------------------------------------------------
    // FINAL READY CHECK
    // ----------------------------------------------------------

    try {
      final finalReady =
          await ad.isAdReady();

      if (!finalReady) {
        debugPrint(
          'LEVELPLAY: rewarded ad became not-ready '
          'before show.',
        );

        unawaited(
          _loadRewardedAdInternal(),
        );

        return false;
      }
    } catch (e) {
      debugPrint(
        'LEVELPLAY final ready check failed: $e',
      );

      return false;
    }

    // ----------------------------------------------------------
    // PREPARE STATE
    // ----------------------------------------------------------

    _rewardGraceTimer?.cancel();
    _rewardGraceTimer = null;

    _currentMode = mode;

    _rewardGrantedForCurrentAd = false;
    _adClosed = false;
    _rewardProcessing = false;
    _rewardProcessingSucceeded = false;

    _onRewarded = onRewarded;
    _onAdClosed = onAdClosed;

    _showCompleter =
        Completer<bool>();

    try {
      debugPrint(
        'LEVELPLAY: showing '
        '${mode == _RewardedAdMode.activation ? 'Activation' : 'Boost'} Ad.',
      );

      await ad.showAd(
        placementName: placementName,
      );

      final completer =
          _showCompleter;

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

    _rewardGraceTimer?.cancel();
    _rewardGraceTimer = null;

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
    _rewardProcessingSucceeded = false;

    try {
      final mode =
          _currentMode;

      if (mode == null) {
        return;
      }

      // --------------------------------------------------------
      // ACTIVATION AD
      // --------------------------------------------------------

      if (mode ==
          _RewardedAdMode.activation) {
        debugPrint(
          'LEVELPLAY: Activation Ad completed.',
        );

        // IMPORTANT:
        // Activation reward NEVER becomes Boost reward.
        // It does NOT call record_rewarded_ad.
        // It does NOT call verify_rewarded_ad.
        // It does NOT add +0.10 FAN/H.

        debugPrint(
          'LEVELPLAY: Activation Ad completed '
          'without Boost reward.',
        );

        debugPrint(
          'LEVELPLAY: Activation Ad completed '
          'without mining rate change.',
        );

        _rewardProcessingSucceeded = true;

        final callback =
            _onRewarded;

        if (callback != null) {
          try {
            callback();
          } catch (e) {
            debugPrint(
              'LEVELPLAY activation callback error: $e',
            );

            _rewardProcessingSucceeded = false;
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

    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'LEVELPLAY: cannot record Boost Ad. '
        'User is not authenticated.',
      );

      _rewardProcessingSucceeded = false;

      return;
    }

    try {
      // --------------------------------------------------------
      // UNIQUE REFERENCE
      // --------------------------------------------------------

      _adReferenceCounter++;

      final adReference =
          'levelplay_${user.id}_$_adReferenceCounter';

      // --------------------------------------------------------
      // RECORD BOOST AD
      // --------------------------------------------------------

      debugPrint(
        'LEVELPLAY: recording Boost Ad on server...',
      );

      final recordResponse =
          await _supabase.rpc(
        'record_rewarded_ad',
        params: {
          'p_ad_reference':
              adReference,
        },
      );

      debugPrint(
        'LEVELPLAY record_rewarded_ad response: '
        '$recordResponse',
      );

      if (_responseIsFailure(
        recordResponse,
      )) {
        debugPrint(
          'LEVELPLAY: server rejected Boost Ad.',
        );

        _rewardProcessingSucceeded = false;

        return;
      }

      final adId =
          _extractAdId(
        recordResponse,
      );

      if (adId == null) {
        debugPrint(
          'LEVELPLAY: server did not return ad_id. '
          'Boost verification skipped.',
        );

        _rewardProcessingSucceeded = false;

        return;
      }

      // --------------------------------------------------------
      // VERIFY BOOST REWARD
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

      if (_responseIsFailure(
        verifyResponse,
      )) {
        debugPrint(
          'LEVELPLAY: Boost verification failed.',
        );

        _rewardProcessingSucceeded = false;

        return;
      }

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      debugPrint(
        'LEVELPLAY: Boost Ad verified successfully.',
      );

      debugPrint(
        'LEVELPLAY: +0.10 FAN/H may now be reflected '
        'by the server.',
      );

      _rewardProcessingSucceeded = true;

      final callback =
          _onRewarded;

      if (callback != null) {
        try {
          callback();
        } catch (e) {
          debugPrint(
            'LEVELPLAY Boost callback error: $e',
          );

          _rewardProcessingSucceeded = false;
        }
      }
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY BOOST SERVER ERROR: $e',
      );

      debugPrint('$st');

      _rewardProcessingSucceeded = false;
    }
  }

  // ------------------------------------------------------------
  // RESPONSE FAILURE
  // ------------------------------------------------------------

  bool _responseIsFailure(
    dynamic response,
  ) {
    if (response is Map) {
      final success =
          response['success'];

      if (success is bool) {
        return !success;
      }

      final status =
          response['status']
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

      if (response
          is Map<String, dynamic>) {
        return response;
      }

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
      }

      if (response is List &&
          response.isNotEmpty) {
        final first =
            response.first;

        if (first
            is Map<String, dynamic>) {
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

      if (data is List &&
          data.isNotEmpty) {
        final first =
            data.first;

        if (first is Map) {
          return first['ad_id'] ??
              first['id'];
        }
      }
    }

    if (response is List &&
        response.isNotEmpty) {
      final first =
          response.first;

      if (first is Map) {
        return first['ad_id'] ??
            first['id'];
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
      final value =
          data[key];

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
  // START REWARD GRACE TIMER
  // ------------------------------------------------------------

  void _startRewardGraceTimer() {
    _rewardGraceTimer?.cancel();

    if (_disposed) {
      return;
    }

    if (_rewardGrantedForCurrentAd) {
      _tryFinishCurrentAd();

      return;
    }

    debugPrint(
      'LEVELPLAY: ad closed before reward callback. '
      'Waiting ${_rewardCallbackGracePeriod.inSeconds}s '
      'for a late reward callback.',
    );

    _rewardGraceTimer =
        Timer(
      _rewardCallbackGracePeriod,
      () {
        _rewardGraceTimer = null;

        if (_disposed) {
          return;
        }

        if (_rewardGrantedForCurrentAd) {
          _tryFinishCurrentAd();

          return;
        }

        debugPrint(
          'LEVELPLAY: no reward callback received during '
          'the grace period.',
        );

        final completer =
            _showCompleter;

        if (completer != null &&
            !completer.isCompleted) {
          completer.complete(false);
        }

        _resetAfterAd();
      },
    );
  }

  // ------------------------------------------------------------
  // TRY FINISH CURRENT AD
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

    // Ad has not closed yet.
    if (!_adClosed) {
      return;
    }

    // Ad closed but reward has not arrived.
    //
    // Do NOT immediately fail because LevelPlay may send
    // onAdRewarded after onAdClosed.
    if (!_rewardGrantedForCurrentAd) {
      _startRewardGraceTimer();

      return;
    }

    // Reward received, but server processing is still running.
    if (_rewardProcessing) {
      return;
    }

    // Reward received but server processing failed.
    if (!_rewardProcessingSucceeded) {
      debugPrint(
        'LEVELPLAY: reward processing was not successful.',
      );

      completer.complete(false);

      _resetAfterAd();

      return;
    }

    debugPrint(
      'LEVELPLAY: rewarded ad completed successfully.',
    );

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
      'LEVELPLAY: rewarded ad loaded successfully.',
    );

    _retryTimer?.cancel();
    _retryTimer = null;
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

    if (error.errorCode == 509) {
      debugPrint(
        'LEVELPLAY: no fill (509). '
        'There is currently no rewarded ad available.',
      );
    }

    _loadingAd = false;

    _scheduleLoadRetry();
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
    _rewardGraceTimer?.cancel();
    _rewardGraceTimer = null;

    _showCompleter = null;

    _currentMode = null;

    _rewardGrantedForCurrentAd = false;
    _adClosed = false;
    _rewardProcessing = false;
    _rewardProcessingSucceeded = false;

    _onRewarded = null;
    _onAdClosed = null;

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
    _rewardGraceTimer?.cancel();
    _rewardGraceTimer = null;

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
    _rewardProcessingSucceeded = false;

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

    _retryTimer?.cancel();
    _retryTimer = null;

    _rewardGraceTimer?.cancel();
    _rewardGraceTimer = null;

    _clearAdState();

    _disposed = true;

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
    _loadingAd = false;
  }
}
