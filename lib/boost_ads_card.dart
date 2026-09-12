import 'package:flutter/material.dart';

import 'services/levelplay_ads_service.dart';
import 'services/mining_service.dart';

class BoostAdsCard extends StatefulWidget {
  final bool isMining;
  final VoidCallback? onRewarded;
  final Future<void> Function()? onWatchAd;

  const BoostAdsCard({
    super.key,
    required this.isMining,
    this.onRewarded,
    this.onWatchAd,
  });

  @override
  State<BoostAdsCard> createState() => _BoostAdsCardState();
}

class _BoostAdsCardState extends State<BoostAdsCard> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);

  static const int maxAdsPerSession = 7;
  static const double defaultMiningRate = 0.20;
  static const double boostPerAd = 0.10;

  final LevelPlayAdsService _ads =
      LevelPlayAdsService.instance;

  final MiningService _mining =
      MiningService.instance;

  bool _loading = true;
  bool _watching = false;
  bool _adReady = false;

  int _adsWatched = 0;
  double _miningRate = defaultMiningRate;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(
    covariant BoostAdsCard oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isMining != widget.isMining) {
      _refresh();
    }
  }

  Future<void> _initialize() async {
    try {
      await _ads.initialize();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      await _refresh();

      // Load rewarded ad in the background.
      // Do not block the whole Boost card waiting for the ad.
      _prepareRewardedAd();
    } catch (e) {
      debugPrint(
        'Boost Ads initialization error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _prepareRewardedAd() async {
    try {
      final ready =
          await _ads.isRewardedAdReady();

      if (ready) {
        if (!mounted) return;

        setState(() {
          _adReady = true;
        });

        return;
      }

      debugPrint(
        'Boost Ads: rewarded ad is not ready. Loading...',
      );

      await _ads.loadRewardedAd();

      if (!mounted) return;

      final readyAfterLoad =
          await _ads.isRewardedAdReady();

      if (!mounted) return;

      setState(() {
        _adReady = readyAfterLoad;
      });

      debugPrint(
        'Boost Ads: rewarded ad ready = $readyAfterLoad',
      );
    } catch (e) {
      debugPrint(
        'Boost Ads prepare error: $e',
      );

      if (!mounted) return;

      setState(() {
        _adReady = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    try {
      final adsWatched =
          await _mining.getAdsWatched();

      final rate =
          await _mining.getUserMiningRate();

      bool ready = false;

      try {
        ready =
            await _ads.isRewardedAdReady();
      } catch (e) {
        debugPrint(
          'Boost Ads readiness check error: $e',
        );
      }

      if (!mounted) return;

      setState(() {
        _adsWatched = adsWatched.clamp(
          0,
          maxAdsPerSession,
        );

        _miningRate =
            rate > 0 ? rate : defaultMiningRate;

        _adReady = ready;
      });
    } catch (e) {
      debugPrint(
        'Boost Ads refresh error: $e',
      );
    }
  }

  Future<void> _watchAd() async {
    if (_watching) return;

    if (!widget.isMining) {
      _showMessage(
        'Start mining before watching a Boost Ad.',
      );
      return;
    }

    await _refresh();

    if (!mounted) return;

    if (_adsWatched >= maxAdsPerSession) {
      _showMessage(
        'You have reached the 7 Boost Ads limit for this mining session.',
      );
      return;
    }

    setState(() {
      _watching = true;
    });

    try {
      /*
       * If HomeScreen supplied its own ad callback,
       * use it. This prevents this card from creating
       * a second competing ad flow.
       */
      if (widget.onWatchAd != null) {
        await widget.onWatchAd!();

        if (!mounted) return;

        await _waitForRewardToBeRecorded();

        if (!mounted) return;

        widget.onRewarded?.call();

        return;
      }

      /*
       * Otherwise use LevelPlayAdsService directly.
       */

      // First try to use an already loaded ad.
      bool ready =
          await _ads.isRewardedAdReady();

      // If not ready, explicitly load it now.
      if (!ready) {
        debugPrint(
          'Boost Ads: ad not ready, loading before show...',
        );

        await _ads.loadRewardedAd();

        if (!mounted) return;

        ready =
            await _ads.isRewardedAdReady();
      }

      if (!ready) {
        if (!mounted) return;

        _showMessage(
          'Rewarded Ad is not available yet. Please try again.',
        );

        return;
      }

      if (!mounted) return;

      bool rewarded = false;

      final shown =
          await _ads.showRewardedAd(
        onRewarded: () async {
          rewarded = true;

          debugPrint(
            'Boost Ads: LevelPlay reward callback received.',
          );

          // Give the backend/S2S flow a little time
          // to record the ad reward.
          await _waitForRewardToBeRecorded();

          if (!mounted) return;

          widget.onRewarded?.call();
        },
        onAdClosed: () async {
          debugPrint(
            'Boost Ads: rewarded ad closed.',
          );

          await _refresh();

          if (!mounted) return;

          setState(() {
            _watching = false;
          });
        },
      );

      if (!mounted) return;

      if (!shown) {
        setState(() {
          _watching = false;
        });

        await _refresh();

        if (!mounted) return;

        _showMessage(
          'Rewarded Ad could not be shown. Please try again.',
        );

        return;
      }

      /*
       * Some LevelPlay/S2S flows deliver the reward
       * shortly after the ad has closed.
       *
       * If the callback already fired, _waitForRewardToBeRecorded()
       * above has handled it.
       */
      if (!rewarded) {
        await _waitForRewardToBeRecorded();
      }

      if (!mounted) return;

      setState(() {
        _watching = false;
      });

      await _refresh();

      if (!mounted) return;

      if (_adsWatched > 0) {
        debugPrint(
          'Boost Ads: current ads watched = $_adsWatched',
        );
      }
    } catch (e) {
      debugPrint(
        'Boost rewarded ad error: $e',
      );

      if (!mounted) return;

      setState(() {
        _watching = false;
      });

      _showMessage(
        'Unable to show the rewarded ad. Please try again.',
      );
    }
  }

  Future<void> _waitForRewardToBeRecorded() async {
    int previousCount = _adsWatched;

    for (int i = 0; i < 15; i++) {
      await Future<void>.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      try {
        final currentCount =
            await _mining.getAdsWatched();

        debugPrint(
          'Boost Ads reward check ${i + 1}/15: '
          '$previousCount -> $currentCount',
        );

        if (currentCount > previousCount) {
          if (!mounted) return;

          final rate =
              await _mining.getUserMiningRate();

          if (!mounted) return;

          setState(() {
            _adsWatched =
                currentCount.clamp(
              0,
              maxAdsPerSession,
            );

            _miningRate =
                rate > 0 ? rate : defaultMiningRate;

            _adReady = false;
          });

          // Load the next ad for the next click.
          _prepareRewardedAd();

          debugPrint(
            'Boost Ads: reward recorded successfully. '
            'Ads watched = $_adsWatched, '
            'rate = $_miningRate',
          );

          return;
        }

        if (!mounted) return;

        setState(() {
          _adsWatched =
              currentCount.clamp(
            0,
            maxAdsPerSession,
          );
        });
      } catch (e) {
        debugPrint(
          'Boost Ads reward polling error: $e',
        );
      }
    }

    // Final refresh even if S2S took longer than expected.
    await _refresh();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        (maxAdsPerSession - _adsWatched)
            .clamp(0, maxAdsPerSession);

    /*
     * IMPORTANT:
     *
     * _adReady is intentionally NOT required here.
     *
     * The user must be able to press Watch Ad even
     * while LevelPlay is loading. _watchAd() will
     * attempt to load the ad.
     */
    final canWatch =
        widget.isMining &&
        !_watching &&
        !_loading &&
        _adsWatched < maxAdsPerSession;

    String buttonText;

    if (_watching) {
      buttonText = 'REWARD PROCESSING...';
    } else if (!widget.isMining) {
      buttonText = 'START MINING FIRST';
    } else if (_adsWatched >= maxAdsPerSession) {
      buttonText = '7/7 ADS COMPLETED';
    } else if (_adReady) {
      buttonText = 'WATCH AD +0.10 FAN/H';
    } else {
      buttonText = 'WATCH AD +0.10 FAN/H';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryPurple.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: primaryPurple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boost Mining',
                      style: TextStyle(
                        color: deepPurple,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rewarded Ads',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: primaryPurple.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  '$_adsWatched/$maxAdsPerSession',
                  style: const TextStyle(
                    color: primaryPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FC),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: primaryPurple,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${boostPerAd.toStringAsFixed(2)} FAN/H',
                        style: const TextStyle(
                          color: deepPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current rate: '
                        '${_miningRate.toStringAsFixed(2)} FAN/H',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 11),

          Text(
            '$remaining Boost Ads remaining this session',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed:
                  canWatch ? _watchAd : null,
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.resolveWith<
                        Color?>(
                  (states) {
                    if (states.contains(
                      WidgetState.disabled,
                    )) {
                      return Colors.grey.shade300;
                    }

                    return primaryPurple;
                  },
                ),
                foregroundColor:
                    WidgetStateProperty.resolveWith<
                        Color?>(
                  (states) {
                    if (states.contains(
                      WidgetState.disabled,
                    )) {
                      return Colors.grey.shade600;
                    }

                    return Colors.white;
                  },
                ),
                elevation:
                    const WidgetStatePropertyAll<double>(
                  0,
                ),
                shape:
                    WidgetStatePropertyAll<
                        OutlinedBorder>(
                  RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
              icon: _watching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.play_arrow_rounded,
                    ),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Each completed rewarded ad increases your mining rate by +0.10 FAN/H. Maximum 7 ads per mining session.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
