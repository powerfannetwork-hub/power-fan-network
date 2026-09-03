import 'dart:async';
import 'dart:io';

import 'package:applovin_max/applovin_max.dart';

import '../globals/app_constants.dart';
import 'mining_service.dart';

class BoostAdsService {
  BoostAdsService({
    MiningService? miningService,
  }) : _miningService = miningService ?? MiningService.instance;

  static final BoostAdsService instance = BoostAdsService();

  final MiningService _miningService;

  bool _initialized = false;
  bool _initializing = false;

  Completer<bool>? _showCompleter;

  int _adsWatched = 0;

  String get _sdkKey {
    if (Platform.isAndroid) {
      return _readConfigValue([
        'appLovinSdkKeyAndroid',
        'applovinSdkKeyAndroid',
        'appLovinSdkKey',
        'applovinSdkKey',
      ]);
    }

    return _readConfigValue([
      'appLovinSdkKeyIos',
      'applovinSdkKeyIos',
      'appLovinSdkKey',
      'applovinSdkKey',
    ]);
  }

  String get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return _readConfigValue([
        'appLovinRewardedAdUnitIdAndroid',
        'applovinRewardedAdUnitIdAndroid',
        'rewardedAdUnitIdAndroid',
        'androidRewardedAdUnitId',
      ]);
    }

    return _readConfigValue([
      'appLovinRewardedAdUnitIdIos',
      'applovinRewardedAdUnitIdIos',
      'rewardedAdUnitIdIos',
      'iosRewardedAdUnitId',
    ]);
  }

  String _readConfigValue(List<String> candidates) {
    /*
     * AppConfig is intentionally accessed through known field names
     * where available. If the project has not configured AppLovin yet,
     * this returns an empty value instead of crashing the application.
     */

    try {
      final dynamic config = AppConfig;

      for (final name in candidates) {
        try {
          final value = _readDynamicField(config, name);

          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        } catch (_) {
          // Try the next known field name.
        }
      }
    } catch (_) {
      // Configuration is unavailable.
    }

    return '';
  }

  dynamic _readDynamicField(dynamic object, String name) {
    /*
     * Dart does not provide normal runtime reflection in Flutter.
     * This method is intentionally kept as a safe fallback.
     *
     * The actual AppConfig constants should be wired explicitly once
     * AppLovin credentials are supplied.
     */
    return null;
  }

  bool get isConfigured {
    return _sdkKey.isNotEmpty && _rewardedAdUnitId.isNotEmpty;
  }

  bool get isInitialized => _initialized;

  int get adsWatched => _adsWatched;

  int get remainingAds {
    final remaining =
        AppConfig.maxAdsPerSession - _adsWatched;

    return remaining < 0 ? 0 : remaining;
  }

  double get currentAdBoost {
    return _miningService.calculateMaximumAdBoost(
      _adsWatched,
    );
  }

  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    if (_initializing) {
      return false;
    }

    if (!isConfigured) {
      return false;
    }

    _initializing = true;

    try {
      AppLovinMAX.setRewardedAdListener(
        RewardedAdListener(
          onAdLoadedCallback: (ad) {
            // Ad is ready.
          },
          onAdLoadFailedCallback: (adUnitId, error) {
            _completeShow(false);
          },
          onAdDisplayedCallback: (ad) {
            // Ad displayed.
          },
          onAdDisplayFailedCallback: (ad, error) {
            _completeShow(false);
          },
          onAdClickedCallback: (ad) {
            // Click does not grant FAN.
          },
          onAdHiddenCallback: (ad) {
            /*
             * If the reward callback was not received, do not
             * automatically grant a mining boost.
             */
            _completeShow(false);
          },
          onAdReceivedRewardCallback: (ad, reward) {
            _completeShow(true);
          },
          onAdRevenuePaidCallback: (ad) {
            // Revenue callback is informational only.
          },
        ),
      );

      final configuration =
          await AppLovinMAX.initialize(_sdkKey);

      if (configuration == null) {
        _initialized = false;
        return false;
      }

      _initialized = true;

      await _loadRewardedAd();

      return true;
    } catch (_) {
      _initialized = false;
      return false;
    } finally {
      _initializing = false;
    }
  }

  Future<void> _loadRewardedAd() async {
    if (!_initialized || _rewardedAdUnitId.isEmpty) {
      return;
    }

    try {
      await AppLovinMAX.loadRewardedAd(
        _rewardedAdUnitId,
      );
    } catch (_) {
      // Loading can be retried later.
    }
  }

  Future<bool> isRewardedAdReady() async {
    if (!_initialized || _rewardedAdUnitId.isEmpty) {
      return false;
    }

    try {
      final ready =
          await AppLovinMAX.isRewardedAdReady(
        _rewardedAdUnitId,
      );

      return ready == true;
    } catch (_) {
      return false;
    }
  }

  Future<int> getAdsWatchedForSession({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    try {
      final count =
          await _miningService.getAdsWatchedForSession(
        startedAt: startedAt,
        endsAt: endsAt,
      );

      _adsWatched = count.clamp(
        0,
        AppConfig.maxAdsPerSession,
      );

      return _adsWatched;
    } catch (_) {
      return _adsWatched;
    }
  }

  Future<Map<String, dynamic>> watchAdAndRecord({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    if (remainingAds <= 0) {
      return <String, dynamic>{
        'success': false,
        'message':
            'You have reached the maximum of ${AppConfig.maxAdsPerSession} ads for this mining session.',
        'ads_watched': _adsWatched,
        'remaining_ads': 0,
        'ad_boost': currentAdBoost,
      };
    }

    if (!isConfigured) {
      return <String, dynamic>{
        'success': false,
        'message':
            'Rewarded ads are not configured yet.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    final initialized = await initialize();

    if (!initialized) {
      return <String, dynamic>{
        'success': false,
        'message':
            'Rewarded ads are temporarily unavailable.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    final ready = await isRewardedAdReady();

    if (!ready) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'Rewarded ad is not ready. Please try again.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    final rewarded = await _showRewardedAd();

    if (!rewarded) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'The ad was not completed, so no mining boost was added.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }

    /*
     * The client only records the completion after MAX reports
     * that the reward was earned.
     *
     * The authoritative server-side S2S callback should still be
     * enabled in AppLovin before production release.
     */
    try {
      final result =
          await _miningService.recordRewardedAd();

      final success =
          result['success'] == true ||
          result['recorded'] == true ||
          result['ok'] == true;

      if (!success) {
        return <String, dynamic>{
          'success': false,
          'message':
              result['message']?.toString() ??
                  'The ad reward could not be recorded.',
          'ads_watched': _adsWatched,
          'remaining_ads': remainingAds,
          'ad_boost': currentAdBoost,
        };
      }

      final returnedCount = result['ads_watched'];

      if (returnedCount is num) {
        _adsWatched = returnedCount.toInt().clamp(
              0,
              AppConfig.maxAdsPerSession,
            );
      } else {
        _adsWatched++;
      }

      await _loadRewardedAd();

      return <String, dynamic>{
        'success': true,
        'message':
            '+${AppConfig.adBoostPerAd.toStringAsFixed(2)} FAN/H mining boost added.',
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
        'reward_rate': AppConfig.adBoostPerAd,
      };
    } catch (error) {
      await _loadRewardedAd();

      return <String, dynamic>{
        'success': false,
        'message':
            'The ad was completed, but the server could not record the reward.',
        'error': error.toString(),
        'ads_watched': _adsWatched,
        'remaining_ads': remainingAds,
        'ad_boost': currentAdBoost,
      };
    }
  }

  Future<bool> _showRewardedAd() async {
    if (_showCompleter != null) {
      return false;
    }

    final completer = Completer<bool>();
    _showCompleter = completer;

    try {
      AppLovinMAX.showRewardedAd(
        _rewardedAdUnitId,
      );

      return await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      _completeShow(false);
      return false;
    } finally {
      _showCompleter = null;
    }
  }

  void _completeShow(bool rewarded) {
    final completer = _showCompleter;

    if (completer == null || completer.isCompleted) {
      return;
    }

    completer.complete(rewarded);
  }

  Future<void> refreshSessionCount({
    required DateTime startedAt,
    DateTime? endsAt,
  }) async {
    await getAdsWatchedForSession(
      startedAt: startedAt,
      endsAt: endsAt,
    );
  }

  void resetLocalState() {
    _adsWatched = 0;
  }
}
