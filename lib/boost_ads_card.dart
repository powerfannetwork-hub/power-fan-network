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

  final LevelPlayAdsService _ads =
      LevelPlayAdsService.instance;

  final MiningService _mining =
      MiningService.instance;

  bool _loading = true;
  bool _watching = false;
  bool _adReady = false;

  int _adsWatched = 0;
  double _miningRate = 0.20;

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
      await _ads.loadRewardedAd();
      await _refresh();
    } catch (e) {
      debugPrint(
        'Boost Ads initialization error: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    try {
      final adsWatched =
          await _mining.getAdsWatched();

      final rate =
          await _mining.getUserMiningRate();

      final ready =
          await _ads.isRewardedAdReady();

      if (!mounted) return;

      setState(() {
        _adsWatched = adsWatched.clamp(0, 7);
        _miningRate =
            rate > 0 ? rate : 0.20;
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

    if (_adsWatched >= 7) {
      _showMessage(
        'You have reached the 7 Boost Ads limit for this mining session.',
      );
      return;
    }

    if (!_adReady) {
      await _ads.loadRewardedAd();

      if (!mounted) return;

      final ready =
          await _ads.isRewardedAdReady();

      if (!ready) {
        _showMessage(
          'Rewarded Ad is still loading. Please try again.',
        );
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _watching = true;
    });

    try {
      final shown =
          await _ads.showRewardedAd(
        onRewarded: () async {
          await _refresh();

          if (!mounted) return;

          widget.onRewarded?.call();
        },
        onAdClosed: () async {
          await _refresh();

          if (!mounted) return;

          setState(() {
            _watching = false;
          });
        },
      );

      if (!shown) {
        if (!mounted) return;

        setState(() {
          _watching = false;
        });

        await _refresh();

        if (!mounted) return;

        _showMessage(
          'Rewarded Ad is not ready yet. Please try again.',
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

  void _showMessage(
    String message,
  ) {
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
        (7 - _adsWatched).clamp(0, 7);

    final canWatch =
        widget.isMining &&
        !_watching &&
        !_loading &&
        _adsWatched < 7 &&
        _adReady;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
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
                        fontWeight:
                            FontWeight.w800,
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
                  '$_adsWatched/7',
                  style: const TextStyle(
                    color: primaryPurple,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
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
                      const Text(
                        '+0.10 FAN/H',
                        style: TextStyle(
                          color: deepPurple,
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Current rate: '
                        '${_miningRate.toStringAsFixed(2)} FAN/H',
                        style:
                            const TextStyle(
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
              fontWeight:
                  FontWeight.w600,
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
                    WidgetStateProperty.resolveWith<Color?>(
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
                    WidgetStateProperty.resolveWith<Color?>(
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
                    const WidgetStatePropertyAll<double>(0),
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
                _watching
                    ? 'REWARD PROCESSING...'
                    : !widget.isMining
                        ? 'START MINING FIRST'
                        : _adsWatched >= 7
                            ? '7/7 ADS COMPLETED'
                            : !_adReady
                                ? 'LOADING AD...'
                                : 'WATCH AD +0.10 FAN/H',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
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
