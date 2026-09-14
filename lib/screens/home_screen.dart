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

  static const Color successGreen = Color(0xFF238B57);
  static const Color successLight = Color(0xFFEAF8F0);

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
  bool _readyToStart = false;

  double _fan = 0.0;
  double _rate = MiningService.defaultMiningRate;
  double _sessionReward = 0.0;

  Duration _remaining = Duration.zero;

  int _miningLoadGeneration = 0;
  int _adsWatched = 0;

  List<DailySocialTask> _tasks = [];

  KycStatus _kycStatus = KycStatus.initial();

  @override
  void initState() {
    super.initState();

    unawaited(_loadInitial());
    unawaited(_initializeAds());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // ADS INITIALIZATION
  // ============================================================

  Future<void> _initializeAds() async {
    try {
      await _ads.initialize();
    } catch (_) {}
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<void> _loadInitial() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      await Future.wait([
        _loadProfile(),
        _loadMining(),
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

    unawaited(_loadTasks());
    unawaited(_loadKyc());
  }

  Future<void> _load() async {
    if (!mounted) return;

    try {
      await Future.wait([
        _loadProfile(),
        _loadMining(),
      ]);
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    }

    unawaited(_loadTasks());
    unawaited(_loadKyc());
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final data = await _mining.getProfile();

    if (!mounted) return;

    setState(() {
      _fan = _toDouble(data['fan_balance']);
    });
  }

  // ============================================================
  // MINING LOAD
  // ============================================================

  Future<void> _loadMining() async {
    final generation = ++_miningLoadGeneration;

    if (_readyToStart) {
      if (!mounted) return;

      _timer?.cancel();

      setState(() {
        _isMining = false;
        _canClaim = false;
        _sessionReward = 0.0;
        _remaining = Duration.zero;
        _adsWatched = 0;
        _rate = MiningService.defaultMiningRate;
      });

      return;
    }

    final data = await _mining.getActiveMining();

    if (generation != _miningLoadGeneration) {
      return;
    }

    if (data.isEmpty) {
      if (!mounted) return;

      _timer?.cancel();

      setState(() {
        _isMining = false;
        _canClaim = false;
        _sessionReward = 0.0;
        _remaining = Duration.zero;
        _adsWatched = 0;
        _rate = MiningService.defaultMiningRate;
      });

      return;
    }

    final status = data['status']?.toString().trim().toLowerCase();

    final serverActive = _toBool(data['active']);

    final serverClaimable =
        _toBool(data['claimable']) ||
        _toBool(data['can_claim']) ||
        _toBool(data['claim_required']) ||
        _toBool(data['requires_claim']) ||
        _toBool(data['needs_claim']) ||
        _toBool(data['session_completed']) ||
        _toBool(data['completed']);

    final statusIsActive =
        status == 'active' ||
        status == 'mining' ||
        status == 'running' ||
        status == 'started';

    final statusIsClaimable = _isClaimableStatus(status);

    final alreadyClaimed =
        _toBool(data['claimed']) ||
        _toBool(data['is_claimed']) ||
        status == 'claimed';

    double rate = _toDouble(
      data['total_rate'] ??
          data['mining_rate'] ??
          data['rate'],
    );

    if (rate <= 0) {
      try {
        rate = await _mining.getUserMiningRate();
      } catch (_) {
        rate = MiningService.defaultMiningRate;
      }
    }

    if (rate <= 0) {
      rate = MiningService.defaultMiningRate;
    }

    var ads = _toInt(
      data['ads_watched'] ??
          data['ad_count'] ??
          data['ads_count'] ??
          data['daily_ads_watched'],
    );

    if (ads < 0) {
      ads = 0;
    }

    if (ads > maxAds) {
      ads = maxAds;
    }

    var serverRemaining = _toInt(
      data['remaining_seconds'] ??
          data['seconds_remaining'] ??
          data['remaining'],
    );

    if (serverRemaining < 0) {
      serverRemaining = 0;
    }

    if (serverRemaining > miningDuration.inSeconds) {
      serverRemaining = miningDuration.inSeconds;
    }

    final serverReward = _toDouble(
      data['reward'] ??
          data['session_reward'] ??
          data['earned_reward'] ??
          data['reward_amount'],
    );

    bool active = false;

    if (!alreadyClaimed) {
      if (serverActive &&
          !serverClaimable &&
          !statusIsClaimable) {
        active = true;
      } else if (statusIsActive &&
          !serverClaimable &&
          !statusIsClaimable) {
        active = true;
      }
    }

    final finalCanClaim =
        !alreadyClaimed &&
        !active &&
        (serverClaimable || statusIsClaimable);

    double liveReward = serverReward;

    if (liveReward <= 0 && active) {
      final elapsedSeconds =
          miningDuration.inSeconds - serverRemaining;

      if (elapsedSeconds > 0) {
        liveReward =
            (elapsedSeconds / 3600.0) * rate;
      }
    }

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining = active;
      _canClaim = finalCanClaim;
      _rate = rate;
      _remaining = Duration(seconds: serverRemaining);
      _sessionReward =
          liveReward < 0 ? 0.0 : liveReward;
      _adsWatched = ads;
    });

    if (_isMining) {
      _startTimer();
    }
  }

  bool _isClaimableStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      return false;
    }

    final value = status.trim().toLowerCase();

    return value == 'completed' ||
        value == 'complete' ||
        value == 'expired' ||
        value == 'finished' ||
        value == 'ready' ||
        value == 'ready_to_claim' ||
        value == 'claimable' ||
        value == 'pending_claim' ||
        value == 'awaiting_claim' ||
        value == 'session_completed' ||
        value == 'ended';
  }

  // ============================================================
  // APPLY MINING RESULT
  // ============================================================

  Future<bool> _applyMiningResult(
    Map<String, dynamic> data,
  ) async {
    if (data.isEmpty) {
      return false;
    }

    final status = data['status']?.toString().trim().toLowerCase();

    final serverActive = _toBool(data['active']);

    final claimRequired =
        _toBool(data['claim_required']) ||
        _toBool(data['requires_claim']) ||
        _toBool(data['needs_claim']) ||
        _toBool(data['claimable']);

    final alreadyClaimed =
        _toBool(data['claimed']) ||
        _toBool(data['is_claimed']) ||
        status == 'claimed';

    if (alreadyClaimed) {
      if (mounted) {
        _timer?.cancel();

        setState(() {
          _isMining = false;
          _canClaim = false;
          _readyToStart = true;
          _remaining = Duration.zero;
          _sessionReward = 0.0;
          _adsWatched = 0;
          _rate = MiningService.defaultMiningRate;
        });
      }

      return true;
    }

    if (claimRequired &&
        !serverActive &&
        !alreadyClaimed) {
      if (mounted) {
        _timer?.cancel();

        setState(() {
          _isMining = false;
          _canClaim = true;
          _remaining = Duration.zero;
          _readyToStart = false;
        });
      }

      return true;
    }

    var serverRemaining = _toInt(
      data['remaining_seconds'] ??
          data['seconds_remaining'] ??
          data['remaining'],
    );

    if (serverRemaining < 0) {
      serverRemaining = 0;
    }

    if (serverRemaining > miningDuration.inSeconds) {
      serverRemaining = miningDuration.inSeconds;
    }

    final statusActive =
        status == 'active' ||
        status == 'mining' ||
        status == 'running' ||
        status == 'started';

    final active =
        !alreadyClaimed &&
        !claimRequired &&
        (serverActive || statusActive);

    final returnedRate = _toDouble(
      data['total_rate'] ??
          data['mining_rate'] ??
          data['rate'],
    );

    var ads = _toInt(
      data['ads_watched'] ??
          data['ad_count'] ??
          data['ads_count'] ??
          data['daily_ads_watched'],
    );

    if (ads < 0) {
      ads = 0;
    }

    if (ads > maxAds) {
      ads = maxAds;
    }

    final reward = _toDouble(
      data['reward'] ??
          data['session_reward'] ??
          data['earned_reward'] ??
          data['reward_amount'],
    );

    if (!mounted) {
      return true;
    }

    _timer?.cancel();

    setState(() {
      _remaining =
          Duration(seconds: serverRemaining);

      _rate = returnedRate > 0
          ? returnedRate
          : MiningService.defaultMiningRate;

      _adsWatched = ads;
      _isMining = active;
      _canClaim = claimRequired && !active;
      _sessionReward =
          reward > 0 ? reward : 0.0;

      if (active) {
        _readyToStart = false;
      }
    });

    if (_isMining) {
      _startTimer();
    }

    return true;
  }

  // ============================================================
  // MINING TIMER
  // ============================================================

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        if (!_isMining) {
          _timer?.cancel();
          return;
        }

        if (_remaining <= Duration.zero) {
          _timer?.cancel();

          unawaited(
            _refreshAfterTimer(),
          );

          return;
        }

        final nextRemaining =
            _remaining -
                const Duration(seconds: 1);

        final safeRemaining =
            nextRemaining.isNegative
                ? Duration.zero
                : nextRemaining;

        double displayReward =
            _sessionReward;

        final elapsedSeconds =
            miningDuration.inSeconds -
                safeRemaining.inSeconds;

        if (elapsedSeconds > 0) {
          displayReward =
              (elapsedSeconds / 3600.0) * _rate;
        }

        setState(() {
          _remaining = safeRemaining;
          _sessionReward = displayReward;
        });

        if (safeRemaining == Duration.zero) {
          _timer?.cancel();

          unawaited(
            _refreshAfterTimer(),
          );
        }
      },
    );
  }

  Future<void> _refreshAfterTimer() async {
    if (!mounted) return;

    try {
      await _loadMining();
    } catch (e) {
      if (mounted) {
        _message(_error(e));
      }
    }
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<void> _startMining() async {
    if (_busy || _isMining || _canClaim) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      try {
        await _ads.initialize();
      } catch (_) {}

      if (!mounted) return;

      _message(
        'Checking for activation ad...',
      );

      final activationCompleted =
          Completer<bool>();

      var activationCallbackReceived = false;

      final shown =
          await _ads.showActivationAd(
        onRewarded: () {
          if (activationCallbackReceived) {
            return;
          }

          activationCallbackReceived = true;

          if (!activationCompleted.isCompleted) {
            activationCompleted.complete(true);
          }
        },
        onAdClosed: () {},
      );

      if (!shown) {
        if (!mounted) return;

        _message(
          'No activation ad is available. Starting mining without it...',
        );
      } else {
        if (!mounted) return;

        _message(
          'Activation ad shown. Complete it to start mining.',
        );

        final rewarded =
            await activationCompleted.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => false,
        );

        if (!rewarded) {
          throw Exception(
            'Activation ad was not completed. Mining has not started.',
          );
        }

        if (!mounted) return;

        _message(
          'Activation ad completed. Starting your 24-hour mining session...',
        );
      }

      final result =
          await _mining.startMining();

      if (result.isEmpty) {
        throw Exception(
          'Mining server returned an empty response.',
        );
      }

      final success =
          result['success'] == true;

      final claimRequired =
          _toBool(result['claim_required']) ||
          _toBool(result['requires_claim']) ||
          _toBool(result['needs_claim']) ||
          _toBool(result['claimable']);

      if (!success && claimRequired) {
        if (mounted) {
          setState(() {
            _isMining = false;
            _canClaim = true;
            _readyToStart = false;
            _remaining = Duration.zero;
          });
        }

        _message(
          'Your previous 24-hour mining session is complete and ready to claim.',
        );

        return;
      }

      if (!success) {
        throw Exception(
          result['message'] ??
              result['error'] ??
              'Unable to start mining.',
        );
      }

      final applied =
          await _applyMiningResult(result);

      if (!applied) {
        await _loadMining();
      }

      if (!mounted) return;

      if (!_isMining) {
        if (_canClaim) {
          _message(
            'Your 24-hour mining session is complete and ready to claim.',
          );
        } else {
          throw Exception(
            'Mining started, but the server did not return a valid active mining session. Please refresh and try again.',
          );
        }

        return;
      }

      await _loadProfile();

      if (!mounted) return;

      _message(
        'Mining started successfully. Your 24-hour countdown has started.',
      );
    } catch (e) {
      if (!mounted) return;

      final errorText =
          _error(e).toLowerCase();

      final claimRequired =
          errorText.contains(
            'claim your completed',
          ) ||
          errorText.contains(
            'claim_required',
          ) ||
          errorText.contains(
            'claim required',
          ) ||
          errorText.contains(
            'completed mining session',
          ) ||
          errorText.contains(
            'claim your reward',
          );

      if (claimRequired) {
        setState(() {
          _isMining = false;
          _canClaim = true;
          _readyToStart = false;
          _remaining = Duration.zero;
        });

        _message(
          'Your 24-hour mining session is complete and ready to claim.',
        );
      } else {
        _message(_error(e));
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _busy = false;
      });
    }
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<void> _claimMining() async {
    if (_busy || !_canClaim || _isMining) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _mining.claimMining();

      if (result.isEmpty) {
        throw Exception(
          'Mining claim server returned an empty response.',
        );
      }

      final success =
          result['success'] == true;

      if (!success) {
        throw Exception(
          result['message'] ??
              result['error'] ??
              'Unable to claim mining reward.',
        );
      }

      _timer?.cancel();

      if (!mounted) return;

      setState(() {
        _sessionReward = 0.0;
        _canClaim = false;
        _isMining = false;
        _remaining = Duration.zero;
        _adsWatched = 0;
        _rate = MiningService.defaultMiningRate;
        _readyToStart = true;
      });

      await _loadProfile();

      if (!mounted) return;

      _message(
        'Mining reward claimed successfully. Press START MINING to begin a new session.',
      );
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

  // ============================================================
  // BOOST ADS
  // ============================================================

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
      try {
        await _ads.initialize();
      } catch (_) {}

      final oldCount = _adsWatched;

      final shown =
          await _ads.showRewardedAd(
        onRewarded: () {},
        onAdClosed: () {},
      );

      if (!shown) {
        if (mounted) {
          _message(
            'Rewarded ad is not ready. No boost was added.',
          );
        }

        return;
      }

      var updated = false;

      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) return;

        await _loadMining();

        if (_adsWatched > oldCount) {
          updated = true;
          break;
        }

        if (!_isMining) {
          break;
        }
      }

      if (!mounted) return;

      if (updated) {
        _message(
          'Ad verified successfully. +0.10 FAN/H boost added.',
        );
      } else {
        _message(
          'Ad reward is still being verified. No boost was added yet.',
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

  // ============================================================
  // SOCIAL TASKS
  //
  // IMPORTANT:
  //
  // Each task is handled independently.
  //
  // We DO NOT use _tasks.first for every action.
  //
  // Every button sends its own task.id to:
  //
  // start_social_task
  // claim_daily_social_reward
  // ============================================================

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

  Future<void> _socialAction(
    DailySocialTask task,
  ) async {
    if (_busy) return;

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
      // ========================================================
      // CLAIM
      // ========================================================

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

      // ========================================================
      // START TASK
      // ========================================================

      await _social.startTask(
        taskId: task.id,
      );

      // ========================================================
      // OPEN POST / SOCIAL URL
      // ========================================================

      if (task.url.trim().isEmpty) {
        if (mounted) {
          _message(
            'Social task started. Complete the required action, then refresh to verify it.',
          );
        }

        await _loadTasks();
        return;
      }

      final opened =
          await _social.openTaskUrl(
        task.url,
      );

      if (mounted) {
        if (opened) {
          _message(
            'Complete the task, then return here. The server will verify your action before you can claim ${_formatFan(task.rewardFan)} FAN.',
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

  // ============================================================
  // SOCIAL TASK CARD
  // ============================================================

  Widget _buildSocialCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIcon(
                Icons
                    .assignment_turned_in_rounded,
                background: successLight,
                iconColor: successGreen,
                size: 56,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOCIAL TASKS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                        color: deepPurple,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Complete any available task and earn FAN.',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Color(0xFF66666F),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh tasks',
                onPressed: _busy
                    ? null
                    : _loadTasks,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: primaryPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (_tasks.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    const Color(0xFFF7F5FC),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons
                        .hourglass_empty_rounded,
                    color: primaryPurple,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No social task is available right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                      color: deepPurple,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._tasks.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final task = entry.value;

                return Padding(
                  padding:
                      EdgeInsets.only(
                    bottom:
                        index == _tasks.length - 1
                            ? 0
                            : 10,
                  ),
                  child:
                      _buildSingleSocialTask(
                    task,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SINGLE SOCIAL TASK
  // ============================================================

  Widget _buildSingleSocialTask(
    DailySocialTask task,
  ) {
    final platform =
        task.platform.trim().toLowerCase();

    final platformLabel =
        _platformName(task);

    final platformIcon =
        _platformIcon(platform);

    final isClaimable =
        task.canClaim &&
        !task.claimed;

    final isClaimed =
        task.claimed;

    final actionText =
        isClaimed
            ? 'CLAIMED'
            : isClaimable
                ? 'CLAIM ${_formatFan(task.rewardFan)} FAN'
                : 'OPEN TASK';

    final actionColor =
        isClaimed
            ? Colors.grey
            : isClaimable
                ? successGreen
                : primaryPurple;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: isClaimable
              ? successGreen
                  .withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _platformColor(
                    platform,
                  ).withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Icon(
                  platformIcon,
                  color:
                      _platformColor(
                    platform,
                  ),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            platformLabel,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  primaryPurple,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFF7E0,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              7,
                            ),
                          ),
                          child: Text(
                            '+${_formatFan(task.rewardFan)} FAN',
                            style:
                                const TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w900,
                              color:
                                  Color(
                                0xFF9A6800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.title.isNotEmpty
                          ? task.title
                          : 'Complete this social task',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    if (task.description
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          color:
                              Color(0xFF66666F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ======================================================
          // REQUIRED ACTIONS
          // ======================================================

          _buildTaskActionsStatus(task),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 43,
            child: ElevatedButton.icon(
              onPressed:
                  _busy || isClaimed
                      ? null
                      : () =>
                          _socialAction(task),
              icon: Icon(
                isClaimed
                    ? Icons.check_rounded
                    : isClaimable
                        ? Icons
                            .card_giftcard_rounded
                        : Icons
                            .open_in_new_rounded,
                size: 18,
              ),
              label: Text(
                actionText,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    actionColor,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    actionColor.withValues(
                  alpha: 0.45,
                ),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                textStyle:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SOCIAL ACTION STATUS
  // ============================================================

  Widget _buildTaskActionsStatus(
    DailySocialTask task,
  ) {
    final items =
        <Widget>[];

    if (task.requiresFollow) {
      items.add(
        _taskStatus(
          'Follow',
          task.followVerified,
        ),
      );
    }

    if (task.requiresLike) {
      items.add(
        _taskStatus(
          'Like',
          task.likeVerified,
        ),
      );
    }

    if (task.requiresComment) {
      items.add(
        _taskStatus(
          'Comment',
          task.commentVerified,
        ),
      );
    }

    if (task.requiresShare) {
      items.add(
        _taskStatus(
          'Share',
          task.shareVerified,
        ),
      );
    }

    if (task.requiresJoin) {
      items.add(
        _taskStatus(
          'Join',
          task.joinVerified,
        ),
      );
    }

    if (task.requiresSubscribe) {
      items.add(
        _taskStatus(
          'Subscribe',
          task.subscribeVerified,
        ),
      );
    }

    if (items.isEmpty) {
      return const Text(
        'Server verification required before reward claim.',
        style: TextStyle(
          fontSize: 10,
          color: Color(0xFF777780),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items,
    );
  }

  Widget _taskStatus(
    String label,
    bool verified,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: verified
            ? successLight
            : const Color(0xFFF5F5F7),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: verified
              ? successGreen
                  .withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            verified
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 13,
            color: verified
                ? successGreen
                : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight:
                  FontWeight.w800,
              color: verified
                  ? successGreen
                  : const Color(
                      0xFF777780,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _platformName(
    DailySocialTask task,
  ) {
    final value =
        task.platform.trim().toLowerCase();

    switch (value) {
      case 'x':
      case 'twitter':
        return 'X / Twitter';

      case 'instagram':
        return 'Instagram';

      case 'facebook':
        return 'Facebook';

      case 'tiktok':
        return 'TikTok';

      case 'youtube':
        return 'YouTube';

      case 'telegram':
        return 'Telegram';

      default:
        return task.platform.isEmpty
            ? 'Social Task'
            : task.platform;
    }
  }

  IconData _platformIcon(
    String platform,
  ) {
    switch (platform) {
      case 'telegram':
        return Icons.send_rounded;

      case 'youtube':
        return Icons.play_circle_fill_rounded;

      case 'instagram':
        return Icons.camera_alt_rounded;

      case 'facebook':
        return Icons.facebook_rounded;

      case 'tiktok':
        return Icons.music_note_rounded;

      case 'x':
      case 'twitter':
        return Icons.close_rounded;

      default:
        return Icons.public_rounded;
    }
  }

  Color _platformColor(
    String platform,
  ) {
    switch (platform) {
      case 'telegram':
        return const Color(0xFF229ED9);

      case 'youtube':
        return Colors.red;

      case 'instagram':
        return const Color(0xFFE1306C);

      case 'facebook':
        return const Color(0xFF1877F2);

      case 'tiktok':
        return Colors.black;

      case 'x':
      case 'twitter':
        return Colors.black;

      default:
        return primaryPurple;
    }
  }

  // ============================================================
  // KYC
  // ============================================================

  Future<void> _loadKyc() async {
    try {
      final status =
          await _kyc.getProgress();

      if (!mounted) return;

      setState(() {
        _kycStatus = status;
      });
    } catch (_) {}
  }

  Future<void> _openKyc() async {
    if (_busy) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KycPage(),
      ),
    );

    if (!mounted) return;

    unawaited(_loadKyc());
  }

  // ============================================================
  // BUILD
  // ============================================================

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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 76,
          height: 56,
          decoration: BoxDecoration(
            color: primaryPurple,
            borderRadius:
                BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: const Text(
            'AFAM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
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
              const SizedBox(height: 2),
              Text(
                'Mine FAN. Earn More',
                style: TextStyle(
                  color: Colors.indigo.shade900,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: deepPurple,
              size: 35,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 9,
                height: 9,
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

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard() {
    final displayedBalance =
        _fan +
        ((_isMining || _canClaim)
            ? _sessionReward
            : 0.0);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4320B4),
            Color(0xFF29107A),
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color:
                primaryPurple.withValues(
              alpha: 0.18,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -16,
            child: Opacity(
              opacity: 0.20,
              child: const Icon(
                Icons.engineering_rounded,
                size: 150,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              17,
              20,
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration:
                          const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            LinearGradient(
                          colors: [
                            Color(0xFFFFC928),
                            Color(0xFFFFA800),
                          ],
                        ),
                      ),
                      alignment:
                          Alignment.center,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          border: Border.all(
                            color:
                                const Color(
                              0xFFE89100,
                            ),
                            width: 2,
                          ),
                        ),
                        alignment:
                            Alignment.center,
                        child: const Text(
                          'F',
                          style: TextStyle(
                            color:
                                Color(0xFFE58A00),
                            fontSize: 27,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Flexible(
                      child: Text(
                        displayedBalance
                            .toStringAsFixed(8),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'FAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  '≈ \$0.00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MINING CARD
  // ============================================================

  Widget _buildMiningCard() {
    final isReadyToClaim =
        _canClaim && !_isMining;

    final buttonText =
        _busy && isReadyToClaim
            ? 'PROCESSING...'
            : isReadyToClaim
                ? 'READY TO CLAIM'
                : _isMining
                    ? _formatDuration(
                        _remaining,
                      )
                    : _busy
                        ? 'STARTING MINING...'
                        : 'START MINING';

    final buttonIcon =
        _busy && isReadyToClaim
            ? Icons.hourglass_top_rounded
            : isReadyToClaim
                ? Icons.card_giftcard_rounded
                : _isMining
                    ? Icons.timer_rounded
                    : _busy
                        ? Icons
                            .ondemand_video_rounded
                        : Icons
                            .construction_rounded;

    return _card(
      child: Column(
        children: [
          if (isReadyToClaim) ...[
            Row(
              children: [
                _circleIcon(
                  Icons.check_circle_rounded,
                  background: successLight,
                  iconColor: successGreen,
                  size: 62,
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Text(
                    'Your 24-hour mining session is complete and ready to claim.',
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Color(0xFF66666F),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
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
                height: 49,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: _miningInfo(
                  Icons.bolt_rounded,
                  'BOOST',
                  '+${(_adsWatched * 0.10).toStringAsFixed(2)} FAN/H',
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Per second: ${(_rate / 3600.0).toStringAsFixed(8)} FAN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: deepPurple,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _busy
                  ? null
                  : isReadyToClaim
                      ? _claimMining
                      : _isMining
                          ? null
                          : _startMining,
              icon: Icon(
                buttonIcon,
                size: 23,
              ),
              label: Text(
                buttonText,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    isReadyToClaim
                        ? successGreen
                        : primaryPurple,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    isReadyToClaim
                        ? successGreen
                            .withValues(
                            alpha: 0.70,
                          )
                        : primaryPurple
                            .withValues(
                            alpha: 0.70,
                          ),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                textStyle: TextStyle(
                  fontSize:
                      _isMining ? 17 : 16,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing:
                      _isMining ? 0.6 : 0,
                ),
              ),
            ),
          ),
          if (!_isMining && !_canClaim) ...[
            const SizedBox(height: 9),
            Text(
              _readyToStart
                  ? 'An activation ad may appear before the new mining session starts. If no ad is available, mining will start automatically.'
                  : 'Activation ad is optional. If no ad is available, the 24-hour mining session will start automatically.',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: deepPurple,
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
          if (_isMining) ...[
            const SizedBox(height: 9),
            const Text(
              'Mining is active. You can watch up to 7 Boost Ads.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: deepPurple,
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BOOST CARD
  // ============================================================

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
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Each verified ad adds +0.1 FAN/H',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF55555F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child:
                    ElevatedButton.icon(
                  onPressed: canWatch
                      ? _watchAd
                      : null,
                  icon: const Icon(
                    Icons
                        .ondemand_video_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'WATCH AD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
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
                          Radius.circular(12),
                        ),
                      ),
                    ),
                    padding:
                        const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Text(
                'Ads watched: $_adsWatched / $maxAds',
                style: const TextStyle(
                  color: deepPurple,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '+${(_adsWatched * 0.10).toStringAsFixed(1)} FAN/H',
                style: const TextStyle(
                  color: deepPurple,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  const Color(0xFFE7E2F8),
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
                  ? '7 Boost Ads maximum per session'
                  : 'Start mining before watching Boost Ads',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KYC CARD
  // ============================================================

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
            size: 56,
          ),
          const SizedBox(width: 12),
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
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verified
                      ? 'Your identity has been verified'
                      : 'Verify your identity to secure your account',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
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
                    BorderRadius.circular(
                  10,
                ),
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 11,
                vertical: 10,
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
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON CARD
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.045,
            ),
            blurRadius: 11,
            offset:
                const Offset(0, 4),
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
            size: 31,
          ),
          const SizedBox(width: 8),
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
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: deepPurple,
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

  // ============================================================
  // DURATION
  // ============================================================

  String _formatDuration(
    Duration duration,
  ) {
    if (duration.isNegative) {
      duration = Duration.zero;
    }

    final hours = duration.inHours
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

  // ============================================================
  // FAN FORMAT
  // ============================================================

  String _formatFan(double value) {
    if (value ==
        value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // PARSERS
  // ============================================================

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

  int _toInt(dynamic value) {
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

  bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value.toString()
            .trim()
            .toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y';
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _error(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }

    return text;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _message(String message) {
    if (!mounted ||
        message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}
