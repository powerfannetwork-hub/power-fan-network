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
      Duration(seconds: 15);

  static const Duration adReadyTimeout =
      Duration(seconds: 15);

  static const Duration adReadyPollInterval =
      Duration(milliseconds: 500);

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
      await existing.future;
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
          onTimeout: () {
            debugPrint(
              'LevelPlay: initialization timeout.',
            );
          },
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: initialization wait error: $e',
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
  // PUBLIC: CHECK IF REWARDED AD IS READY
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

      if (_rewardedAd == null) {
        return false;
      }

      final ready =
          await _rewardedAd!.isAdReady();

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
      return;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    if (_rewardedAd == null) {
      return;
    }

    if (_loading) {
      return;
    }

    try {
      final ready =
          await _rewardedAd!.isAdReady();

      if (ready) {
        debugPrint(
          'LevelPlay: rewarded ad already ready.',
        );
        return;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: initial ready check failed: $e',
      );
    }

    _loading = true;

    try {
      debugPrint(
        'LevelPlay: loading rewarded ad...',
      );

      await _rewardedAd!.loadAd();

      debugPrint(
        'LevelPlay: loadAd request sent.',
      );
    } catch (e, stackTrace) {
      _loading = false;

      debugPrint(
        'LevelPlay: loadRewardedAd error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  // ============================================================
  // WAIT UNTIL AD IS READY
  // ============================================================

  Future<bool> _ensureRewardedAdReady() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_initialized) {
      return false;
    }

    if (_rewardedAd == null) {
      _createRewardedAd();
    }

    if (_rewardedAd == null) {
      return false;
    }

    try {
      if (await _rewardedAd!.isAdReady()) {
        return true;
      }
    } catch (e) {
      debugPrint(
        'LevelPlay: ready check failed: $e',
      );
    }

    await loadRewardedAd();

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed <
        adReadyTimeout) {
      try {
        if (await _rewardedAd!.isAdReady()) {
          _loading = false;

          debugPrint(
            'LevelPlay: rewarded ad became READY.',
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
      'LevelPlay: rewarded ad still not ready.',
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
        'LevelPlay: ad already showing.',
      );

      return false;
    }

    try {
      if (!_initialized) {
        await initialize();
      }

      if (!_initialized) {
        return false;
      }

      final user =
          SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: user not authenticated.',
        );

        return false;
      }

      // ========================================================
      // GET MINING
      // ========================================================

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
          'LevelPlay: mining is not active or claimable.',
        );

        return false;
      }

      final adsWatched =
          _extractAdsWatched(mining);

      // ========================================================
      // MAX 7 ADS
      // ========================================================

      if (active &&
          adsWatched >= maxAdsPerSession) {
        debugPrint(
          'LevelPlay: maximum ads reached.',
        );

        return false;
      }

      // ========================================================
      // CLAIM AD
      // ========================================================

      String? claimRequestId;

      if (claimable) {
        claimRequestId =
            await _createClaimAdRequest();

        if (claimRequestId == null ||
            claimRequestId.isEmpty) {
          debugPrint(
            'LevelPlay: failed to create claim request.',
          );

          return false;
        }

        debugPrint(
          'LevelPlay: claim request created.',
        );
      } else {
        _adsWatchedBeforeCurrentAd =
            adsWatched;

        debugPrint(
          'LevelPlay: previous ads = '
          '$_adsWatchedBeforeCurrentAd',
        );
      }

      // ========================================================
      // WAIT FOR AD
      // ========================================================

      final ready =
          await _ensureRewardedAdReady();

      if (!ready) {
        debugPrint(
          'LevelPlay: rewarded ad is not ready.',
        );

        return false;
      }

      // ========================================================
      // SAVE STATE
      // ========================================================

      _claimRequestId =
          claimRequestId;

      _currentAdIsClaimAd =
          claimable;

      _rewardProcessing = false;
      _rewardGrantedForCurrentAd = false;

      _onRewarded = onRewarded;
      _onAdClosed = onAdClosed;

      // ========================================================
      // DYNAMIC USER ID
      // ========================================================

      try {
        await LevelPlay.setDynamicUserId(
          userId,
        );
      } catch (e) {
        debugPrint(
          'LevelPlay: setDynamicUserId failed: $e',
        );
      }

      // ========================================================
      // FINAL CHECK
      // ========================================================

      if (_rewardedAd == null) {
        _clearCurrentAdState();
        return false;
      }

      final finalReady =
          await _rewardedAd!.isAdReady();

      if (!finalReady) {
        debugPrint(
          'LevelPlay: ad became unavailable.',
        );

        _clearCurrentAdState();

        unawaited(
          loadRewardedAd(),
        );

        return false;
      }

      // ========================================================
      // SHOW
      // ========================================================

      _showing = true;

      debugPrint(
        'LevelPlay: SHOWING REWARDED AD.',
      );

      await _rewardedAd!.showAd();

      return true;
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: showRewardedAd error: $e',
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
        'LevelPlay: request_claim_ad = $response',
      );

      return _extractRequestId(response);
    } catch (e, stackTrace) {
      debugPrint(
        'LevelPlay: request_claim_ad error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  // ============================================================
  // CREATE AD OBJECT
  // ============================================================

  void _createRewardedAd() {
    if (_rewardedAd != null) {
      return;
    }

    try {
      _rewardedAd =
          LevelPlayRewardedAd(
        adUnitId: rewardedAdUnitId,
      );

      _rewardedAd!.setListener(this);

      debugPrint(
        'LevelPlay: rewarded ad object created.',
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
      'LevelPlay: INIT SUCCESS.',
    );

    _initialized = true;

    _createRewardedAd();

    final completer =
        _initCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete();
    }

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
      'LevelPlay: INIT FAILED: $error',
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
      'LevelPlay: AD LOADED.',
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
      'LevelPlay: AD LOAD FAILED: $error',
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
      'LevelPlay: AD DISPLAYED.',
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
      'LevelPlay: AD DISPLAY FAILED: $error',
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
  // IMPORTANT:
  // unity_levelplay_mediation 9.2.0 requires:
  // LevelPlayReward + LevelPlayAdInfo
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
      'LevelPlay: REWARD CALLBACK.',
    );

    debugPrint(
      'LevelPlay: reward name=${reward.name}, '
      'amount=${reward.amount}',
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
    } else {
      final previousAds =
          _adsWatchedBeforeCurrentAd ?? 0;

      unawaited(
        _processMiningAdReward(
          previousAds,
        ),
      );
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

    _clearCurrentAdState();

    callback?.call();

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
        'LevelPlay: mining reward error: $e',
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
        'LevelPlay: claim reward error: $e',
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
        // IMPORTANT:
        // getClaimAdStatus() in your MiningService
        // takes NO positional argument.
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
  // ADS WATCHED
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
      final value = data[key];

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
      final value = data[key];

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

    final ad = _rewardedAd;

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
