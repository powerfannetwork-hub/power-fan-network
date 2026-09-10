import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/kyc_page.dart';
import '../services/kyc_service.dart';
import '../services/levelplay_ads_service.dart';
import '../services/mining_service.dart';
import '../services/social_task_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color pageBackground = Color(0xFFF8F8FC);

  static const Duration miningDuration = Duration(hours: 24);
  static const int maxAds = 7;

  final MiningService _mining = MiningService.instance;
  final SocialTaskService _social = SocialTaskService();
  final KycService _kyc = KycService();
  final LevelPlayAdsService _ads = LevelPlayAdsService.instance;

  Timer? _timer;

  bool _loading = true;
  bool _busy = false;
  bool _isMining = false;
  bool _canClaim = false;

  /*
   * True only while the claim button is waiting for
   * the rewarded ad to finish and be verified.
   */
  bool _claimAdWaiting = false;

  double _fan = 0.0;
  double _rate = MiningService.defaultMiningRate;
  double _sessionReward = 0.0;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Duration _remaining = Duration.zero;

  int _adsWatched = 0;

  List<DailySocialTask> _tasks = [];

  KycStatus _kycStatus = KycStatus.initial();

  @override
  void initState() {
    super.initState();

    unawaited(_load());
    unawaited(_ads.initialize());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      await Future.wait([
        _loadProfile(),
        _loadMining(),
        _loadTasks(),
        _loadKyc(),
      ]);
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final data = await _mining.getProfile();

    if (!mounted || data == null) {
      return;
    }

    setState(() {
      _fan = _toDouble(data['fan_balance']);
    });
  }

  Future<void> _loadMining() async {
    final data = await _mining.getActiveMining();

    final serverRate = await _mining.getUserMiningRate();

    final started = _parseDate(
      data['started_at'] ??
          data['start_time'] ??
          data['started'],
    );

    final ends = _parseDate(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'],
    );

    final claimable = data['claimable'] == true;

    final rate = _toDouble(
      data['mining_rate'] ??
          data['rate'] ??
          serverRate,
    );

    final ads = _toInt(
      data['ads_watched'] ??
          data['ad_count'] ??
          data['ads_count'],
    );

    final serverRemaining = _toInt(
      data['remaining_seconds'],
    );

    final serverReward = _toDouble(
      data['reward'],
    );

    DateTime? finalStarted = started;
    DateTime? finalEnds = ends;

    if (finalStarted == null && finalEnds != null) {
      finalStarted = finalEnds.subtract(miningDuration);
    }

    if (finalEnds == null && finalStarted != null) {
      finalEnds = finalStarted.add(miningDuration);
    }

    final now = DateTime.now();

    Duration remaining = Duration.zero;

    /*
     * Supabase server timestamps are the source of truth.
     */
    if (finalEnds != null) {
      remaining = finalEnds.difference(now);

      if (remaining.isNegative) {
        remaining = Duration.zero;
      }
    } else if (serverRemaining > 0) {
      remaining = Duration(seconds: serverRemaining);
    }

    if (remaining > miningDuration) {
      remaining = miningDuration;
    }

    final activeByTime =
        finalStarted != null &&
        finalEnds != null &&
        !finalStarted.isAfter(now) &&
        finalEnds.isAfter(now);

    final sessionFinished =
        finalEnds != null &&
        !finalEnds.isAfter(now);

    final effectiveRate =
        rate > 0
            ? rate
            : MiningService.defaultMiningRate;

    /*
     * Server reward is authoritative.
     *
     * While the session is active, if the server has not yet
     * returned a reward value, calculate a temporary live
     * display from elapsed time.
     */
    double liveReward = serverReward;

    if (liveReward <= 0 && activeByTime) {
      final elapsedSeconds =
          now.difference(finalStarted).inSeconds;

      if (elapsedSeconds > 0) {
        liveReward =
            (elapsedSeconds / 3600.0) *
                effectiveRate;
      }
    }

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining = activeByTime;

      _canClaim =
          claimable || sessionFinished;

      _rate = effectiveRate;

      _startedAt = finalStarted;
      _endsAt = finalEnds;

      _remaining = remaining;

      _sessionReward = liveReward;

      _adsWatched =
          ads.clamp(0, maxAds).toInt();

      /*
       * If Supabase says the session is active or claimable,
       * the UI is no longer waiting for the previous claim-ad
       * operation.
       */
      if (_isMining || _canClaim) {
        _claimAdWaiting = false;
      }
    });

    if (_isMining) {
      _startTimer();
    }
  }

  void _applyMiningResult(
    Map<String, dynamic> data,
  ) {
    final started = _parseDate(
      data['started_at'] ??
          data['start_time'] ??
          data['started'],
    );

    final ends = _parseDate(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'],
    );

    if (started == null && ends == null) {
      return;
    }

    final now = DateTime.now();

    DateTime? finalStarted = started;
    DateTime? finalEnds = ends;

    if (finalStarted == null && finalEnds != null) {
      finalStarted =
          finalEnds.subtract(miningDuration);
    }

    if (finalEnds == null && finalStarted != null) {
      finalEnds =
          finalStarted.add(miningDuration);
    }

    if (finalStarted == null || finalEnds == null) {
      return;
    }

    var remaining =
        finalEnds.difference(now);

    if (remaining.isNegative) {
      remaining = Duration.zero;
    }

    if (remaining > miningDuration) {
      remaining = miningDuration;
    }

    final active =
        !finalStarted.isAfter(now) &&
        finalEnds.isAfter(now);

    final returnedRate =
        _toDouble(
      data['mining_rate'] ??
          data['rate'],
    );

    final returnedReward =
        _toDouble(
      data['reward'],
    );

    setState(() {
      _startedAt = finalStarted;
      _endsAt = finalEnds;
      _remaining = remaining;

      _rate = returnedRate > 0
          ? returnedRate
          : _rate;

      if (returnedReward > 0) {
        _sessionReward = returnedReward;
      } else if (active) {
        _sessionReward = 0.0;
      }

      _isMining = active;

      _canClaim =
          !active &&
          remaining == Duration.zero;
    });

    if (_isMining) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final started = _startedAt;
        final ends = _endsAt;

        if (started == null || ends == null) {
          _timer?.cancel();
          return;
        }

        final now = DateTime.now();

        var remaining =
            ends.difference(now);

        if (remaining.isNegative) {
          remaining = Duration.zero;
        }

        if (remaining > miningDuration) {
          remaining = miningDuration;
        }

        /*
         * Live FAN display.
         *
         * This is display-only.
         * The actual claimed amount is calculated by Supabase.
         */
        if (remaining > Duration.zero) {
          final fanPerSecond =
              _rate / 3600.0;

          _sessionReward +=
              fanPerSecond;
        }

        final finished =
            remaining == Duration.zero;

        setState(() {
          _remaining = remaining;

          if (finished) {
            _isMining = false;
            _canClaim = true;
          }
        });

        if (finished) {
          _timer?.cancel();

          /*
           * Refresh from Supabase immediately when the
           * local countdown reaches zero.
           *
           * This lets the server confirm that the session
           * is really claimable.
           */
          unawaited(_loadMining());
        }
      },
    );
  }

  Future<void> _startMining() async {
    if (_busy || _isMining || _canClaim) {
      if (_canClaim && !_isMining && !_busy) {
        _message(
          'Please claim your completed mining session first.',
        );
      }

      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _mining.startMining();

      final success =
          result.isEmpty ||
          result['success'] == true;

      if (!success) {
        throw Exception(
          result['message'] ??
              result['error'] ??
              'Unable to start mining.',
        );
      }

      /*
       * Apply the authoritative start_mining() response
       * immediately.
       */
      if (result.isNotEmpty) {
        _applyMiningResult(result);
      }

      await _loadProfile();

      /*
       * Reload from Supabase so the UI gets the authoritative
       * mining state.
       */
      await _loadMining();

      if (!mounted) return;

      if (result['claim_required'] == true) {
        _message(
          'Claim your completed mining session before starting a new one.',
        );
      } else if (result['already_active'] == true) {
        _message(
          'Mining is already active.',
        );
      } else if (_isMining) {
        _message(
          'Mining started successfully.',
        );
      } else if (_canClaim) {
        _message(
          'Your mining session is ready to claim.',
        );
      } else {
        _message(
          'Mining started successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _claimMining() async {
    if (_busy || !_canClaim || _isMining) {
      return;
    }

    /*
     * Extra safety check:
     *
     * The app must not claim a session before its real
     * server-side end time.
     */
    final ends = _endsAt;

    if (ends != null &&
        DateTime.now().isBefore(ends)) {
      final difference =
          ends.difference(DateTime.now());

      if (mounted) {
        _message(
          'Mining is still active. ${_formatDuration(difference)} remaining.',
        );
      }

      await _loadMining();
      return;
    }

    setState(() {
      _busy = true;
      _claimAdWaiting = true;
    });

    try {
      /*
       * STEP 1:
       * Show LevelPlay rewarded ad before the mining claim.
       *
       * The existing LevelPlay service is responsible for
       * waiting for its server-side reward confirmation.
       */
      final adCompleted =
          Completer<bool>();

      var adCallbackReceived = false;

      final shown =
          await _ads.showRewardedAd(
        onRewarded: () {
          if (adCallbackReceived) {
            return;
          }

          adCallbackReceived = true;

          if (!adCompleted.isCompleted) {
            adCompleted.complete(true);
          }
        },
        onAdClosed: () {
          /*
           * Do not treat simply closing the ad as a successful
           * reward. The reward callback must be received.
           */
        },
      );

      if (!shown) {
        throw Exception(
          'Rewarded ad is not ready. Please try again.',
        );
      }

      /*
       * The LevelPlay service normally calls onRewarded only
       * after its S2S verification succeeds.
       *
       * Give the service time to deliver that callback.
       */
      final adVerified =
          await adCompleted.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => false,
      );

      if (!adVerified) {
        throw Exception(
          'Ad reward could not be verified. Your FAN was not claimed.',
        );
      }

      if (!mounted) return;

      /*
       * STEP 2:
       * Refresh mining state after the rewarded ad.
       */
      await _loadMining();

      if (!mounted) return;

      /*
       * The session must still be claimable.
       */
      if (_isMining || !_canClaim) {
        throw Exception(
          'Mining session is not ready to claim.',
        );
      }

      /*
       * STEP 3:
       * Claim only after the rewarded ad has been verified.
       */
      final result =
          await _mining.claimMining();

      final success =
          result.isEmpty ||
          result['success'] == true;

      if (!success) {
        throw Exception(
          result['message'] ??
              result['error'] ??
              'Unable to claim mining reward.',
        );
      }

      /*
       * STEP 4:
       * Refresh the actual FAN balance from Supabase.
       */
      await _loadProfile();
      await _loadMining();

      if (mounted) {
        _message(
          'Mining reward claimed successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _claimAdWaiting = false;
      });
    }
  }

  Future<void> _watchAd() async {
    if (_busy || !_isMining) {
      return;
    }

    if (_adsWatched >= maxAds) {
      _message(
        'You have reached the 7 ads limit.',
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final shown =
          await _ads.showRewardedAd(
        onRewarded: () {
          unawaited(_loadMining());
        },
        onAdClosed: () {
          if (!mounted) return;

          setState(() {
            _busy = false;
          });
        },
      );

      if (!shown && mounted) {
        _message(
          'Rewarded ad is not ready. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks =
          await _social.getDailyTasksForCard();

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _tasks = [];
      });
    }
  }

  Future<void> _socialAction() async {
    if (_busy) return;

    if (_tasks.isEmpty) {
      _message(
        'No social task is available right now.',
      );
      return;
    }

    final task = _tasks.first;

    if (task.claimed) {
      _message(
        'This social reward has already been claimed.',
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      if (task.canClaim) {
        await _social.claimReward(
          taskId: task.id,
        );

        await _loadProfile();
        await _loadTasks();

        if (mounted) {
          _message(
            '+${_formatFan(task.rewardFan)} FAN reward claimed.',
          );
        }

        return;
      }

      await _social.startTask(
        taskId: task.id,
      );

      final opened =
          await _social.openTaskUrl(
        task.url,
      );

      if (mounted) {
        if (opened) {
          _message(
            'Complete the social task, then return to claim your reward.',
          );
        } else {
          _message(
            'Unable to open the social task.',
          );
        }
      }

      await _loadTasks();
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _loadKyc() async {
    try {
      final status =
          await _kyc.getProgress();

      if (!mounted) return;

      setState(() {
        _kycStatus = status;
      });
    } catch (_) {
      /*
       * KYC must not stop HomeScreen loading.
       */
    }
  }

  Future<void> _openKyc() async {
    if (_busy) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KycPage(),
      ),
    );

    if (!mounted) return;

    await _loadKyc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryPurple,
          onRefresh: _load,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: primaryPurple,
                  ),
                )
              : ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    20,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildBalanceCard(),
                    const SizedBox(height: 12),
                    _buildMiningCard(),
                    const SizedBox(height: 12),
                    _buildBoostCard(),
                    const SizedBox(height: 12),
                    _buildSocialCard(),
                    const SizedBox(height: 12),
                    _buildKycCard(),
                    const SizedBox(height: 10),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primaryPurple,
            borderRadius:
                BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'AFAM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            children: [
              const Text(
                'POWER FAN NETWORK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryPurple,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Mine FAN. Earn More',
                style: TextStyle(
                  color: Colors.indigo.shade900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: deepPurple,
              size: 28,
            ),
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration:
                    const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final displayedBalance =
        _fan +
        (_isMining || _canClaim
            ? _sessionReward
            : 0.0);

    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4320B4),
            Color(0xFF29107A),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                primaryPurple.withValues(
              alpha: 0.18,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -25,
            child: Opacity(
              opacity: 0.22,
              child: const Icon(
                Icons.diamond_rounded,
                size: 125,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              15,
              18,
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                          const BoxDecoration(
                        color: Color(0xFFFFB600),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFF8C00),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        displayedBalance
                            .toStringAsFixed(8),
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'FAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '≈ \$0.00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 10,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha: 0.11,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.engineering_rounded,
                color: Colors.white,
                size: 43,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    final finished =
        _canClaim && !_isMining;

    final fanPerSecond =
        _rate / 3600.0;

    String buttonText;

    if (_claimAdWaiting) {
      buttonText = 'WATCHING AD...';
    } else if (_busy && finished) {
      buttonText = 'PROCESSING...';
    } else if (finished) {
      buttonText = 'CLAIM FAN';
    } else if (_isMining) {
      buttonText = 'MINING';
    } else {
      buttonText = 'START MINING';
    }

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                finished
                    ? Icons.check_circle_rounded
                    : _isMining
                        ? Icons.bolt_rounded
                        : Icons.construction_rounded,
                background:
                    const Color(0xFFF0EEFA),
                iconColor: primaryPurple,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w700,
                        ),
                        children: [
                          const TextSpan(
                            text: 'STATUS: ',
                          ),
                          TextSpan(
                            text: finished
                                ? 'CLAIMABLE'
                                : _isMining
                                    ? 'MINING'
                                    : 'READY',
                            style: TextStyle(
                              color: finished
                                  ? Colors.orange.shade700
                                  : _isMining
                                      ? primaryPurple
                                      : Colors.green.shade600,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      finished
                          ? 'Your 24-hour mining session is complete'
                          : _isMining
                              ? 'Mining FAN. Keep your session active'
                              : 'Start mining to earn FAN',
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miningInfo(
                  Icons.speed_rounded,
                  'MINING RATE',
                  '${_rate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: _miningInfo(
                  Icons.access_time_rounded,
                  'COUNTDOWN',
                  _formatDuration(_remaining),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Per second: ${fanPerSecond.toStringAsFixed(8)} FAN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: deepPurple,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : finished
                          ? _claimMining
                          : _isMining
                              ? null
                              : _startMining,
              icon: Icon(
                _claimAdWaiting
                    ? Icons.ondemand_video_rounded
                    : finished
                        ? Icons.card_giftcard_rounded
                        : _isMining
                            ? Icons.bolt_rounded
                            : Icons.construction_rounded,
                size: 19,
              ),
              label: Text(
                buttonText,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryPurple,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    primaryPurple.withValues(
                  alpha: 0.55,
                ),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                textStyle:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_claimAdWaiting) ...[
            const SizedBox(height: 8),
            const Text(
              'Please complete the rewarded ad. Your FAN will be claimed after the ad is verified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: deepPurple,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoostCard() {
    final progress =
        (_adsWatched / maxAds)
            .clamp(0.0, 1.0)
            .toDouble();

    final canWatch =
        _isMining &&
        !_busy &&
        _adsWatched < maxAds;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.rocket_launch_rounded,
                background:
                    const Color(0xFFF0EEFA),
                iconColor:
                    Colors.red.shade700,
                size: 50,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Color(0xFF55555F),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      canWatch
                          ? _watchAd
                          : null,
                  icon: const Icon(
                    Icons.ondemand_video_rounded,
                    size: 17,
                  ),
                  label: const Text(
                    'WATCH AD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty
                            .resolveWith(
                      (states) {
                        if (states.contains(
                          WidgetState.disabled,
                        )) {
                          return primaryPurple
                              .withValues(
                            alpha: 0.45,
                          );
                        }

                        return primaryPurple;
                      },
                    ),
                    foregroundColor:
                        const WidgetStatePropertyAll(
                      Colors.white,
                    ),
                    shape:
                        const WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.all(
                          Radius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                'Ads watched: $_adsWatched / $maxAds',
                style: const TextStyle(
                  color: deepPurple,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '+${(_adsWatched * 0.10).toStringAsFixed(1)} FAN/H',
                style: const TextStyle(
                  color: deepPurple,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor:
                  const Color(0xFFE7E2F8),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Align(
            alignment:
                Alignment.centerRight,
            child: Text(
              _isMining
                  ? '7 ads maximum per session'
                  : 'Start mining before watching ads',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard() {
    final task =
        _tasks.isNotEmpty
            ? _tasks.first
            : null;

    final reward =
        task?.rewardFan ?? 2.0;

    final taskLabel =
        task == null
            ? 'Follow us on social media'
            : task.title.isNotEmpty
                ? task.title
                : 'Complete today’s social task';

    return _card(
      child: Row(
        children: [
          _circleIcon(
            Icons.assignment_turned_in_rounded,
            background:
                const Color(0xFFEAF8F0),
            iconColor:
                Colors.green.shade700,
            size: 50,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY TASK',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  taskLabel,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF55555F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Reward: ${_formatFan(reward)} FAN',
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                        Color(0xFF55555F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _socialIcon('X'),
                  const SizedBox(width: 3),
                  _socialIcon('➤'),
                  const SizedBox(width: 3),
                  _socialIcon('◎'),
                  const SizedBox(width: 3),
                  _socialIcon('▶'),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _socialAction,
                  icon: const Icon(
                    Icons
                        .card_giftcard_rounded,
                    size: 15,
                  ),
                  label: Text(
                    task?.canClaim == true
                        ? 'CLAIM ${_formatFan(reward)}'
                        : 'FOLLOW & EARN',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        deepPurple,
                    side:
                        const BorderSide(
                      color:
                          primaryPurple,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        9,
                      ),
                    ),
                    textStyle:
                        const TextStyle(
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w700,
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

  Widget _buildKycCard() {
    final verified =
        _kycStatus.isVerified;

    return _card(
      child: Row(
        children: [
          _circleIcon(
            Icons.shield_rounded,
            background:
                const Color(0xFFF0EEFA),
            iconColor:
                primaryPurple,
            size: 50,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  verified
                      ? 'KYC VERIFIED'
                      : 'KYC VERIFICATION',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  verified
                      ? 'Your identity has been verified'
                      : 'Verify your identity to secure your account',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color:
                        Color(0xFF55555F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          OutlinedButton(
            onPressed:
                _busy ? null : _openKyc,
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  deepPurple,
              side:
                  const BorderSide(
                color: deepPurple,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(9),
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  verified
                      ? 'VIEW KYC'
                      : 'COMPLETE KYC',
                  style:
                      const TextStyle(
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  size: 17,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 9,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _circleIcon(
    IconData icon, {
    required Color background,
    required Color iconColor,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: iconColor,
        size: size * 0.54,
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
        horizontal: 6,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryPurple,
            size: 27,
          ),
          const SizedBox(width: 6),
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
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: deepPurple,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialIcon(String text) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style:
            const TextStyle(
          fontSize: 12,
          fontWeight:
              FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }

  String _formatDuration(
    Duration duration,
  ) {
    if (duration.isNegative) {
      duration = Duration.zero;
    }

    final hours =
        duration.inHours
            .toString()
            .padLeft(2, '0');

    final minutes =
        (duration.inMinutes % 60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        (duration.inSeconds % 60)
            .toString()
            .padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _formatFan(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  double _toDouble(
    dynamic value,
  ) {
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

  int _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final parsed =
        DateTime.tryParse(text);

    if (parsed != null) {
      return parsed.toLocal();
    }

    final numeric =
        num.tryParse(text);

    if (numeric == null) {
      return null;
    }

    final timestamp =
        numeric.toInt();

    if (timestamp.abs() >=
        100000000000) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        timestamp,
        isUtc: true,
      ).toLocal();
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    ).toLocal();
  }

  String _error(
    Object error,
  ) {
    final text =
        error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      return text.substring(11);
    }

    return text;
  }

  void _message(
    String message,
  ) {
    if (!mounted ||
        message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}
