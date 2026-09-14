import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

class LevelPlayAdsService {
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

  bool get isInitialized => _initialized;
  bool get isLoading => _loadingAd;
  bool get isShowing => _showingAd;

  Future<void> initialize() async {
    if (_initialized || _initializing) return;

    _initializing = true;

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User must be signed in before LevelPlay initialization.');
      }

      final userId = user.id;

      final initRequest = LevelPlayInitRequest.builder(appKey)
          .withUserId(userId)
          .build();

      await LevelPlay.init(initRequest);

      _initialized = true;

      _attachRewardedAd();

      await loadRewardedAd();
    } catch (e, st) {
      debugPrint('LevelPlay initialization error: $e');
      debugPrint('$st');

      _initialized = false;
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  void _attachRewardedAd() {
    _rewardedAd = LevelPlayRewardedAd(
      rewardedAdUnitId,
    );

    _rewardedAd!.setListener(
      LevelPlayRewardedAdListener(
        onAdLoaded: (adInfo) {
          _loadingAd = false;

          debugPrint(
            'LevelPlay rewarded ad loaded: ${adInfo.adUnitId}',
          );
        },
        onAdLoadFailed: (error) {
          _loadingAd = false;

          debugPrint(
            'LevelPlay rewarded ad load failed: '
            '${error.errorCode} - ${error.errorMessage}',
          );
        },
        onAdDisplayed: (adInfo) {
          _showingAd = true;

          debugPrint(
            'LevelPlay rewarded ad displayed: ${adInfo.adUnitId}',
          );
        },
        onAdDisplayFailed: (error, adInfo) {
          _showingAd = false;

          debugPrint(
            'LevelPlay rewarded ad display failed: '
            '${error.errorCode} - ${error.errorMessage}',
          );

          unawaited(loadRewardedAd());
        },
        onAdClicked: (adInfo) {
          debugPrint(
            'LevelPlay rewarded ad clicked: ${adInfo.adUnitId}',
          );
        },
        onAdClosed: (adInfo) {
          _showingAd = false;

          debugPrint(
            'LevelPlay rewarded ad closed: ${adInfo.adUnitId}',
          );

          unawaited(loadRewardedAd());
        },
        onAdRewarded: (reward, adInfo) {
          debugPrint(
            'LevelPlay rewarded event received: '
            'amount=${reward.amount}, '
            'name=${reward.name}',
          );

          /*
           * IMPORTANT:
           *
           * Wannan callback ba ya ƙara mining boost kai tsaye.
           *
           * LevelPlay S2S callback ne zai tabbatar da reward
           * sannan Supabase zai rubuta verified ad.
           */
        },
      ),
    );
  }

  Future<bool> loadRewardedAd() async {
    if (!_initialized) {
      await initialize();
    }

    if (_rewardedAd == null) {
      _attachRewardedAd();
    }

    if (_loadingAd) return false;

    _loadingAd = true;

    try {
      _rewardedAd!.loadAd();

      return true;
    } catch (e, st) {
      _loadingAd = false;

      debugPrint('LevelPlay loadAd error: $e');
      debugPrint('$st');

      return false;
    }
  }

  Future<bool> isRewardedAdReady() async {
    if (!_initialized) {
      await initialize();
    }

    if (_rewardedAd == null) {
      _attachRewardedAd();
    }

    try {
      return _rewardedAd!.isAdReady();
    } catch (e) {
      debugPrint('LevelPlay isAdReady error: $e');
      return false;
    }
  }

  Future<bool> showRewardedAd() async {
    if (!_initialized) {
      await initialize();
    }

    if (_showingAd) {
      debugPrint('LevelPlay rewarded ad is already showing.');
      return false;
    }

    if (_rewardedAd == null) {
      _attachRewardedAd();
      await loadRewardedAd();
    }

    bool ready = false;

    try {
      ready = _rewardedAd!.isAdReady();
    } catch (e) {
      debugPrint('LevelPlay readiness check failed: $e');
    }

    if (!ready) {
      debugPrint('Rewarded ad is not ready. Loading...');

      await loadRewardedAd();

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );

      try {
        ready = _rewardedAd!.isAdReady();
      } catch (_) {
        ready = false;
      }
    }

    if (!ready) {
      debugPrint('LevelPlay rewarded ad is still not ready.');
      return false;
    }

    _showingAd = true;

    try {
      _rewardedAd!.showAd(
        placementName: placementName,
      );

      return true;
    } catch (e, st) {
      _showingAd = false;

      debugPrint('LevelPlay showAd error: $e');
      debugPrint('$st');

      unawaited(loadRewardedAd());

      return false;
    }
  }

  Future<void> reloadRewardedAd() async {
    if (!_initialized) {
      await initialize();
    }

    await loadRewardedAd();
  }

  void dispose() {
    _rewardedAd = null;
    _initialized = false;
    _initializing = false;
    _loadingAd = false;
    _showingAd = false;
  }
}
