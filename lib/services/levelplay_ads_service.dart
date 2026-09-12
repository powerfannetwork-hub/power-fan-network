import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'kyc_service.dart';
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

  static const String rewardedAdUnitId =
      'z69e4f6g6emi98mbu';

  static const int maxAdsPerSession = 7;

  static const Duration initTimeout =
      Duration(seconds: 20);

  static const Duration adReadyTimeout =
      Duration(seconds: 30);

  static const Duration adReadyPollInterval =
      Duration(milliseconds: 500);

  static const int maxLoadAttempts = 3;

  // ============================================================
  // STATE
  // ============================================================

  LevelPlayRewardedAd? _rewardedAd;

  bool _initialized = false;
  bool _loading = false;
  bool _showing = false;
  bool _rewardProcessing = false;
  bool _rewardGrantedForCurrentAd = false;

  int? _adsWatchedBeforeCurrentAd;

  String? _claimRequestId;

  bool _currentAdIsClaimAd = false;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  Completer<void>? _initCompleter;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final existing = _initCompleter;

    if (existing != null) {
      try {
        await existing.future.timeout(initTimeout);
      } catch (_) {}

      return;
    }

    final user =
        SupabaseService.client.auth.currentUser;

    final userId = user?.id;

    if (userId == null || userId.isEmpty) {
      debugPrint(
        'LevelPlay: user is not authenticated.',
      );
      return;
    }

    final completer = Completer<void>();

    _initCompleter = completer;

    try {
      final initRequest =
          LevelPlayInitRequest
              .builder(appKeyAndroid)
              .withUserId(userId)
              .build();

      debugPrint(
        'LevelPlay: initializing...',
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
          'LevelPlay: initialization wait timed out.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: initialization error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!completer.isCompleted) {
        completer.complete();
      }
    } finally {
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
        return false;
      }

      if (_rewardedAd == null) {
        _createRewardedAd();
      }

      final ad = _rewardedAd;

      if (ad == null) {
        return false;
      }

      final ready =
          await ad.isAdReady();

      debugPrint(
        'LevelPlay: isRewardedAdReady = $ready',
      );

      return ready;
    } catch (e) {
      debugPrint(
        'LevelPlay: isRewardedAdReady error: $e',
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
        'LevelPlay: cannot load ad because SDK is not initialized.',
      );
      return;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    final ad = _rewardedAd;

    if (ad == null) {
      debugPrint(
        'LevelPlay: rewarded ad object is null.',
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
      final ready =
          await ad.isAdReady();

      if (ready) {
        debugPrint(
          'LevelPlay: rewarded ad already READY.',
        );
        return;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: ready check error: $e',
      );
    }

    _loading = true;

    try {
      debugPrint(
        'LevelPlay: LOAD REWARDED AD.',
      );

      await ad.loadAd();

      debugPrint(
        'LevelPlay: loadAd() request sent.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: loadAd() error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _loading = false;
    }
  }

  // ============================================================
  // WAIT FOR READY
  // ============================================================

  Future<bool> _ensureRewardedAdReady() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      debugPrint(
        'LevelPlay: SDK is not initialized.',
      );
      return false;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    final ad = _rewardedAd;

    if (ad == null) {
      return false;
    }

    // ----------------------------------------------------------
    // FIRST CHECK
    // ----------------------------------------------------------

    try {
      final ready =
          await ad.isAdReady();

      if (ready) {
        debugPrint(
          'LevelPlay: rewarded ad is already READY.',
        );

        return true;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: first ready check failed: $e',
      );
    }

    // ----------------------------------------------------------
    // TRY MULTIPLE LOAD ATTEMPTS
    // ----------------------------------------------------------

    for (int loadAttempt = 1;
        loadAttempt <= maxLoadAttempts;
        loadAttempt++) {
      debugPrint(
        'LevelPlay: ad load attempt '
        '$loadAttempt/$maxLoadAttempts',
      );

      if (!_loading) {
        await loadRewardedAd();
      }

      final stopwatch = Stopwatch()..start();

      while (stopwatch.elapsed <
          adReadyTimeout) {
        try {
          final ready =
              await ad.isAdReady();

          if (ready) {
            _loading = false;

            debugPrint(
              'LevelPlay: REWARDED AD READY.',
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
        'LevelPlay: ad still not ready after '
        '$adReadyTimeout.',
      );
    }

    debugPrint(
      'LevelPlay: FAILED TO GET READY REWARDED AD '
      'after $maxLoadAttempts attempts.',
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
        'LevelPlay: ad is already showing.',
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

      final user =
          SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: user is not authenticated.',
        );

        return false;
      }

      // --------------------------------------------------------
      // GET MINING
      // --------------------------------------------------------

      final mining =
          await MiningService.instance
              .getActiveMining();

      if (mining.isEmpty) {
        debugPrint(
          'LevelPlay: no mining session.',
        );

        return false;
      }

      final active =
          _isMiningActive(mining);

      final claimable =
          _isMiningClaimable(mining);

      if (!active && !claimable) {
        debugPrint(
          'LevelPlay: mining is neither active nor claimable.',
        );

        return false;
      }

      final adsWatched =
          _extractAdsWatched(mining);

      debugPrint(
        'LevelPlay: mining active=$active '
        'claimable=$claimable '
        'adsWatched=$adsWatched',
      );

      // --------------------------------------------------------
      // MAX 7 ADS
      // --------------------------------------------------------

      if (active &&
          adsWatched >= maxAdsPerSession) {
        debugPrint(
          'LevelPlay: maximum 7 ads already reached.',
        );

        return false;
      }

      // --------------------------------------------------------
      // WAIT FOR REAL AD FIRST
      //
      // IMPORTANT:
      // We do NOT create claim request until the ad
      // is actually ready.
      // --------------------------------------------------------

      debugPrint(
        'LevelPlay: waiting for rewarded ad...',
      );

      final ready =
          await _ensureRewardedAdReady();

      if (!ready) {
        debugPrint(
          'LevelPlay: NO READY REWARDED AD.',
        );

        return false;
      }

      // --------------------------------------------------------
      // CLAIM REQUEST
      // --------------------------------------------------------

      String? claimRequestId;

      if (claimable) {
        claimRequestId =
            await _createClaimAdRequest();

        if (claimRequestId == null ||
            claimRequestId.isEmpty) {
          debugPrint(
            'LevelPlay: failed to create claim ad request.',
          );

          return false;
        }

        debugPrint(
          'LevelPlay: claim request created: '
          '$claimRequestId',
        );
      } else {
        _adsWatchedBeforeCurrentAd =
            adsWatched;

        debugPrint(
          'LevelPlay: previous ads watched = '
          '$_adsWatchedBeforeCurrentAd',
        );
      }

      // --------------------------------------------------------
      // SAVE CURRENT AD STATE
      // --------------------------------------------------------

      _claimRequestId =
          claimRequestId;

      _currentAdIsClaimAd =
          claimable;

      _rewardProcessing = false;

      _rewardGrantedForCurrentAd =
          false;

      _onRewarded =
          onRewarded;

      _onAdClosed =
          onAdClosed;

      // --------------------------------------------------------
      // DYNAMIC USER ID
      // --------------------------------------------------------

      try {
        await LevelPlay.setDynamicUserId(
          userId,
        );

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
          'LevelPlay: rewarded ad object disappeared.',
        );

        _clearCurrentAdState();

        return false;
      }

      final finalReady =
          await ad.isAdReady();

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
        'LevelPlay: SHOWING REWARDED AD NOW',
      );

      debugPrint(
        'LevelPlay: claimAd=$_currentAdIsClaimAd',
      );

      debugPrint(
        'LevelPlay: previousAds=$_adsWatchedBeforeCurrentAd',
      );

      debugPrint(
        '================================================',
      );

      await ad.showAd();

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
  // CLAIM REQUEST
  // ============================================================

  Future<String?> _createClaimAdRequest() async {
    try {
      final response =
          await SupabaseService.client.rpc(
        'request_claim_ad',
      );

      debugPrint(
        'LevelPlay: request_claim_ad response = '
        '$response',
      );

      return _extractRequestId(response);
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: request_claim_ad ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // CREATE REWARDED AD OBJECT
  // ============================================================

  void _createRewardedAd() {
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
        'LevelPlay: rewarded ad object CREATED.',
      );

      debugPrint(
        'LevelPlay: rewarded ad unit = '
        '$rewardedAdUnitId',
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
      '================================================',
    );

    _initialized = true;

    _createRewardedAd();

    final completer =
        _initCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete();
    }

    // Start loading immediately.
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
      '$error',
    );

    debugPrint(
      '================================================',
    );

    _initialized = false;
    _loading = false;

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

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: REWARDED AD LOADED SUCCESSFULLY',
    );

    debugPrint(
      '$adInfo',
    );

    debugPrint(
      '================================================',
    );
  }

  // ============================================================
  // AD LOAD FAILED
  // ============================================================

  @override
  void onAdLoadFailed(
    LevelPlayAdError error,
  ) {
    _loading = false;

    debugPrint(
      '================================================',
    );

    debugPrint(
      'LevelPlay: REWARDED AD LOAD FAILED',
    );

    debugPrint(
      '$error',
    );

    debugPrint(
      '================================================',
    );
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
      '$error',
    );

    debugPrint(
      '$adInfo',
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

    if (_currentAdIsClaimAd) {
      final requestId =
          _claimRequestId;

      if (requestId == null ||
          requestId.isEmpty) {
        debugPrint(
          'LevelPlay: claim request ID missing.',
        );

        _rewardProcessing = false;

        return;
      }

      unawaited(
        _processClaimAdReward(
          requestId,
        ),
      );

      return;
    }

    final previousAds =
        _adsWatchedBeforeCurrentAd ?? 0;

    unawaited(
      _processMiningAdReward(
        previousAds,
      ),
    );
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

    _clearCurrentAdState();

    callback?.call();

    // Immediately preload next ad.
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
  }

  // ============================================================
  // NORMAL MINING REWARD
  // ============================================================

  Future<void> _processMiningAdReward(
    int previousAdsWatched,
  ) async {
    try {
      debugPrint(
        'LevelPlay: waiting for S2S reward confirmation...',
      );

      final confirmed =
          await _waitForS2SRewardConfirmation(
        previousAdsWatched,
      );

      if (!confirmed) {
        debugPrint(
          'LevelPlay: S2S reward NOT confirmed.',
        );

        _rewardProcessing = false;

        return;
      }

      debugPrint(
        'LevelPlay: S2S reward CONFIRMED.',
      );

      try {
        await KycService()
            .recordDailyBoost();

        debugPrint(
          'LevelPlay: daily boost recorded.',
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: recordDailyBoost failed: $e',
        );
      }

      _rewardGrantedForCurrentAd = true;

      final callback =
          _onRewarded;

      callback?.call();
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: mining reward processing ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _rewardProcessing = false;
    }
  }

  // ============================================================
  // CLAIM REWARD
  // ============================================================

  Future<void> _processClaimAdReward(
    String requestId,
  ) async {
    try {
      debugPrint(
        'LevelPlay: waiting for claim verification...',
      );

      final confirmed =
          await _waitForClaimAdVerification(
        requestId,
      );

      if (!confirmed) {
        debugPrint(
          'LevelPlay: claim verification FAILED.',
        );

        _rewardProcessing = false;

        return;
      }

      debugPrint(
        'LevelPlay: claim verification CONFIRMED.',
      );

      _rewardGrantedForCurrentAd = true;

      final callback =
          _onRewarded;

      callback?.call();
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: claim reward processing ERROR: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _rewardProcessing = false;
    }
  }

  // ============================================================
  // WAIT FOR S2S
  // ============================================================

  Future<bool> _waitForS2SRewardConfirmation(
    int previousAdsWatched,
  ) async {
    const maxAttempts = 50;

    for (int attempt = 0;
        attempt < maxAttempts;
        attempt++) {
      try {
        final mining =
            await MiningService.instance
                .getActiveMining();

        final currentAds =
            _extractAdsWatched(mining);

        debugPrint(
          'LevelPlay: S2S check '
          '${attempt + 1}/$maxAttempts '
          'current=$currentAds '
          'previous=$previousAdsWatched',
        );

        if (currentAds >
            previousAdsWatched) {
          return true;
        }
      } catch (e) {
        debugPrint(
          'LevelPlay: S2S polling error: $e',
        );
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );
    }

    return false;
  }

  // ============================================================
  // WAIT FOR CLAIM VERIFICATION
  // ============================================================

  Future<bool> _waitForClaimAdVerification(
    String requestId,
  ) async {
    const maxAttempts = 60;

    for (int attempt = 0;
        attempt < maxAttempts;
        attempt++) {
      try {
        final response =
            await MiningService.instance
                .getClaimAdStatus();

        debugPrint(
          'LevelPlay: claim status '
          '${attempt + 1}/$maxAttempts '
          'request=$requestId '
          'response=$response',
        );

        final verified =
            _extractBool(
          response,
          const [
            'verified',
            'rewarded',
            'approved',
            'confirmed',
            'success',
          ],
        );

        if (verified == true) {
          return true;
        }

        final status =
            _extractString(
          response,
          const [
            'status',
          ],
        );

        if (status != null) {
          final normalized =
              status.toLowerCase().trim();

          if (normalized == 'verified' ||
              normalized == 'rewarded' ||
              normalized == 'approved' ||
              normalized == 'confirmed' ||
              normalized == 'completed' ||
              normalized == 'success') {
            return true;
          }

          if (normalized == 'failed' ||
              normalized == 'rejected' ||
              normalized == 'cancelled' ||
              normalized == 'expired') {
            return false;
          }
        }
      } catch (e) {
        debugPrint(
          'LevelPlay: claim status error: $e',
        );
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );
    }

    return false;
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
      final value =
          data[key];

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
  // MINING CLAIMABLE
  // ============================================================

  bool _isMiningClaimable(
    Map<String, dynamic> data,
  ) {
    final claimable =
        _extractBool(
      data,
      const [
        'claimable',
        'can_claim',
        'claim_required',
        'requires_claim',
        'session_completed',
        'completed',
      ],
    );

    if (claimable == true) {
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

      const claimStatuses = {
        'completed',
        'expired',
        'ready_to_claim',
        'claimable',
        'pending_claim',
        'ended',
      };

      if (claimStatuses.contains(
        normalized,
      )) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // REQUEST ID
  // ============================================================

  String? _extractRequestId(
    dynamic response,
  ) {
    if (response is Map) {
      const keys = [
        'request_id',
        'requestId',
        'id',
      ];

      for (final key in keys) {
        final value =
            response[key];

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
        for (final key in keys) {
          final value =
              nested[key];

          if (value != null) {
            final text =
                value.toString().trim();

            if (text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    }

    if (response is List &&
        response.isNotEmpty) {
      return _extractRequestId(
        response.first,
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
  // STRING
  // ============================================================

  String? _extractString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value =
          data[key];

      if (value == null) {
        continue;
      }

      final text =
          value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  // ============================================================
  // BOOL
  // ============================================================

  bool? _extractBool(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value =
          data[key];

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
            normalized == 'verified' ||
            normalized == 'approved' ||
            normalized == 'confirmed') {
          return true;
        }

        if (normalized == 'false' ||
            normalized == '0' ||
            normalized == 'no') {
          return false;
        }
      }
    }

    return null;
  }

  // ============================================================
  // CLEAR STATE
  // ============================================================

  void _clearCurrentAdState() {
    _claimRequestId = null;

    _currentAdIsClaimAd = false;

    _adsWatchedBeforeCurrentAd =
        null;

    _rewardProcessing = false;

    _rewardGrantedForCurrentAd =
        false;

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

    final completer =
        _initCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete();
    }

    _initCompleter = null;

    final ad =
        _rewardedAd;

    _rewardedAd = null;

    if (ad != null) {
      unawaited(
        ad.dispose(),
      );
    }

    _clearCurrentAdState();

    _initialized = false;
  }
}
