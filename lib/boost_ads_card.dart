// lib/components/boost_ads_card.dart

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';

import '../services/mining_service.dart';

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

  /*
   * IMPORTANT:
   * Saka Ad Unit ID ɗinka na AppLovin MAX a nan.
   *
   * Android:
   *   Rewarded Ad Unit ID
   *
   * iOS:
   *   Rewarded Ad Unit ID
   */
  static const String _androidRewardedAdUnitId =
      'YOUR_ANDROID_REWARDED_AD_UNIT_ID';

  static const String _iosRewardedAdUnitId =
      'YOUR_IOS_REWARDED_AD_UNIT_ID';

  int _adsWatched = 0;
  bool _loading = false;

  String get _rewardedAdUnitId {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _iosRewardedAdUnitId;
    }

    return _androidRewardedAdUnitId;
  }

  @override
  void initState() {
    super.initState();
    _loadAdsCount();
  }

  @override
  void didUpdateWidget(covariant BoostAdsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isMining != widget.isMining) {
      _loadAdsCount();
    }
  }

  Future<void> _loadAdsCount() async {
    if (!widget.isMining) {
      if (!mounted) return;

      setState(() {
        _adsWatched = 0;
      });

      return;
    }

    try {
      final count =
          await MiningService.instance.getAdsWatched();

      if (!mounted) return;

      setState(() {
        _adsWatched = count.clamp(0, 7).toInt();
      });
    } catch (_) {
      // Kada network ya samu matsala, kada UI ya fadi.
    }
  }

  Future<void> _watchAd() async {
    if (_loading) return;

    if (!widget.isMining) {
      _showMessage(
        'Fara mining kafin ka kalli ad.',
      );
      return;
    }

    if (_adsWatched >= 7) {
      _showMessage(
        'Ka kammala ads 7 na wannan session.',
      );
      return;
    }

    final adUnitId = _rewardedAdUnitId;

    if (adUnitId.startsWith('YOUR_')) {
      _showMessage(
        'AppLovin Rewarded Ad Unit ID bai sa ba tukuna.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    String? adId;
    bool rewardReceived = false;
    bool verificationFinished = false;

    try {
      /*
       * 1. Tabbatar ad yana ready.
       */
      final isReady =
          await AppLovinMAX.isRewardedAdReady(
        adUnitId,
      );

      if (!isReady) {
        AppLovinMAX.loadRewardedAd(adUnitId);

        if (!mounted) return;

        _showMessage(
          'Ad bai shirya ba. Ka sake gwadawa kaɗan.',
        );

        return;
      }

      /*
       * 2. Record ad session a backend.
       *
       * BA a ƙara reward anan ba.
       * Wannan kawai yana samar da adId.
       */
      adId = await MiningService.instance
          .recordRewardedAd();

      /*
       * 3. Sanya listener domin mu jira
       *    actual rewarded callback.
       */
      AppLovinMAX.setRewardedAdListener(
        RewardedAdListener(
          onAdLoadedCallback: (ad) {
            // Ad ya load.
          },

          onAdLoadFailedCallback: (
            adUnitId,
            error,
          ) {
            if (!mounted) return;

            _showMessage(
              'An kasa load ɗin ad. Ka sake gwadawa.',
            );
          },

          onAdDisplayedCallback: (ad) {
            // Ad ya bayyana.
          },

          onAdDisplayFailedCallback: (
            ad,
            error,
          ) {
            if (!mounted) return;

            _showMessage(
              'An kasa nuna ad. Ka sake gwadawa.',
            );
          },

          onAdClickedCallback: (ad) {
            // User ya danna ad.
          },

          /*
           * MUHIMMIN PART:
           *
           * Wannan callback ne kawai yake tabbatar
           * cewa user ya sami rewarded ad.
           */
          onAdReceivedRewardCallback: (
            ad,
            reward,
          ) async {
            if (rewardReceived) return;

            rewardReceived = true;

            if (adId == null) {
              return;
            }

            try {
              /*
               * 4. Verify reward a backend.
               *
               * Wannan yana ƙara +0.1 FAN/H
               * idan backend ya tabbatar.
               */
              await MiningService.instance
                  .verifyRewardedAd(adId!);

              verificationFinished = true;

              await _loadAdsCount();

              if (!mounted) return;

              widget.onRewarded?.call();

              _showMessage(
                '+0.1 FAN/H boost an ƙara.',
              );
            } catch (e) {
              if (!mounted) return;

              _showMessage(
                _cleanError(e),
              );
            }
          },

          onAdHiddenCallback: (ad) {
            /*
             * Kada mu ba user reward a nan.
             *
             * Reward yana zuwa ne kawai daga
             * onAdReceivedRewardCallback.
             */
            if (!rewardReceived &&
                !verificationFinished &&
                mounted) {
              _showMessage(
                'Ba a kammala rewarded ad ba.',
              );
            }

            /*
             * Sake load na gaba.
             */
            AppLovinMAX.loadRewardedAd(
              adUnitId,
            );
          },
        ),
      );

      /*
       * 5. Nuna actual rewarded ad.
       */
      AppLovinMAX.showRewardedAd(
        adUnitId,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
      );
    } finally {
      /*
       * Kada loading ya makale.
       *
       * Amma idan ad yana kan screen,
       * button zai koma enabled bayan wannan.
       */
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
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

  String _cleanError(Object error) {
    var message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    if (message.startsWith('PostgrestException: ')) {
      message = message.substring(19);
    }

    return message.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : message.trim();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = 7 - _adsWatched;

    final canWatch =
        widget.isMining &&
        !_loading &&
        _adsWatched < 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.orange,
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Boost by Watching Ads',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  '+0.1 FAN/H per ad',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),

                if (widget.isMining &&
                    remaining > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '$remaining ads remaining',
                    style: const TextStyle(
                      color: primaryPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                if (!widget.isMining) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Start mining to boost your rate',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color:
                      primaryPurple.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  '$_adsWatched / 7',
                  style: const TextStyle(
                    color: primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 7),

              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed:
                      canWatch ? _watchAd : null,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryPurple,
                    disabledBackgroundColor:
                        Colors.grey.shade300,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 11,
                    ),
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(9),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _adsWatched >= 7
                              ? 'DONE'
                              : 'WATCH',
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
