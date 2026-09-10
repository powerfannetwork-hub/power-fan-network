import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import 'kyc_service.dart';
import 'mining_service.dart';
import 'supabase_service.dart';

class LevelPlayAdsService
    implements LevelPlayInitListener, LevelPlayRewardedAdListener {
  LevelPlayAdsService._();

  static final LevelPlayAdsService instance = LevelPlayAdsService._();

  // ============================================================
  // LEVELPLAY CONFIGURATION
  // ============================================================

  static const String appKeyAndroid = '27f58cf85';

  static const String rewardedAdUnitId = 'z69e4f6g6emi98mbu';

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

  // Number of normal mining ads already recorded
  // by Supabase before the current ad.
  int? _adsWatchedBeforeCurrentAd;

  // Claim-ad request created on the server before
  // displaying the claim advertisement.
  String? _claimRequestId;

  // Whether the currently displayed ad is a claim ad.
  bool _currentAdIsClaimAd = false;

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
      final ready = await _rewardedAd!.isAdReady();

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
  //
  // ACTIVE SESSION:
  //   Normal mining boost advertisement.
  //
  // EXPIRED SESSION:
  //   Claim advertisement.
  //
  // The server remains authoritative for all rewards.
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
      final ready = await _rewardedAd!.isAdReady();

      if (!ready) {
        await loadRewardedAd();

        debugPrint(
          'LevelPlay: rewarded ad is not ready yet.',
        );

        return false;
      }

      final user = SupabaseService.client.auth.currentUser;

      final userId = user?.id;

      if (userId == null || userId.isEmpty) {
        debugPrint(
          'LevelPlay: cannot show rewarded ad '
          'without user ID.',
        );

        return false;
      }

      // ----------------------------------------------------------
      // RESET CURRENT AD STATE
      // ----------------------------------------------------------

      _adsWatchedBeforeCurrentAd = null;
      _claimRequestId = null;
      _currentAdIsClaimAd = false;

      // ----------------------------------------------------------
      // DETERMINE WHETHER THIS IS A CLAIM AD
      // ----------------------------------------------------------

      final mining =
          await MiningService.instance.getActiveMining();

      final claimable = _isMiningClaimable(mining);

      final miningActive = _isMiningActive(mining);

      if (claimable && !miningActive) {
        // --------------------------------------------------------
        // CLAIM AD
        // --------------------------------------------------------

        final request = await _createClaimAdRequest();

        final requestId = _extractRequestId(request);

        if (requestId == null || requestId.isEmpty) {
          debugPrint(
            'LevelPlay: failed to create claim-ad request.',
          );

          return false;
        }

        _claimRequestId = requestId;
        _currentAdIsClaimAd = true;

        debugPrint(
          'LevelPlay: claim-ad request created: '
          '$_claimRequestId',
        );
      } else if (miningActive) {
        // --------------------------------------------------------
        // NORMAL MINING BOOST AD
        // --------------------------------------------------------

        _adsWatchedBeforeCurrentAd =
            _extractAdsWatched(mining);

        debugPrint(
          'LevelPlay: normal mining ad. '
          'ads watched before current ad: '
          '$_adsWatchedBeforeCurrentAd',
        );
      } else {
        debugPrint(
          'LevelPlay: no active mining session and '
          'no claimable session.',
        );

        return false;
      }

      // ----------------------------------------------------------
      // ENSURE LEVELPLAY KNOWS THE AUTHENTICATED USER
      // ----------------------------------------------------------

      await LevelPlay.setDynamicUserId(userId);

      // ----------------------------------------------------------
      // REGISTER CALLBACKS
      // ----------------------------------------------------------

      _onRewarded = onRewarded;
      _onAdClosed = onAdClosed;

      _showing = true;
      _rewardProcessing = false;
      _rewardGrantedForCurrentAd = false;

      // ----------------------------------------------------------
      // SHOW AD
      // ----------------------------------------------------------

      _rewardedAd!.showAd();

      return true;
    } catch (e) {
      _showing = false;
      _rewardProcessing = false;

      _adsWatchedBeforeCurrentAd = null;
      _claimRequestId = null;
      _currentAdIsClaimAd = false;

      debugPrint(
        'LevelPlay show rewarded error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // CREATE CLAIM AD REQUEST
  // ============================================================

  Future<Map<String, dynamic>> _createClaimAdRequest() async {
    final result = await SupabaseService.safeCall(
      () async {
        final response = await SupabaseService.client.rpc(
          'request_claim_ad',
        );

        if (response is Map<String, dynamic>) {
          return response;
        }

        throw Exception(
          'Invalid claim-ad request response.',
        );
      },
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    throw Exception(
      'Invalid claim-ad request result.',
    );
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
    _claimRequestId = null;
    _currentAdIsClaimAd = false;
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

    _clearCurrentAdState();

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
      // ========================================================
      // CLAIM AD
      // ========================================================

      if (_currentAdIsClaimAd) {
        final requestId = _claimRequestId;

        if (requestId == null || requestId.isEmpty) {
          throw Exception(
            'Claim advertisement request ID is missing.',
          );
        }

        final confirmed =
            await _waitForClaimAdVerification(
          requestId: requestId,
        );

        if (!confirmed) {
          throw Exception(
            'Claim advertisement was not verified '
            'by Supabase within the timeout.',
          );
        }

        _rewardGrantedForCurrentAd = true;

        _onRewarded?.call();

        debugPrint(
          'LevelPlay: claim advertisement verified '
          'successfully.',
        );

        return;
      }

      // ========================================================
      // NORMAL MINING BOOST AD
      // ========================================================

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

      // KYC daily boost is recorded only for a normal
      // mining boost advertisement.
      try {
        await KycService().recordDailyBoost();

        debugPrint(
          'KYC: daily boost recorded successfully.',
        );
      } catch (e) {
        debugPrint(
          'KYC daily boost recording failed: $e',
        );
      }

      _rewardGrantedForCurrentAd = true;

      _onRewarded?.call();

      debugPrint(
        'LevelPlay: normal mining S2S reward '
        'confirmed successfully.',
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
  // WAIT FOR NORMAL MINING AD S2S CONFIRMATION
  // ============================================================

  Future<bool> _waitForS2SRewardConfirmation({
    required int previousAdsWatched,
  }) async {
    const Duration timeout = Duration(seconds: 25);

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
          'LevelPlay normal S2S confirmation: '
          'previous=$previousAdsWatched '
          'current=$currentAdsWatched',
        );

        if (currentAdsWatched >
            previousAdsWatched) {
          return true;
        }
      } catch (e) {
        debugPrint(
          'LevelPlay normal S2S confirmation '
          'poll failed: $e',
        );
      }

      await Future<void>.delayed(
        pollInterval,
      );
    }

    return false;
  }

  // ============================================================
  // WAIT FOR CLAIM AD S2S VERIFICATION
  // ============================================================

  Future<bool> _waitForClaimAdVerification({
    required String requestId,
  }) async {
    const Duration timeout = Duration(seconds: 30);

    const Duration pollInterval =
        Duration(milliseconds: 500);

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      try {
        final response = await SupabaseService.safeCall(
          () async {
            final result =
                await SupabaseService.client.rpc(
              'get_claim_ad_status',
              params: {
                'p_request_id': requestId,
              },
            );

            if (result is Map<String, dynamic>) {
              return result;
            }

            throw Exception(
              'Invalid claim-ad status response.',
            );
          },
        );

        final status = _extractString(
          response,
          'status',
        );

        final verified = _extractBool(
          response,
          'verified',
        );

        debugPrint(
          'LevelPlay claim S2S confirmation: '
          'request=$requestId '
          'status=$status '
          'verified=$verified',
        );

        if (verified || status == 'verified') {
          return true;
        }

        if (status == 'expired' ||
            status == 'cancelled') {
          return false;
        }
      } catch (e) {
        debugPrint(
          'LevelPlay claim S2S confirmation '
          'poll failed: $e',
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

  // ============================================================
  // DETECT ACTIVE MINING
  // ============================================================

  bool _isMiningActive(
    Map<String, dynamic> mining,
  ) {
    final value =
        mining['mining_active'] ??
        mining['active'];

    if (value is bool) {
      return value;
    }

    if (value != null) {
      return value.toString().toLowerCase() == 'true';
    }

    return false;
  }

  // ============================================================
  // DETECT CLAIMABLE MINING
  // ============================================================

  bool _isMiningClaimable(
    Map<String, dynamic> mining,
  ) {
    final claimable = mining['claimable'];

    if (claimable is bool && claimable) {
      return true;
    }

    final expired = mining['expired'];

    if (expired is bool && expired) {
      return true;
    }

    return false;
  }

  // ============================================================
  // EXTRACT REQUEST ID
  // ============================================================

  String? _extractRequestId(
    Map<String, dynamic> response,
  ) {
    final value = response['request_id'];

    if (value == null) {
      return null;
    }

    return value.toString();
  }

  // ============================================================
  // EXTRACT STRING
  // ============================================================

  String? _extractString(
    dynamic response,
    String key,
  ) {
    if (response is Map<String, dynamic>) {
      final value = response[key];

      if (value == null) {
        return null;
      }

      return value.toString();
    }

    return null;
  }

  // ============================================================
  // EXTRACT BOOLEAN
  // ============================================================

  bool _extractBool(
    dynamic response,
    String key,
  ) {
    if (response is Map<String, dynamic>) {
      final value = response[key];

      if (value is bool) {
        return value;
      }

      if (value != null) {
        return value.toString().toLowerCase() == 'true';
      }
    }

    return false;
  }

  // ============================================================
  // CLEAR CURRENT AD STATE
  // ============================================================

  void _clearCurrentAdState() {
    _onRewarded = null;
    _onAdClosed = null;

    _rewardProcessing = false;
    _rewardGrantedForCurrentAd = false;

    _adsWatchedBeforeCurrentAd = null;
    _claimRequestId = null;
    _currentAdIsClaimAd = false;
  }

  // ============================================================
  // AD CLICKED
  // ============================================================

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

    _clearCurrentAdState();

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
