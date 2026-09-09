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

  static const Duration miningDuration =
      Duration(hours: 24);

  static const int maxAds = 7;

  final MiningService _mining =
      MiningService.instance;

  final SocialTaskService _social =
      SocialTaskService();

  final KycService _kyc =
      KycService();

  final LevelPlayAdsService _ads =
      LevelPlayAdsService.instance;

  Timer? _timer;

  bool _loading = true;
  bool _busy = false;
  bool _isMining = false;
  bool _canClaim = false;

  double _fan = 0.0;

  double _rate =
      MiningService.defaultMiningRate;

  double _sessionReward = 0.0;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Duration _remaining = Duration.zero;
  Duration _elapsed = Duration.zero;

  int _adsWatched = 0;

  List<DailySocialTask> _tasks = [];

  KycStatus _kycStatus =
      KycStatus.initial();

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
    final data =
        await _mining.getProfile();

    if (!mounted || data == null) {
      return;
    }

    setState(() {
      _fan = _toDouble(
        data['fan_balance'],
      );
    });
  }

  Future<void> _loadMining() async {
    final data =
        await _mining.getActiveMining();

    final serverRate =
        await _mining.getUserMiningRate();

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

    final active =
        data['active'] ??
        data['is_mining'] ??
        data['mining_active'] ??
        data['is_active'] ??
        false;

    final claimable =
        data['claimable'] == true;

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

    final serverElapsed = _toInt(
      data['elapsed_seconds'],
    );

    final serverReward = _toDouble(
      data['reward'],
    );

    DateTime? finalStarted = started;
    DateTime? finalEnds = ends;

    if (finalStarted == null &&
        finalEnds != null) {
      finalStarted =
          finalEnds.subtract(
        miningDuration,
      );
    }

    if (finalEnds == null &&
        finalStarted != null) {
      finalEnds =
          finalStarted.add(
        miningDuration,
      );
    }

    Duration remaining =
        Duration.zero;

    Duration elapsed =
        Duration.zero;

    if (serverRemaining > 0) {
      remaining =
          Duration(
        seconds: serverRemaining,
      );
    } else if (finalEnds != null) {
      remaining =
          finalEnds.difference(
        DateTime.now(),
      );

      if (remaining.isNegative) {
        remaining = Duration.zero;
      }
    }

    if (serverElapsed > 0) {
      elapsed =
          Duration(
        seconds: serverElapsed,
      );
    } else if (finalStarted != null) {
      elapsed =
          DateTime.now().difference(
        finalStarted,
      );

      if (elapsed.isNegative) {
        elapsed = Duration.zero;
      }
    }

    if (elapsed > miningDuration) {
      elapsed = miningDuration;
    }

    if (remaining > miningDuration) {
      remaining = miningDuration;
    }

    final sessionFinished =
        finalStarted != null &&
        remaining == Duration.zero;

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining =
          active == true &&
          remaining > Duration.zero;

      _canClaim =
          claimable ||
          sessionFinished;

      _rate = rate > 0
          ? rate
          : MiningService
              .defaultMiningRate;

      _startedAt = finalStarted;
      _endsAt = finalEnds;

      _remaining = remaining;
      _elapsed = elapsed;

      _sessionReward =
          serverReward;

      _adsWatched =
          ads.clamp(
        0,
        maxAds,
      ).toInt();
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

        if (started == null ||
            ends == null) {
          return;
        }

        final now = DateTime.now();

        var remaining =
            ends.difference(now);

        if (remaining.isNegative) {
          remaining =
              Duration.zero;
        }

        var elapsed =
            now.difference(started);

        if (elapsed.isNegative) {
          elapsed =
              Duration.zero;
        }

        if (elapsed > miningDuration) {
          elapsed = miningDuration;
        }

        final previousElapsedSeconds =
            _elapsed.inSeconds;

        final currentElapsedSeconds =
            elapsed.inSeconds;

        final secondsSinceLoad =
            currentElapsedSeconds -
            previousElapsedSeconds;

        if (secondsSinceLoad > 0 &&
            remaining > Duration.zero) {
          final fanPerSecond =
              _rate / 3600.0;

          _sessionReward +=
              fanPerSecond *
              secondsSinceLoad;
        }

        final finished =
            remaining == Duration.zero;

        setState(() {
          _remaining = remaining;
          _elapsed = elapsed;

          if (finished) {
            _isMining = false;
            _canClaim = true;
          }
        });

        if (finished) {
          _timer?.cancel();
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
      await _mining.startMining();

      await _loadProfile();
      await _loadMining();

      if (mounted) {
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
    if (_busy || !_canClaim) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
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
          unawaited(
            _loadMining(),
          );
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
          await _social
              .getDailyTasksForCard();

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
      // KYC must not stop HomeScreen loading.
    }
  }

  Future<void> _openKyc() async {
    if (_busy) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const KycPage(),
      ),
    );

    if (!mounted) return;

    await _loadKyc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryPurple,
          onRefresh: _load,
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(
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
                    const SizedBox(height: 14),
                    _buildBalanceCard(),
                    const SizedBox(height: 14),
                    _buildMiningCard(),
                    const SizedBox(height: 14),
                    _buildBoostCard(),
                    const SizedBox(height: 14),
                    _buildSocialCard(),
                    const SizedBox(height: 14),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryPurple,
            borderRadius:
                BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'AFAM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              const Text(
                'POWER FAN NETWORK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryPurple,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Mine FAN. Earn More',
                style: TextStyle(
                  color:
                      Colors.indigo.shade900,
                  fontSize: 14,
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
              size: 35,
            ),
            Positioned(
              right: 1,
              top: 2,
              child: Container(
                width: 10,
                height: 10,
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
      height: 174,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF4320B4),
            Color(0xFF29107A),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                primaryPurple.withValues(
              alpha: 0.22,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -25,
            child: Opacity(
              opacity: 0.28,
              child: const Icon(
                Icons.diamond_rounded,
                size: 155,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              20,
              22,
              16,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                          const BoxDecoration(
                        color:
                            Color(0xFFFFB600),
                        shape:
                            BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color:
                            Color(0xFFFF8C00),
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        displayedBalance
                            .toStringAsFixed(
                          4,
                        ),
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 34,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'FAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  '≈ \$0.00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha: 0.12,
                ),
                shape:
                    BoxShape.circle,
              ),
              alignment:
                  Alignment.center,
              child: const Icon(
                Icons.engineering_rounded,
                color: Colors.white,
                size: 58,
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
                iconColor:
                    primaryPurple,
                size: 66,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text:
                          TextSpan(
                        style:
                            const TextStyle(
                          color:
                              Colors.black,
                          fontSize: 18,
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
                            style:
                                TextStyle(
                              color:
                                  finished
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
                    const SizedBox(height: 5),
                    Text(
                      finished
                          ? 'Your 24-hour mining session is complete'
                          : _isMining
                              ? 'Mining FAN. Keep your session active'
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
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
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
                height: 48,
                color:
                    Colors.grey.shade200,
              ),
              Expanded(
                child: _miningInfo(
                  Icons.access_time_rounded,
                  'COUNTDOWN',
                  _formatDuration(
                    _remaining,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Per second: ${fanPerSecond.toStringAsFixed(8)} FAN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: deepPurple,
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child:
                ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : finished
                      ? _claimMining
                      : _isMining
                          ? null
                          : _startMining,
              icon: Icon(
                finished
                    ? Icons.card_giftcard_rounded
                    : _isMining
                        ? Icons.bolt_rounded
                        : Icons.construction_rounded,
              ),
              label: Text(
                finished
                    ? 'CLAIM MINING'
                    : _isMining
                        ? 'MINING'
                        : 'START MINING',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryPurple,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                textStyle:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
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
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Color(0xFF55555F),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      canWatch
                          ? _watchAd
                          : null,
                  icon: const Icon(
                    Icons.ondemand_video_rounded,
                    size: 20,
                  ),
                  label:
                      const Text(
                    'WATCH AD',
                  ),
                  style:
                      ButtonStyle(
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
                          Radius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Ads watched: $_adsWatched / $maxAds',
                style:
                    const TextStyle(
                  color: deepPurple,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '+${(_adsWatched * 0.10).toStringAsFixed(1)} FAN/H',
                style:
                    const TextStyle(
                  color: deepPurple,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
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
                0xFFE7E2F8,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 5),
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
                fontSize: 11,
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
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY TASK',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  taskLabel,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    color:
                        Color(0xFF55555F),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Reward: ${_formatFan(reward)} FAN',
                  style:
                      const TextStyle(
                    fontSize: 13,
                    color:
                        Color(0xFF55555F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _socialIcon('X'),
                  const SizedBox(width: 5),
                  _socialIcon('➤'),
                  const SizedBox(width: 5),
                  _socialIcon('◎'),
                  const SizedBox(width: 5),
                  _socialIcon('▶'),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 40,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _socialAction,
                  icon: const Icon(
                    Icons.card_giftcard_rounded,
                    size: 18,
                  ),
                  label: Text(
                    task?.canClaim == true
                        ? 'CLAIM ${_formatFan(reward)} FAN'
                        : 'FOLLOW & EARN ${_formatFan(reward)} FAN',
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
                        10,
                      ),
                    ),
                    textStyle:
                        const TextStyle(
                      fontSize: 11,
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
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  verified
                      ? 'KYC VERIFIED'
                      : 'KYC VERIFICATION',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  verified
                      ? 'Your identity has been verified'
                      : 'Verify your identity to secure your account',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF55555F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
                    BorderRadius.circular(
                  10,
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
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
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
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
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.045,
            ),
            blurRadius: 12,
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
    double size = 58,
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
        size: size * 0.55,
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
        horizontal: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryPurple,
            size: 38,
          ),
          const SizedBox(width: 9),
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
                    color: deepPurple,
                    fontSize: 15,
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
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style:
            const TextStyle(
          fontSize: 15,
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
