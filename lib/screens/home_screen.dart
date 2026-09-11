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

  static const Color successGreen = Color(0xFF20884D);
  static const Color successLight = Color(0xFFEAF8F0);

  static const Duration miningDuration = Duration(hours: 24);
  static const int maxAds = 7;

  final MiningService _mining = MiningService.instance;
  final SocialTaskService _social = SocialTaskService();
  final KycService _kyc = KycService();
  final LevelPlayAdsService _ads =
      LevelPlayAdsService.instance;

  Timer? _timer;

  bool _loading = true;
  bool _busy = false;
  bool _isMining = false;
  bool _canClaim = false;
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

    unawaited(_loadInitial());
    unawaited(_initializeAds());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<void> _initializeAds() async {
    try {
      await _ads.initialize();
    } catch (_) {
      // Ads must never block HomeScreen.
    }
  }

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

    if (!mounted || data == null) {
      return;
    }

    setState(() {
      _fan = _toDouble(data['fan_balance']);
    });
  }

  // ============================================================
  // MINING
  // ============================================================

  Future<void> _loadMining() async {
    final data = await _mining.getActiveMining();

    if (data.isEmpty) {
      if (!mounted) return;

      _timer?.cancel();

      setState(() {
        _isMining = false;
        _canClaim = false;
        _sessionReward = 0.0;
        _remaining = Duration.zero;
        _startedAt = null;
        _endsAt = null;
        _adsWatched = 0;
        _rate = MiningService.defaultMiningRate;
      });

      return;
    }

    // ----------------------------------------------------------
    // DATES
    // ----------------------------------------------------------

    final started = _parseDate(
      data['started_at'] ??
          data['start_time'] ??
          data['started'] ??
          data['mining_started_at'],
    );

    final ends = _parseDate(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'] ??
          data['mining_ends_at'],
    );

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

    final now = DateTime.now();

    // ----------------------------------------------------------
    // STATUS
    // ----------------------------------------------------------

    final status =
        data['status']?.toString().trim().toLowerCase();

    // ----------------------------------------------------------
    // CLAIM STATE
    // ----------------------------------------------------------

    final claimable =
        _toBool(data['claimable']) ||
        _toBool(data['can_claim']) ||
        _toBool(data['claim_required']) ||
        _toBool(data['requires_claim']) ||
        _toBool(data['needs_claim']) ||
        _toBool(data['session_completed']) ||
        _toBool(data['completed']);

    final statusIsClaimable =
        _isClaimableStatus(status);

    final alreadyClaimed =
        _toBool(data['claimed']) ||
        _toBool(data['is_claimed']) ||
        status == 'claimed';

    // ----------------------------------------------------------
    // RATE
    // ----------------------------------------------------------

    var rate = _toDouble(
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

    // ----------------------------------------------------------
    // ADS
    // ----------------------------------------------------------

    final ads = _toInt(
      data['ads_watched'] ??
          data['ad_count'] ??
          data['ads_count'] ??
          data['daily_ads_watched'],
    );

    // ----------------------------------------------------------
    // SERVER REMAINING
    // ----------------------------------------------------------

    final serverRemaining = _toInt(
      data['remaining_seconds'] ??
          data['seconds_remaining'],
    );

    // ----------------------------------------------------------
    // SERVER REWARD
    // ----------------------------------------------------------

    final serverReward = _toDouble(
      data['reward'] ??
          data['session_reward'] ??
          data['earned_reward'],
    );

    // ----------------------------------------------------------
    // REMAINING TIME
    // ----------------------------------------------------------

    Duration remaining = Duration.zero;

    if (finalEnds != null) {
      remaining = finalEnds.difference(now);

      if (remaining.isNegative) {
        remaining = Duration.zero;
      }
    } else if (serverRemaining > 0) {
      remaining =
          Duration(seconds: serverRemaining);
    }

    if (remaining > miningDuration) {
      remaining = miningDuration;
    }

    // ----------------------------------------------------------
    // ACTIVE DETECTION
    // ----------------------------------------------------------

    final activeByTime =
        finalStarted != null &&
        finalEnds != null &&
        !finalStarted.isAfter(now) &&
        finalEnds.isAfter(now);

    final sessionFinished =
        finalEnds != null &&
        !finalEnds.isAfter(now);

    final activeByStatus =
        status == 'active' ||
        status == 'mining' ||
        status == 'running' ||
        status == 'started';

    final explicitInactive =
        data.containsKey('active') &&
        data['active'] == false;

    final activeFlag =
        data['mining_active'] == true;

    /*
     * IMPORTANT:
     *
     * If the 24-hour end time has passed, the session MUST NOT
     * remain MINING even if the old mining_active database flag
     * is still true.
     */
    final active =
        !explicitInactive &&
        !sessionFinished &&
        (
          activeByTime ||
          activeByStatus ||
          (
            activeFlag &&
            finalEnds == null
          )
        );

    // ----------------------------------------------------------
    // FINAL CLAIM STATE
    // ----------------------------------------------------------

    final finalCanClaim =
        !alreadyClaimed &&
        !active &&
        (
          claimable ||
          statusIsClaimable ||
          sessionFinished
        );

    final explicitClaimRequired =
        _toBool(data['claim_required']) ||
        _toBool(data['requires_claim']) ||
        _toBool(data['needs_claim']);

    final forceClaim =
        explicitClaimRequired &&
        !alreadyClaimed &&
        !active;

    final finalClaim =
        finalCanClaim || forceClaim;

    // ----------------------------------------------------------
    // DISPLAY REWARD
    // ----------------------------------------------------------

    double liveReward = serverReward;

    if (liveReward <= 0 &&
        active &&
        finalStarted != null) {
      final elapsedSeconds =
          now.difference(finalStarted).inSeconds;

      if (elapsedSeconds > 0) {
        liveReward =
            (elapsedSeconds / 3600.0) * rate;
      }
    }

    if (finalClaim &&
        liveReward <= 0 &&
        rate > 0) {
      liveReward =
          (miningDuration.inSeconds / 3600.0) *
              rate;
    }

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining = active;
      _canClaim = finalClaim;

      _rate = rate;

      _startedAt = finalStarted;
      _endsAt = finalEnds;

      _remaining = remaining;

      _sessionReward =
          liveReward < 0 ? 0.0 : liveReward;

      _adsWatched =
          ads.clamp(0, maxAds).toInt();

      if (_isMining) {
        _claimAdWaiting = false;
      }
    });

    if (_isMining) {
      _startTimer();
    }
  }

  // ============================================================
  // CLAIMABLE STATUS
  // ============================================================

  bool _isClaimableStatus(String? status) {
    if (status == null ||
        status.trim().isEmpty) {
      return false;
    }

    final value =
        status.trim().toLowerCase();

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
  // APPLY START MINING RESPONSE
  // ============================================================

  void _applyMiningResult(
    Map<String, dynamic> data,
  ) {
    if (_toBool(data['claim_required']) ||
        _toBool(data['requires_claim']) ||
        _toBool(data['needs_claim'])) {
      if (!mounted) return;

      setState(() {
        _isMining = false;
        _canClaim = true;
        _remaining = Duration.zero;
      });

      return;
    }

    final started = _parseDate(
      data['started_at'] ??
          data['start_time'] ??
          data['started'] ??
          data['mining_started_at'],
    );

    final ends = _parseDate(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'] ??
          data['mining_ends_at'],
    );

    if (started == null && ends == null) {
      return;
    }

    final now = DateTime.now();

    DateTime? finalStarted = started;
    DateTime? finalEnds = ends;

    if (finalStarted == null &&
        finalEnds != null) {
      finalStarted =
          finalEnds.subtract(miningDuration);
    }

    if (finalEnds == null &&
        finalStarted != null) {
      finalEnds =
          finalStarted.add(miningDuration);
    }

    if (finalStarted == null ||
        finalEnds == null) {
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
      data['total_rate'] ??
          data['mining_rate'] ??
          data['rate'],
    );

    final returnedReward =
        _toDouble(
      data['reward'] ??
          data['session_reward'],
    );

    if (!mounted) return;

    setState(() {
      _startedAt = finalStarted;
      _endsAt = finalEnds;
      _remaining = remaining;

      if (returnedRate > 0) {
        _rate = returnedRate;
      }

      if (returnedReward > 0) {
        _sessionReward =
            returnedReward;
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

  // ============================================================
  // COUNTDOWN
  // ============================================================

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

        double displayReward =
            _sessionReward;

        if (remaining > Duration.zero) {
          final elapsedSeconds =
              now.difference(started).inSeconds;

          if (elapsedSeconds >= 0) {
            displayReward =
                (elapsedSeconds / 3600.0) *
                    _rate;
          }
        }

        final finished =
            remaining == Duration.zero;

        setState(() {
          _remaining = remaining;

          if (finished) {
            /*
             * 24 HOURS FINISHED.
             *
             * Immediately switch the UI from MINING to
             * READY TO CLAIM.
             */
            _isMining = false;
            _canClaim = true;

            /*
             * Keep the completed reward visible until claim.
             */
            if (_sessionReward <= 0) {
              _sessionReward =
                  (miningDuration.inSeconds /
                          3600.0) *
                      _rate;
            }
          } else {
            _sessionReward =
                displayReward;
          }
        });

        if (finished) {
          _timer?.cancel();

          /*
           * Ask Supabase to confirm the final state.
           */
          unawaited(_loadMining());
        }
      },
    );
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<void> _startMining() async {
    if (_busy ||
        _isMining ||
        _canClaim) {
      if (_canClaim &&
          !_isMining &&
          !_busy) {
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
        if (_toBool(result['claim_required']) ||
            _toBool(result['requires_claim']) ||
            _toBool(result['needs_claim'])) {
          if (mounted) {
            setState(() {
              _isMining = false;
              _canClaim = true;
              _remaining = Duration.zero;
            });
          }

          _message(
            'Your completed mining session is ready to claim.',
          );

          return;
        }

        throw Exception(
          result['message'] ??
              result['error'] ??
              'Unable to start mining.',
        );
      }

      if (result.isNotEmpty) {
        _applyMiningResult(result);
      }

      await _loadProfile();
      await _loadMining();

      if (!mounted) return;

      if (_toBool(result['claim_required']) ||
          _toBool(result['requires_claim']) ||
          _toBool(result['needs_claim'])) {
        _message(
          'Your completed mining session is ready to claim.',
        );
      } else if (_toBool(result['already_active'])) {
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
              );

      if (claimRequired && mounted) {
        setState(() {
          _isMining = false;
          _canClaim = true;
          _remaining = Duration.zero;
        });

        _message(
          'Your completed mining session is ready to claim.',
        );
      } else if (mounted) {
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
    if (_busy ||
        !_canClaim ||
        _isMining) {
      return;
    }

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
        onAdClosed: () {},
      );

      if (!shown) {
        throw Exception(
          'Rewarded ad is not ready. Please try again.',
        );
      }

      final adVerified =
          await adCompleted.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );

      if (!adVerified) {
        throw Exception(
          'Ad reward could not be verified. Your FAN was not claimed.',
        );
      }

      if (!mounted) return;

      await _loadMining();

      if (!mounted) return;

      if (_isMining ||
          !_canClaim) {
        throw Exception(
          'Mining session is not ready to claim.',
        );
      }

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

      if (mounted) {
        setState(() {
          _sessionReward = 0.0;
          _canClaim = false;
          _isMining = false;
          _remaining = Duration.zero;
          _startedAt = null;
          _endsAt = null;
          _adsWatched = 0;
        });
      }

      await _loadProfile();
      await _loadMining();

      if (mounted) {
        _message(
          'Mining reward claimed successfully. Come back tomorrow.',
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

  // ============================================================
  // NORMAL BOOST AD
  // ============================================================

  Future<void> _watchAd() async {
    if (_busy ||
        !_isMining) {
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
        onAdClosed: () {},
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

  // ============================================================
  // SOCIAL TASKS
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
    } catch (_) {
      // KYC never blocks Home.
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
                    8,
                    16,
                    18,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    _buildBalanceCard(),
                    const SizedBox(height: 11),
                    _buildMiningCard(),
                    const SizedBox(height: 11),
                    _buildBoostCard(),
                    const SizedBox(height: 11),
                    _buildSocialCard(),
                    const SizedBox(height: 11),
                    _buildKycCard(),
                    const SizedBox(height: 8),
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
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: primaryPurple,
              borderRadius:
                  BorderRadius.circular(11),
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
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'POWER FAN NETWORK',
                    style: TextStyle(
                      color: primaryPurple,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
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
                size: 30,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
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
      ),
    );
  }

  // ============================================================
  // FAN COIN
  // ============================================================

  Widget _fanCoin({
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFC928),
            Color(0xFFFF9F00),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(
              alpha: 0.22,
            ),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.68,
        height: size * 0.68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.orange.shade700,
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'F',
          style: TextStyle(
            color: const Color(0xFFE97900),
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
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
      height: 142,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF4320B4),
            Color(0xFF29107A),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(
              alpha: 0.16,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -20,
            child: Opacity(
              opacity: 0.16,
              child: Icon(
                Icons
                    .engineering_rounded,
                size: 115,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              17,
              15,
              17,
              10,
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
                    _fanCoin(size: 42),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        displayedBalance
                            .toStringAsFixed(8),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'FAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
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
        ],
      ),
    );
  }

  // ============================================================
  // MINING CARD
  // ============================================================

  Widget _buildMiningCard() {
    final readyToClaim =
        _canClaim && !_isMining;

    final fanPerSecond =
        _rate / 3600.0;

    String statusText;
    String description;
    Color statusColor;
    IconData statusIcon;
    Color statusBackground;

    if (readyToClaim) {
      statusText = 'READY TO CLAIM';
      description =
          'Your 24-hour mining session is complete and ready to claim.';
      statusColor = successGreen;
      statusIcon =
          Icons.check_circle_rounded;
      statusBackground = successLight;
    } else if (_isMining) {
      statusText = 'MINING...';
      description =
          'Your mining session is active. Keep mining FAN.';
      statusColor = primaryPurple;
      statusIcon = Icons.bolt_rounded;
      statusBackground =
          const Color(0xFFF0EEFA);
    } else {
      statusText = 'READY';
      description =
          'Start mining to earn FAN.';
      statusColor = successGreen;
      statusIcon =
          Icons.construction_rounded;
      statusBackground =
          const Color(0xFFF0EEFA);
    }

    String buttonText;

    if (_claimAdWaiting) {
      buttonText = 'WATCHING AD...';
    } else if (_busy && readyToClaim) {
      buttonText = 'PROCESSING...';
    } else if (readyToClaim) {
      /*
       * User requested:
       * after 24 hours the button must say CLAIM.
       */
      buttonText = 'CLAIM';
    } else if (_isMining) {
      buttonText = 'MINING';
    } else {
      buttonText = 'START MINING';
    }

    return _card(
      padding: const EdgeInsets.fromLTRB(
        15,
        14,
        15,
        15,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                statusIcon,
                background: statusBackground,
                iconColor: statusColor,
                size: 52,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style:
                            const TextStyle(
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
                            text: statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Divider(
            height: 1,
            color: Colors.grey.shade300,
          ),
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
                height: 39,
                color: Colors.grey.shade200,
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
          const SizedBox(height: 5),
          Text(
            'Per second: ${fanPerSecond.toStringAsFixed(8)} FAN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: deepPurple,
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
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
                      : readyToClaim
                          ? _claimMining
                          : _isMining
                              ? null
                              : _startMining,
              icon: Icon(
                _claimAdWaiting
                    ? Icons
                        .ondemand_video_rounded
                    : readyToClaim
                        ? Icons
                            .card_giftcard_rounded
                        : _isMining
                            ? Icons.bolt_rounded
                            : Icons
                                .construction_rounded,
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
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                textStyle:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
          if (_claimAdWaiting) ...[
            const SizedBox(height: 8),
            const Text(
              'Complete the rewarded ad. Your FAN will be claimed after verification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: deepPurple,
                fontSize: 10,
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
      padding: const EdgeInsets.fromLTRB(
        15,
        14,
        15,
        13,
      ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: const [
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
              const SizedBox(width: 7),
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed:
                      canWatch
                          ? _watchAd
                          : null,
                  icon: const Icon(
                    Icons
                        .ondemand_video_rounded,
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
                    elevation:
                        const WidgetStatePropertyAll(
                      0,
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
          const SizedBox(height: 10),
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
            child: LinearProgressIndicator(
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

  // ============================================================
  // SOCIAL CARD
  // ============================================================

  Widget _buildSocialCard() {
    final task =
        _tasks.isNotEmpty
            ? _tasks.first
            : null;

    /*
     * Official daily social reward = 10 FAN.
     */
    final reward =
        task?.rewardFan ?? 10.0;

    final taskLabel =
        task == null
            ? 'Follow us on social media'
            : task.title.isNotEmpty
                ? task.title
                : 'Complete today’s social task';

    return _card(
      padding: const EdgeInsets.fromLTRB(
        15,
        13,
        15,
        13,
      ),
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

  // ============================================================
  // KYC CARD
  // ============================================================

  Widget _buildKycCard() {
    final verified =
        _kycStatus.isVerified;

    return _card(
      padding: const EdgeInsets.fromLTRB(
        15,
        13,
        12,
        13,
      ),
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
                horizontal: 9,
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

  // ============================================================
  // CARD
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(15),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // CIRCLE ICON
  // ============================================================

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

  // ============================================================
  // MINING INFO
  // ============================================================

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
                  style: const TextStyle(
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
                  style: const TextStyle(
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

  // ============================================================
  // SOCIAL ICON
  // ============================================================

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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

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

  // ============================================================
  // FORMAT FAN
  // ============================================================

  String _formatFan(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  // ============================================================
  // DOUBLE
  // ============================================================

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

  // ============================================================
  // INT
  // ============================================================

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

  // ============================================================
  // BOOL
  // ============================================================

  bool _toBool(
    dynamic value,
  ) {
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
        value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y';
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

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

  // ============================================================
  // ERROR
  // ============================================================

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

  // ============================================================
  // MESSAGE
  // ============================================================

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
