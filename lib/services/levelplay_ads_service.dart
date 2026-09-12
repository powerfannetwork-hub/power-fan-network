import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// IMPORTANT:
// Ka tabbata package name ɗin LevelPlay ɗinka da imports ɗin nan
// sun yi daidai da package ɗin da kake amfani da shi.
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../services/supabase_service.dart';

enum _RewardedAdMode {
  boost,
  activation,
}

class LevelPlayAdsService {
  LevelPlayAdsService._();

  static final LevelPlayAdsService instance = LevelPlayAdsService._();

  static const String appKey = '27f58cf85';
  static const String rewardedAdUnitId = 'z69e4fg6emi98mbu';

  static const int maxAdsPerSession = 7;

  static const String activationMessage =
      'Watch the activation ad to start your 24-hour mining session.';

  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;

  dynamic _rewardedAd;

  bool _rewardGrantedForCurrentAd = false;
  bool _adWasClosed = false;

  _RewardedAdMode? _currentMode;

  VoidCallback? _onRewarded;
  VoidCallback? _onAdClosed;

  Completer<bool>? _showCompleter;

  static const Duration _showTimeout = Duration(seconds: 60);

  SupabaseClient get _supabase => SupabaseService.client;

  /// ------------------------------------------------------------
  /// INITIALIZE LEVELPLAY
  /// ------------------------------------------------------------
  Future<bool> initialize() async {
    if (_disposed) {
      return false;
    }

    if (_initialized) {
      return true;
    }

    if (_initializing) {
      while (_initializing && !_disposed) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      return _initialized && !_disposed;
    }

    _initializing = true;

    try {
      debugPrint('LEVELPLAY: initializing...');

      await LevelPlay.init(
        LevelPlayInitRequest(
          appKey: appKey,
        ),
      );

      if (_disposed) {
        return false;
      }

      _initialized = true;

      _setupRewardedAd();

      debugPrint('LEVELPLAY: initialized successfully.');

      return true;
    } catch (e, st) {
      debugPrint('LEVELPLAY INIT ERROR: $e');
      debugPrint('$st');

      _initialized = false;

      return false;
    } finally {
      _initializing = false;
    }
  }

  /// ------------------------------------------------------------
  /// SETUP REWARDED AD
  /// ------------------------------------------------------------
  void _setupRewardedAd() {
    if (_disposed) {
      return;
    }

    try {
      _rewardedAd = LevelPlayRewardedAd(
        adUnitId: rewardedAdUnitId,
      );

      _rewardedAd.setListener(
        LevelPlayRewardedAdListener(
          onAdLoaded: (adInfo) {
            debugPrint('LEVELPLAY: rewarded ad loaded.');
          },
          onAdLoadFailed: (error) {
            debugPrint(
              'LEVELPLAY: rewarded ad load failed: $error',
            );
          },
          onAdDisplayed: (adInfo) {
            debugPrint(
              'LEVELPLAY: rewarded ad displayed.',
            );
          },
          onAdDisplayFailed: (error, adInfo) {
            debugPrint(
              'LEVELPLAY: rewarded ad display failed: $error',
            );

            _finishCurrentAd(success: false);
          },
          onAdClicked: (adInfo) {
            debugPrint(
              'LEVELPLAY: rewarded ad clicked.',
            );
          },
          onAdClosed: (adInfo) {
            debugPrint(
              'LEVELPLAY: rewarded ad closed.',
            );

            _adWasClosed = true;

            final callback = _onAdClosed;

            if (callback != null) {
              try {
                callback();
              } catch (e) {
                debugPrint(
                  'LEVELPLAY onAdClosed callback error: $e',
                );
              }
            }

            if (_rewardGrantedForCurrentAd) {
              _finishCurrentAd(success: true);
            } else {
              _finishCurrentAd(success: false);
            }
          },
          onAdRewarded: (reward, adInfo) {
            debugPrint(
              'LEVELPLAY: rewarded callback received. '
              'reward=$reward',
            );

            _handleRewardedCallback();
          },
        ),
      );

      _loadRewardedAd();
    } catch (e, st) {
      debugPrint('LEVELPLAY SETUP ERROR: $e');
      debugPrint('$st');
    }
  }

  /// ------------------------------------------------------------
  /// LOAD REWARDED AD
  /// ------------------------------------------------------------
  void _loadRewardedAd() {
    if (_disposed || _rewardedAd == null) {
      return;
    }

    try {
      _rewardedAd.loadAd();

      debugPrint(
        'LEVELPLAY: loading rewarded ad...',
      );
    } catch (e) {
      debugPrint(
        'LEVELPLAY LOAD ERROR: $e',
      );
    }
  }

  /// ------------------------------------------------------------
  /// CHECK READY
  /// ------------------------------------------------------------
  bool get isRewardedAdReady {
    if (_disposed || _rewardedAd == null) {
      return false;
    }

    try {
      return _rewardedAd.isAdReady();
    } catch (e) {
      debugPrint(
        'LEVELPLAY READY CHECK ERROR: $e',
      );

      return false;
    }
  }

  /// ------------------------------------------------------------
  /// PUBLIC BOOST AD METHOD
  ///
  /// This is ONLY for Boost Ads while mining is active.
  /// ------------------------------------------------------------
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

  /// ------------------------------------------------------------
  /// PUBLIC ACTIVATION AD METHOD
  ///
  /// IMPORTANT FIX:
  /// The callback name is onRewarded, not onCompleted.
  ///
  /// Activation Ad:
  /// - does NOT call record_rewarded_ad
  /// - does NOT call verify_rewarded_ad
  /// - does NOT increase mining rate
  /// - does NOT count as one of the 7 Boost Ads
  /// - only authorizes the app to start a new mining session
  /// ------------------------------------------------------------
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

  /// ------------------------------------------------------------
  /// SHOW REWARDED AD
  /// ------------------------------------------------------------
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
        'LEVELPLAY: cannot show ad because initialization failed.',
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
    // BOOST MODE
    // ----------------------------------------------------------
    //
    // Boost Ads are allowed ONLY while mining is active.
    //
    if (mode == _RewardedAdMode.boost) {
      final mining = await _getActiveMining();

      if (mining == null) {
        debugPrint(
          'LEVELPLAY: no active mining session. '
          'Boost Ad blocked.',
        );

        return false;
      }

      final bool isActive = _isMiningActive(mining);

      if (!isActive) {
        debugPrint(
          'LEVELPLAY: mining is not active. '
          'Boost Ad blocked.',
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
          'LEVELPLAY: maximum Boost Ads reached.',
        );

        return false;
      }
    }

    // ----------------------------------------------------------
    // ACTIVATION MODE
    // ----------------------------------------------------------
    //
    // No active mining session is required here.
    //
    if (mode == _RewardedAdMode.activation) {
      debugPrint(
        'LEVELPLAY: showing Activation Ad.',
      );
    }

    if (_showCompleter != null &&
        !_showCompleter!.isCompleted) {
      debugPrint(
        'LEVELPLAY: another rewarded ad is already showing.',
      );

      return false;
    }

    if (!isRewardedAdReady) {
      debugPrint(
        'LEVELPLAY: rewarded ad is not ready.',
      );

      _loadRewardedAd();

      return false;
    }

    _currentMode = mode;
    _rewardGrantedForCurrentAd = false;
    _adWasClosed = false;

    _onRewarded = onRewarded;
    _onAdClosed = onAdClosed;

    _showCompleter = Completer<bool>();

    try {
      debugPrint(
        'LEVELPLAY: showing '
        '${mode == _RewardedAdMode.activation ? 'Activation' : 'Boost'} Ad.',
      );

      _rewardedAd.showAd();

      return await _showCompleter!.future.timeout(
        _showTimeout,
        onTimeout: () {
          debugPrint(
            'LEVELPLAY: rewarded ad timed out.',
          );

          _clearAdState();

          return false;
        },
      );
    } catch (e, st) {
      debugPrint(
        'LEVELPLAY SHOW ERROR: $e',
      );
      debugPrint('$st');

      _clearAdState();

      return false;
    }
  }

  /// ------------------------------------------------------------
  /// LEVELPLAY REWARD CALLBACK
  /// ------------------------------------------------------------
  Future<void> _handleRewardedCallback() async {
    if (_disposed) {
      return;
    }

    final mode = _currentMode;

    if (mode == null) {
      debugPrint(
        'LEVELPLAY: reward callback received '
        'without an active ad mode.',
      );

      return;
    }

    _rewardGrantedForCurrentAd = true;

    // ----------------------------------------------------------
    // ACTIVATION AD
    // ----------------------------------------------------------
    //
    // IMPORTANT:
    // No Supabase boost RPC is called here.
    //
    if (mode == _RewardedAdMode.activation) {
      await _processActivationReward();
      return;
    }

    // ----------------------------------------------------------
    // BOOST AD
    // ----------------------------------------------------------
    await _processMiningAd();
  }

  /// ------------------------------------------------------------
  /// ACTIVATION AD REWARD
  /// ------------------------------------------------------------
  Future<void> _processActivationReward() async {
    if (_disposed) {
      return;
    }

    debugPrint(
      'LEVELPLAY: Activation Ad completed.',
    );

    debugPrint(
      'LEVELPLAY: Activation Ad does not create a Boost reward.',
    );

    debugPrint(
      'LEVELPLAY: Activation Ad does not modify mining rate.',
    );

    final callback = _onRewarded;

    if (callback != null) {
      try {
        callback();
      } catch (e) {
        debugPrint(
          'LEVELPLAY Activation callback error: $e',
        );
      }
    }
  }

  /// ------------------------------------------------------------
  /// BOOST AD REWARD
  /// ------------------------------------------------------------
  Future<void> _processMiningAd() async {
    if (_disposed) {
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'LEVELPLAY: cannot record Boost Ad '
        'because user is not authenticated.',
      );

      return;
    }

    try {
      debugPrint(
        'LEVELPLAY: recording Boost Ad on server...',
      );

      final recordResponse = await _supabase.rpc(
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

      if (recordResponse is Map) {
        final success = recordResponse['success'];

        if (success == false) {
          debugPrint(
            'LEVELPLAY: server rejected Boost Ad.',
          );

          return;
        }
      }

      // --------------------------------------------------------
      // VERIFY BOOST REWARD
      // --------------------------------------------------------
      debugPrint(
        'LEVELPLAY: verifying Boost Ad on server...',
      );

      final verifyResponse = await _supabase.rpc(
        'verify_rewarded_ad',
        params: {
          'p_ad_id': _extractAdId(recordResponse),
        },
      );

      debugPrint(
        'LEVELPLAY verify_rewarded_ad response: '
        '$verifyResponse',
      );

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

  /// ------------------------------------------------------------
  /// GET ACTIVE MINING
  /// ------------------------------------------------------------
  Future<Map<String, dynamic>?> _getActiveMining() async {
    try {
      final response = await _supabase.rpc(
        'get_active_mining',
      );

      if (response == null) {
        return null;
      }

      if (response is Map<String, dynamic>) {
        return response;
      }

      if (response is List && response.isNotEmpty) {
        final first = response.first;

        if (first is Map<String, dynamic>) {
          return first;
        }

        if (first is Map) {
          return Map<String, dynamic>.from(first);
        }
      }

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return null;
    } catch (e) {
      debugPrint(
        'LEVELPLAY get_active_mining ERROR: $e',
      );

      return null;
    }
  }

  /// ------------------------------------------------------------
  /// CHECK WHETHER MINING IS ACTIVE
  /// ------------------------------------------------------------
  bool _isMiningActive(
    Map<String, dynamic> mining,
  ) {
    final now = DateTime.now().toUtc();

    final startedAt = _readDateTime(
      mining,
      const [
        'started_at',
        'start_time',
        'started',
        'mining_started_at',
      ],
    );

    final endsAt = _readDateTime(
      mining,
      const [
        'ends_at',
        'end_time',
        'expires_at',
        'ended_at',
        'mining_ends_at',
      ],
    );

    if (startedAt != null && endsAt != null) {
      return startedAt.isBefore(now) &&
          endsAt.isAfter(now);
    }

    final status = mining['status']
        ?.toString()
        .toLowerCase()
        .trim();

    if (status == 'active') {
      return true;
    }

    final active = mining['active'];

    if (active is bool) {
      return active;
    }

    final miningActive = mining['mining_active'];

    if (miningActive is bool) {
      return miningActive;
    }

    return false;
  }

  /// ------------------------------------------------------------
  /// EXTRACT AD ID
  /// ------------------------------------------------------------
  dynamic _extractAdId(dynamic response) {
    if (response is Map) {
      return response['ad_id'] ??
          response['id'] ??
          response['data']?['ad_id'] ??
          response['data']?['id'];
    }

    return null;
  }

  /// ------------------------------------------------------------
  /// READ INT
  /// ------------------------------------------------------------
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
        final parsed = int.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  /// ------------------------------------------------------------
  /// READ DATETIME
  /// ------------------------------------------------------------
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
        final parsed = DateTime.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed.toUtc();
        }
      }
    }

    return null;
  }

  /// ------------------------------------------------------------
  /// FINISH CURRENT AD
  /// ------------------------------------------------------------
  void _finishCurrentAd({
    required bool success,
  }) {
    final completer = _showCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete(success);
    }

    _showCompleter = null;

    _currentMode = null;

    _rewardGrantedForCurrentAd = false;
    _adWasClosed = false;

    _onRewarded = null;
    _onAdClosed = null;

    // Load the next ad immediately.
    Future<void>.delayed(
      const Duration(milliseconds: 300),
      () {
        if (!_disposed) {
          _loadRewardedAd();
        }
      },
    );
  }

  /// ------------------------------------------------------------
  /// CLEAR AD STATE
  /// ------------------------------------------------------------
  void _clearAdState() {
    final completer = _showCompleter;

    if (completer != null &&
        !completer.isCompleted) {
      completer.complete(false);
    }

    _showCompleter = null;

    _currentMode = null;

    _rewardGrantedForCurrentAd = false;
    _adWasClosed = false;

    _onRewarded = null;
    _onAdClosed = null;
  }

  /// ------------------------------------------------------------
  /// PUBLIC PRELOAD
  /// ------------------------------------------------------------
  Future<void> preloadRewardedAd() async {
    if (_disposed) {
      return;
    }

    final initialized = await initialize();

    if (!initialized) {
      return;
    }

    if (!isRewardedAdReady) {
      _loadRewardedAd();
    }
  }

  /// ------------------------------------------------------------
  /// PUBLIC REFRESH
  /// ------------------------------------------------------------
  Future<void> refreshRewardedAd() async {
    if (_disposed) {
      return;
    }

    if (!_initialized) {
      await initialize();
      return;
    }

    _loadRewardedAd();
  }

  /// ------------------------------------------------------------
  /// APP LIFECYCLE
  /// ------------------------------------------------------------
  void onAppResumed() {
    if (_disposed) {
      return;
    }

    debugPrint(
      'LEVELPLAY: app resumed.',
    );

    if (_initialized && !isRewardedAdReady) {
      _loadRewardedAd();
    }
  }

  void onAppPaused() {
    if (_disposed) {
      return;
    }

    debugPrint(
      'LEVELPLAY: app paused.',
    );
  }

  /// ------------------------------------------------------------
  /// DISPOSE
  /// ------------------------------------------------------------
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _clearAdState();

    try {
      _rewardedAd?.destroy();
    } catch (e) {
      debugPrint(
        'LEVELPLAY destroy error: $e',
      );
    }

    _rewardedAd = null;

    _initialized = false;
    _initializing = false;
  }
}
