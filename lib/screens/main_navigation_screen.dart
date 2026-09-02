import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mining_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  final MiningService _miningService =
      MiningService.instance;

  /*
   * AppLovin MAX configuration.
   *
   * These must be replaced with the real values from
   * the AppLovin MAX dashboard before real rewarded ads
   * can be displayed.
   *
   * DO NOT use a fake SDK key or fake ad unit ID.
   */
  static const String _appLovinSdkKey = '';

  static const String _rewardedAdUnitId = '';

  int _currentIndex = 0;

  double _balance = 0.0;
  double _afamBalance = 0.0;
  double _miningRate = 0.2;

  /*
   * Rewarded ad count belongs to the current
   * 24-hour mining session.
   *
   * Maximum: 7 ads per session.
   */
  int _adsWatched = 0;

  bool _isMining = false;
  bool _loading = true;
  bool _busy = false;

  bool _appLovinInitialized = false;
  bool _rewardedAdLoading = false;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Timer? _timer;

  Completer<bool>? _adRewardCompleter;

  bool _waitingForClaimAd = false;
  bool _waitingForBoostAd = false;

  Duration get _sessionRemaining {
    if (_endsAt == null) {
      return Duration.zero;
    }

    final remaining =
        _endsAt!.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  Duration get _sessionElapsed {
    if (_startedAt == null) {
      return Duration.zero;
    }

    final elapsed =
        DateTime.now().difference(_startedAt!);

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return elapsed;
  }

  bool get _sessionFinished {
    if (!_isMining || _endsAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(_endsAt!);
  }

  @override
  void initState() {
    super.initState();

    _initializeRewardedAds();
    _loadDashboard();
  }

  @override
  void dispose() {
    _timer?.cancel();

    if (_adRewardCompleter != null &&
        !_adRewardCompleter!.isCompleted) {
      _adRewardCompleter!.complete(false);
    }

    super.dispose();
  }

  Future<void> _initializeRewardedAds() async {
    /*
     * We intentionally do not initialize AppLovin until the
     * real SDK key and rewarded ad unit ID are available.
     */
    if (_appLovinSdkKey.trim().isEmpty ||
        _rewardedAdUnitId.trim().isEmpty) {
      return;
    }

    try {
      AppLovinMAX.setRewardedAdListener(
        RewardedAdListener(
          onAdLoadedCallback: (ad) {
            _rewardedAdLoading = false;
          },
          onAdLoadFailedCallback: (adUnitId, error) {
            _rewardedAdLoading = false;

            if (_adRewardCompleter != null &&
                !_adRewardCompleter!.isCompleted) {
              _adRewardCompleter!.complete(false);
            }
          },
          onAdDisplayedCallback: (ad) {},
          onAdDisplayFailedCallback: (ad, error) {
            _rewardedAdLoading = false;

            if (_adRewardCompleter != null &&
                !_adRewardCompleter!.isCompleted) {
              _adRewardCompleter!.complete(false);
            }

            _loadRewardedAd();
          },
          onAdClickedCallback: (ad) {},
          onAdReceivedRewardCallback: (ad, reward) {
            /*
             * IMPORTANT:
             *
             * No FAN is awarded here directly.
             *
             * This callback only confirms that AppLovin
             * has granted the rewarded-ad reward.
             *
             * The actual database operation happens after
             * this Future completes.
             */
            if (_adRewardCompleter != null &&
                !_adRewardCompleter!.isCompleted) {
              _adRewardCompleter!.complete(true);
            }
          },
          onAdHiddenCallback: (ad) {
            /*
             * If the user closes/dismisses the ad without
             * receiving a reward, the pending operation fails.
             */
            if (_adRewardCompleter != null &&
                !_adRewardCompleter!.isCompleted) {
              _adRewardCompleter!.complete(false);
            }

            _loadRewardedAd();
          },
          onAdRevenuePaidCallback: (ad) {},
        ),
      );

      final configuration =
          await AppLovinMAX.initialize(
        _appLovinSdkKey,
      );

      if (configuration != null) {
        _appLovinInitialized = true;

        final user = Supabase
            .instance
            .client
            .auth
            .currentUser;

        if (user != null) {
          AppLovinMAX.setUserId(user.id);
        }

        _loadRewardedAd();
      }
    } catch (e) {
      _appLovinInitialized = false;
    }
  }

  Future<void> _loadRewardedAd() async {
    if (!_appLovinInitialized) {
      return;
    }

    if (_rewardedAdUnitId.trim().isEmpty) {
      return;
    }

    if (_rewardedAdLoading) {
      return;
    }

    try {
      final ready =
          await AppLovinMAX.isRewardedAdReady(
        _rewardedAdUnitId,
      );

      if (ready == true) {
        return;
      }

      _rewardedAdLoading = true;

      AppLovinMAX.loadRewardedAd(
        _rewardedAdUnitId,
      );
    } catch (e) {
      _rewardedAdLoading = false;
    }
  }

  Future<bool> _showRewardedAd() async {
    if (!_appLovinInitialized ||
        _rewardedAdUnitId.trim().isEmpty) {
      _showMessage(
        'Rewarded ads are not configured yet.',
      );
      return false;
    }

    try {
      final ready =
          await AppLovinMAX.isRewardedAdReady(
        _rewardedAdUnitId,
      );

      if (ready != true) {
        _loadRewardedAd();

        _showMessage(
          'Rewarded ad is loading. Please try again in a moment.',
        );

        return false;
      }

      if (_adRewardCompleter != null &&
          !_adRewardCompleter!.isCompleted) {
        return false;
      }

      final completer =
          Completer<bool>();

      _adRewardCompleter = completer;

      AppLovinMAX.showRewardedAd(
        _rewardedAdUnitId,
      );

      final rewarded =
          await completer.future;

      if (identical(
        _adRewardCompleter,
        completer,
      )) {
        _adRewardCompleter = null;
      }

      return rewarded;
    } catch (e) {
      if (_adRewardCompleter != null &&
          !_adRewardCompleter!.isCompleted) {
        _adRewardCompleter!.complete(false);
      }

      _adRewardCompleter = null;

      _loadRewardedAd();

      return false;
    }
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    String? firstError;

    try {
      await _loadProfile();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    try {
      await _loadMining();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    try {
      await _loadMiningRate();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    try {
      await _loadAdsCount();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    _startUiTimer();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }

    if (firstError != null && mounted) {
      _showMessage(firstError);
    }
  }

  Future<void> _loadProfile() async {
    final result =
        await _miningService.getProfile();

    final fan =
        result['fan_balance'] ??
        result['fanBalance'] ??
        0;

    final afam =
        result['afam_balance'] ??
        result['afamBalance'] ??
        0;

    if (!mounted) return;

    setState(() {
      _balance = _toDouble(fan);
      _afamBalance = _toDouble(afam);
    });
  }

  Future<void> _loadAdsCount() async {
    /*
     * Ads are counted only inside the current
     * 24-hour mining session.
     *
     * If there is no active mining session,
     * the next session starts at 0/7.
     */
    if (!_isMining || _startedAt == null) {
      if (!mounted) return;

      setState(() {
        _adsWatched = 0;
      });

      return;
    }

    final count =
        await _miningService.getAdsWatchedForSession(
      startedAt: _startedAt!,
    );

    if (!mounted) return;

    setState(() {
      _adsWatched = count.clamp(0, 7);
    });
  }

  Future<void> _loadMiningRate() async {
    final result =
        await _miningService.getUserMiningRate();

    final possibleRate = [
      result['rate'],
      result['mining_rate'],
      result['value'],
    ];

    for (final value in possibleRate) {
      if (value != null) {
        if (!mounted) return;

        setState(() {
          _miningRate = _toDouble(value);
        });

        return;
      }
    }
  }

  Future<void> _loadMining() async {
    final result =
        await _miningService.getActiveMining();

    final active =
        result['active'] == true ||
        result['is_active'] == true;

    if (!active) {
      if (!mounted) return;

      setState(() {
        _isMining = false;
        _startedAt = null;
        _endsAt = null;
        _adsWatched = 0;
      });

      return;
    }

    final started =
        _parseDate(result['started_at']);

    final ends =
        _parseDate(result['ends_at']);

    if (!mounted) return;

    setState(() {
      _isMining = true;
      _startedAt = started;
      _endsAt = ends;
    });
  }

  void _startUiTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        if (!mounted) return;

        if (_isMining &&
            _endsAt != null &&
            !DateTime.now().isBefore(_endsAt!)) {
          await _loadMining();
          await _loadProfile();
          await _loadMiningRate();
          await _loadAdsCount();
        }

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> _startMining() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _miningService.startMining();

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Unable to start mining.',
        );
        return;
      }

      /*
       * Load the newly-created session first.
       */
      await _loadMining();

      /*
       * Load the rate for the new session.
       */
      await _loadMiningRate();

      /*
       * IMPORTANT:
       *
       * A new 24-hour mining session starts with
       * its own ad counter.
       *
       * This therefore becomes 0/7 for a fresh session.
       */
      await _loadAdsCount();

      _showMessage(
        'Mining started successfully.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _claimMining() async {
    if (_busy) return;

    /*
     * Claim is impossible before the 24-hour session ends.
     */
    if (!_sessionFinished) {
      return;
    }

    /*
     * Prevent multiple claim attempts while the ad is open.
     */
    setState(() {
      _busy = true;
      _waitingForClaimAd = true;
    });

    try {
      /*
       * The claim button goes DIRECTLY into the rewarded ad.
       */
      final rewarded =
          await _showRewardedAd();

      if (!rewarded) {
        _showMessage(
          'The rewarded ad was not completed. Mining reward was not claimed.',
        );
        return;
      }

      /*
       * ONLY after AppLovin confirms the reward do we
       * call the database claim function.
       */
      final result =
          await _miningService.claimMining();

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Unable to claim mining reward.',
        );
        return;
      }

      await _loadProfile();
      await _loadMining();
      await _loadMiningRate();
      await _loadAdsCount();

      _showMessage(
        result['message']?.toString() ??
            'Mining reward claimed successfully.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _waitingForClaimAd = false;
        });
      }
    }
  }

  Future<void> _watchAd() async {
    if (_busy) return;

    /*
     * Ads can only be watched during an active
     * 24-hour mining session.
     */
    if (!_isMining) {
      _showMessage(
        'Start mining before watching boost ads.',
      );
      return;
    }

    /*
     * Once the 24-hour session is complete,
     * the user must claim the reward and start
     * a new mining session before watching more ads.
     */
    if (_sessionFinished) {
      _showMessage(
        'Mining session is complete. Claim your reward and start a new session before watching more ads.',
      );
      return;
    }

    /*
     * Maximum: 7 rewarded ads for ONE mining session.
     */
    if (_adsWatched >= 7) {
      _showMessage(
        'You have reached the 7 ads limit for this mining session.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _waitingForBoostAd = true;
    });

    try {
      /*
       * WATCH AD now opens the real rewarded ad directly.
       */
      final rewarded =
          await _showRewardedAd();

      if (!rewarded) {
        _showMessage(
          'The rewarded ad was not completed. No mining boost was added.',
        );
        return;
      }

      /*
       * The database is updated ONLY after AppLovin
       * confirms the reward.
       */
      final adReference =
          'mobile_${DateTime.now().millisecondsSinceEpoch}';

      final result =
          await _miningService.recordRewardedAd(
        adRef: adReference,
      );

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Unable to record rewarded ad.',
        );
        return;
      }

      /*
       * Reload the session-based ad count.
       */
      await _loadAdsCount();

      /*
       * Reload mining rate because the rewarded ad
       * changes the mining rate.
       */
      await _loadMiningRate();

      _showMessage(
        'Ad completed successfully. +0.1 FAN/H boost added.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _waitingForBoostAd = false;
        });
      }
    }
  }

  Future<void> _dailyCheckin() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _miningService.dailyCheckin();

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Daily check-in failed.',
        );
        return;
      }

      await _loadProfile();

      _showMessage(
        result['message']?.toString() ??
            'Daily check-in completed successfully.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadDashboard();
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    if (text.startsWith('PostgrestException: ')) {
      text = text.substring(19);
    }

    return text.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : text.trim();
  }

  String _formatDuration(Duration duration) {
    final hours =
        duration.inHours
            .toString()
            .padLeft(2, '0');

    final minutes =
        duration.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        duration.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      _buildReferralPage(),
      _buildWalletPage(),
      _buildSettingsPage(),
    ];

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F8FC),
      body: SafeArea(
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      Color(0xFF4A20B9),
                ),
              )
            : pages[_currentIndex],
      ),
      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: const Color(0xFF4A20B9),
      onRefresh: _refresh,
      child: CustomScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverPadding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              24,
            ),
            sliver: SliverList(
              delegate:
                  SliverChildListDelegate(
                [
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  _buildMiningCard(),
                  const SizedBox(height: 14),
                  _buildAdsCard(),
                  const SizedBox(height: 14),
                  _buildDailyTaskCard(),
                  const SizedBox(height: 14),
                  _buildKycCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(15),
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xFF5B2BD9),
                  Color(0xFF32148E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xFF3B159B)
                          .withOpacity(0.22),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'POWER FAN',
                  style: TextStyle(
                    color:
                        Color(0xFF35148F),
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                Text(
                  'Mine FAN. Earn More',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior:
                Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  _showMessage(
                    'No new notifications.',
                  );
                },
                icon: const Icon(
                  Icons
                      .notifications_none_rounded,
                  size: 31,
                  color:
                      Color(0xFF28116F),
                ),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration:
                      const BoxDecoration(
                    color: Colors.red,
                    shape:
                        BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      height: 178,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(25),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF4820B7),
            Color(0xFF291075),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF35128D)
                    .withOpacity(0.28),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 15,
            bottom: 5,
            child:
                _buildMiningCharacter(),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              21,
              15,
              18,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 53,
                      height: 53,
                      decoration:
                          const BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            Color(0xFFFFB800),
                      ),
                      child:
                          const Icon(
                        Icons
                            .star_rounded,
                        color:
                            Color(0xFFE88700),
                        size: 35,
                      ),
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    Flexible(
                      child: Text(
                        _balance
                            .toStringAsFixed(
                          4,
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 37,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    const Text(
                      'FAN',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'AFAM ${_afamBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.85),
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCharacter() {
    return SizedBox(
      width: 155,
      height: 140,
      child: Stack(
        alignment:
            Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 2,
            right: 0,
            child: Container(
              width: 76,
              height: 76,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    const Color(
                  0xFF743BDF,
                ).withOpacity(0.75),
              ),
              child: const Center(
                child: Icon(
                  Icons.bolt_rounded,
                  color:
                      Color(0xFFFFC400),
                  size: 48,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            left: 17,
            child: Transform.rotate(
              angle: -0.65,
              child: Container(
                width: 84,
                height: 13,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF7B4B2A,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 29,
            left: 7,
            child: Transform.rotate(
              angle: -0.65,
              child: const Icon(
                Icons
                    .construction_rounded,
                color:
                    Color(0xFFE7D4FF),
                size: 45,
              ),
            ),
          ),
          Positioned(
            top: 1,
            left: 42,
            child: Container(
              width: 73,
              height: 73,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFF4A261),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Column(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      _Eye(),
                      SizedBox(width: 11),
                      _Eye(),
                    ],
                  ),
                  SizedBox(height: 8),
                  Icon(
                    Icons
                        .sentiment_satisfied_alt_rounded,
                    color:
                        Color(0xFF32148E),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 55,
            left: 30,
            child: Container(
              width: 98,
              height: 78,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFF5323B7),
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      Radius.circular(28),
                  topRight:
                      Radius.circular(28),
                  bottomLeft:
                      Radius.circular(15),
                  bottomRight:
                      Radius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    final remaining =
        _sessionRemaining;

    final elapsed =
        _sessionElapsed;

    final sessionText =
        _isMining
            ? _sessionFinished
                ? '24:00:00'
                : _formatDuration(
                    elapsed,
                  )
            : '00:00:00';

    /*
     * IMPORTANT:
     *
     * Before 24 hours:
     * MINING...
     *
     * After 24 hours:
     * CLAIM MINING
     *
     * When there is no active session:
     * START MINING
     */
    final buttonLabel =
        _busy
            ? _waitingForClaimAd
                ? 'WATCHING AD...'
                : _waitingForBoostAd
                    ? 'WATCHING AD...'
                    : 'PLEASE WAIT...'
            : !_isMining
                ? 'START MINING'
                : _sessionFinished
                    ? 'CLAIM MINING'
                    : 'MINING...';

    final buttonEnabled =
        !_busy &&
        (!_isMining || _sessionFinished);

    return _whiteCard(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.handyman_rounded,
                const Color(0xFFEAE5FF),
                const Color(0xFF4520AA),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'STATUS: ',
                          style:
                              TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        Text(
                          _isMining
                              ? 'MINING'
                              : 'READY',
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF159B61,
                            ),
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMining
                          ? _sessionFinished
                              ? 'Mining session completed'
                              : 'Mining FAN right now'
                          : 'Start mining to earn FAN',
                      style:
                          TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Divider(
            color:
                Colors.grey.shade200,
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miningInfo(
                  Icons.speed_rounded,
                  'MINING RATE',
                  '${_miningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              Container(
                width: 1,
                height: 58,
                color:
                    Colors.grey.shade200,
              ),
              Expanded(
                child: _miningInfo(
                  Icons.access_time_rounded,
                  'SESSION TIME',
                  '$sessionText / 24:00:00',
                ),
              ),
            ],
          ),
          if (_isMining) ...[
            const SizedBox(height: 10),
            Text(
              _sessionFinished
                  ? 'Session completed. You can claim your mining reward now.'
                  : 'Time remaining: ${_formatDuration(remaining)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    _sessionFinished
                        ? const Color(
                            0xFF159B61,
                          )
                        : Colors.black54,
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 58,
            child:
                ElevatedButton.icon(
              onPressed:
                  buttonEnabled
                      ? _isMining
                          ? _claimMining
                          : _startMining
                      : null,
              icon: Icon(
                _busy
                    ? Icons
                        .hourglass_top_rounded
                    : !_isMining
                        ? Icons
                            .hardware_rounded
                        : _sessionFinished
                            ? Icons
                                .card_giftcard_rounded
                            : Icons
                                .access_time_rounded,
                size: 26,
              ),
              label: Text(
                buttonLabel,
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF4A20B9,
                ),
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    const Color(
                  0xFF8D76CF,
                ),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miningInfo(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                const Color(0xFF3C169B),
            size: 43,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Color(0xFF341490),
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsCard() {
    final progress =
        (_adsWatched / 7)
            .clamp(0.0, 1.0);

    /*
     * Ad boost is calculated from the number of ads
     * watched in THIS mining session only.
     *
     * Referral mining bonuses are intentionally not
     * included in this display.
     */
    final boost =
        (_adsWatched * 0.1)
            .clamp(0.0, 0.7);

    /*
     * WATCH AD is available only while:
     *
     * 1. Mining session is active.
     * 2. Session has not finished.
     * 3. Fewer than 7 ads have been watched.
     * 4. No other operation is busy.
     */
    final canWatchAd =
        !_busy &&
        _isMining &&
        !_sessionFinished &&
        _adsWatched < 7;

    return _whiteCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIcon(
                Icons
                    .rocket_launch_rounded,
                const Color(0xFFF0EBFF),
                const Color(0xFFE64949),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style:
                          TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style:
                          TextStyle(
                        fontSize: 13,
                        color:
                            Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 49,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      canWatchAd
                          ? _watchAd
                          : null,
                  icon:
                      const Icon(
                    Icons
                        .video_collection_rounded,
                    size: 20,
                  ),
                  label:
                      Text(
                    _waitingForBoostAd
                        ? 'WATCHING'
                        : 'WATCH AD',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF4A20B9,
                    ),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        const Color(
                      0xFF8D76CF,
                    ),
                    disabledForegroundColor:
                        Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 14,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            'Ads watched this session: $_adsWatched / 7',
            style:
                const TextStyle(
              color:
                  Color(0xFF35148F),
              fontSize: 14,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  const Color(
                0xFFE9E4FA,
              ),
              valueColor:
                  const AlwaysStoppedAnimation(
                Color(0xFF5A2AD0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment:
                Alignment.centerRight,
            child: Text(
              '+${boost.toStringAsFixed(1)} FAN/H',
              style:
                  const TextStyle(
                color:
                    Color(0xFF35148F),
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskCard() {
    return _whiteCard(
      child: Row(
        children: [
          _circleIcon(
            Icons
                .assignment_turned_in_rounded,
            const Color(0xFFE8F8F0),
            const Color(0xFF159B61),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY TASK',
                  style:
                      TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Follow us on social media',
                  style:
                      TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Follow and get 10 FAN reward',
                  style:
                      TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _socialIcon('X'),
                  const SizedBox(
                    width: 6,
                  ),
                  _socialIcon('T'),
                  const SizedBox(
                    width: 6,
                  ),
                  _socialIcon('I'),
                  const SizedBox(
                    width: 6,
                  ),
                  _socialIcon('Y'),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 42,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _dailyCheckin,
                  icon:
                      const Icon(
                    Icons
                        .card_giftcard_rounded,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'FOLLOW & EARN',
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        const Color(
                      0xFF35148F,
                    ),
                    side:
                        const BorderSide(
                      color:
                          Color(0xFF35148F),
                      width: 1.3,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
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

  Widget _socialIcon(String letter) {
    return Container(
      width: 36,
      height: 36,
      decoration:
          BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Center(
        child: Text(
          letter,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildKycCard() {
    return _whiteCard(
      child: Row(
        children: [
          _circleIcon(
            Icons
                .verified_user_rounded,
            const Color(0xFFECE8FF),
            const Color(0xFF4320A5),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC VERIFICATION',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify your identity to secure your account',
                  style:
                      TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              _showMessage(
                'KYC verification is Coming Soon.',
              );
            },
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  const Color(
                0xFF35148F,
              ),
              side:
                  const BorderSide(
                color:
                    Color(0xFF35148F),
                width: 1.3,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 13,
                vertical: 12,
              ),
            ),
            child: const Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'COMPLETE KYC',
                  style:
                      TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons
                      .chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.045,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _circleIcon(
    IconData icon,
    Color background,
    Color foreground,
  ) {
    return Container(
      width: 58,
      height: 58,
      decoration:
          BoxDecoration(
        color: background,
        shape:
            BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: foreground,
        size: 31,
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration:
          BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.07,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            8,
            7,
            8,
            6,
          ),
          child: Row(
            children: [
              _navItem(
                index: 0,
                icon:
                    Icons.home_rounded,
                label: 'HOME',
              ),
              _navItem(
                index: 1,
                icon:
                    Icons.groups_rounded,
                label: 'REFERRAL',
              ),
              _navItem(
                index: 2,
                icon:
                    Icons
                        .account_balance_wallet_rounded,
                label: 'WALLET',
              ),
              _navItem(
                index: 3,
                icon:
                    Icons.settings_rounded,
                label: 'SETTINGS',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected =
        _currentIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            vertical: 5,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 29,
                color: selected
                    ? const Color(
                        0xFF4A20B9,
                      )
                    : const Color(
                        0xFF606060,
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style:
                    TextStyle(
                  color: selected
                      ? const Color(
                          0xFF35148F,
                        )
                      : const Color(
                          0xFF606060,
                        ),
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight
                          .w900
                      : FontWeight
                          .w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralPage() {
    return _simplePage(
      icon:
          Icons.groups_rounded,
      title: 'REFERRAL',
      subtitle:
          'Invite friends and grow your FAN mining rate.',
      child: Column(
        children: [
          _infoBox(
            'Referral reward',
            '5 FAN',
            Icons
                .card_giftcard_rounded,
          ),
          const SizedBox(height: 12),
          _infoBox(
            'New user reward',
            '20 FAN',
            Icons
                .person_add_alt_1_rounded,
          ),
          const SizedBox(height: 12),
          _infoBox(
            'Mining boost',
            '+0.02 FAN/H per active referral',
            Icons.speed_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletPage() {
    return _simplePage(
      icon:
          Icons
              .account_balance_wallet_rounded,
      title: 'WALLET',
      subtitle:
          'Your AFAM wallet will be available soon.',
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(25),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color:
                  Color(0xFF4320A5),
              size: 58,
            ),
            const SizedBox(height: 15),
            const Text(
              'COMING SOON',
              style:
                  TextStyle(
                color:
                    Color(0xFF4320A5),
                fontSize: 20,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AFAM Balance: ${_afamBalance.toStringAsFixed(2)}',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return _simplePage(
      icon:
          Icons.settings_rounded,
      title: 'SETTINGS',
      subtitle:
          'Manage your POWER FAN account.',
      child: Column(
        children: [
          _settingsItem(
            Icons
                .person_outline_rounded,
            'Profile',
            'Manage your account information',
          ),
          _settingsItem(
            Icons
                .notifications_none_rounded,
            'Notifications',
            'Manage notifications',
          ),
          _settingsItem(
            Icons.language_rounded,
            'Language',
            'English',
          ),
          _settingsItem(
            Icons.security_rounded,
            'Security',
            'Account security',
          ),
          _settingsItem(
            Icons.info_outline_rounded,
            'About POWER FAN',
            'Version 1.0.0',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                OutlinedButton.icon(
              onPressed: () async {
                await Supabase
                    .instance
                    .client
                    .auth
                    .signOut();
              },
              icon:
                  const Icon(
                Icons.logout_rounded,
              ),
              label:
                  const Text(
                'LOG OUT',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simplePage({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        25,
        18,
        30,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 53,
                height: 53,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFEDE8FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF4320A5,
                  ),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF35148F,
                        ),
                        fontSize: 25,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _infoBox(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          _circleIcon(
            icon,
            const Color(0xFFEDE8FF),
            const Color(0xFF4320A5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style:
                      const TextStyle(
                    color:
                        Color(0xFF35148F),
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsItem(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Icon(
          icon,
          color:
              const Color(0xFF4320A5),
          size: 27,
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle:
            Text(subtitle),
        trailing:
            const Icon(
          Icons.chevron_right_rounded,
          color: Colors.black45,
        ),
        onTap: () {
          _showMessage(
            '$title will be connected soon.',
          );
        },
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 13,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF291075),
        borderRadius:
            BorderRadius.circular(8),
      ),
    );
  }
}
