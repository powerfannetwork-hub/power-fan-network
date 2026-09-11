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
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color pageBackground = Color(0xFFF8F8FC);

  static const Color successGreen = Color(0xFF238B57);
  static const Color successLight = Color(0xFFEAF8F0);

  // ============================================================
  // MINING RULES
  // ============================================================

  static const Duration miningDuration =
      Duration(hours: 24);

  static const int maxAds = 7;

  // ============================================================
  // SERVICES
  // ============================================================

  final MiningService _mining =
      MiningService.instance;

  final SocialTaskService _social =
      SocialTaskService();

  final KycService _kyc =
      KycService();

  final LevelPlayAdsService _ads =
      LevelPlayAdsService.instance;

  // ============================================================
  // TIMER
  // ============================================================

  Timer? _timer;

  // ============================================================
  // SCREEN STATE
  // ============================================================

  bool _loading = true;

  bool _busy = false;

  bool _isMining = false;

  bool _canClaim = false;

  bool _claimAdWaiting = false;

  // ============================================================
  // FAN
  // ============================================================

  double _fan = 0.0;

  double _rate =
      MiningService.defaultMiningRate;

  double _sessionReward = 0.0;

  // ============================================================
  // MINING TIME
  // ============================================================

  DateTime? _startedAt;

  DateTime? _endsAt;

  Duration _remaining =
      Duration.zero;

  // ============================================================
  // ADS
  // ============================================================

  int _adsWatched = 0;

  // ============================================================
  // SOCIAL
  // ============================================================

  List<DailySocialTask> _tasks = [];

  // ============================================================
  // KYC
  // ============================================================

  KycStatus _kycStatus =
      KycStatus.initial();

  // ============================================================
  // INIT
  // ============================================================

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
    } catch (_) {
      // Ads must never stop HomeScreen from opening.
    }
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

  // ============================================================
  // REFRESH
  // ============================================================

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

  // ============================================================
  // MINING LOAD
  // ============================================================

  Future<void> _loadMining() async {
    final data =
        await _mining.getActiveMining();

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
        _rate =
            MiningService.defaultMiningRate;
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

    final status = data['status']
        ?.toString()
        .trim()
        .toLowerCase();

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

    var rate = _toDouble(
      data['total_rate'] ??
          data['mining_rate'] ??
          data['rate'],
    );

    if (rate <= 0) {
      try {
        rate =
            await _mining.getUserMiningRate();
      } catch (_) {
        rate =
            MiningService.defaultMiningRate;
      }
    }

    if (rate <= 0) {
      rate =
          MiningService.defaultMiningRate;
    }

    final ads = _toInt(
      data['ads_watched'] ??
          data['ad_count'] ??
          data['ads_count'] ??
          data['daily_ads_watched'],
    );

    final serverRemaining = _toInt(
      data['remaining_seconds'] ??
          data['seconds_remaining'],
    );

    final serverReward = _toDouble(
      data['reward'] ??
          data['session_reward'] ??
          data['earned_reward'],
    );

    DateTime? finalStarted =
        started;

    DateTime? finalEnds =
        ends;

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

    final now =
        DateTime.now();

    Duration remaining =
        Duration.zero;

    if (finalEnds != null) {
      remaining =
          finalEnds.difference(now);

      if (remaining.isNegative) {
        remaining =
            Duration.zero;
      }
    } else if (serverRemaining > 0) {
      remaining =
          Duration(
        seconds: serverRemaining,
      );
    }

    if (remaining >
        miningDuration) {
      remaining =
          miningDuration;
    }

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
        data['mining_active'];

    final active =
        !explicitInactive &&
        (
          activeByTime ||
          activeByStatus ||
          activeFlag == true
        );

    final finalCanClaim =
        !alreadyClaimed &&
        !active &&
        (
          claimable ||
          statusIsClaimable ||
          sessionFinished
        );

    double liveReward =
        serverReward;

    if (liveReward <= 0 &&
        active &&
        finalStarted != null) {
      final elapsedSeconds =
          now.difference(
        finalStarted,
      ).inSeconds;

      if (elapsedSeconds > 0) {
        liveReward =
            (elapsedSeconds /
                    3600.0) *
                rate;
      }
    }

    if (finalCanClaim &&
        liveReward <= 0 &&
        rate > 0) {
      liveReward =
          (miningDuration
                      .inSeconds /
                  3600.0) *
              rate;
    }

    final explicitClaimRequired =
        _toBool(
          data['claim_required'],
        ) ||
        _toBool(
          data['requires_claim'],
        ) ||
        _toBool(
          data['needs_claim'],
        );

    final forceClaim =
        explicitClaimRequired &&
        !alreadyClaimed &&
        !active;

    final finalClaim =
        finalCanClaim ||
        forceClaim;

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining = active;

      _canClaim = finalClaim;

      _rate = rate;

      _startedAt =
          finalStarted;

      _endsAt =
          finalEnds;

      _remaining =
          remaining;

      _sessionReward =
          liveReward < 0
              ? 0.0
              : liveReward;

      _adsWatched = ads
          .clamp(
            0,
            maxAds,
          )
          .toInt();

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

  bool _isClaimableStatus(
    String? status,
  ) {
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
  // APPLY START RESPONSE
  // ============================================================

  void _applyMiningResult(
    Map<String, dynamic> data,
  ) {
    /*
     * IMPORTANT:
     *
     * A successful START MINING response must never
     * immediately turn the UI into READY TO CLAIM.
     *
     * We first look for server timestamps.
     * If the server response does not contain them,
     * we create the 24-hour UI countdown immediately.
     *
     * This fixes:
     *
     * START MINING
     *       ↓
     * READY TO CLAIM   ❌
     *
     * and makes it:
     *
     * START MINING
     *       ↓
     * 24:00:00
     *       ↓
     * 23:59:59
     *       ↓
     * ...
     *       ↓
     * 00:00:00
     *       ↓
     * READY TO CLAIM
     */

    final started =
        _parseDate(
      data['started_at'] ??
          data['start_time'] ??
          data['started'] ??
          data['mining_started_at'],
    );

    final ends =
        _parseDate(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'] ??
          data['mining_ends_at'],
    );

    DateTime? finalStarted =
        started;

    DateTime? finalEnds =
        ends;

    /*
     * If the backend returns only ends_at,
     * calculate started_at from the 24-hour session.
     */
    if (finalStarted == null &&
        finalEnds != null) {
      finalStarted =
          finalEnds.subtract(
        miningDuration,
      );
    }

    /*
     * If the backend returns only started_at,
     * calculate the exact 24-hour end.
     */
    if (finalEnds == null &&
        finalStarted != null) {
      finalEnds =
          finalStarted.add(
        miningDuration,
      );
    }

    /*
     * If the RPC response does not contain
     * timestamps at all, the START operation
     * itself was successful, so immediately
     * create the 24-hour countdown.
     */
    if (finalStarted == null ||
        finalEnds == null) {
      finalStarted =
          DateTime.now();

      finalEnds =
          finalStarted.add(
        miningDuration,
      );
    }

    final now =
        DateTime.now();

    var remaining =
        finalEnds.difference(now);

    if (remaining.isNegative) {
      remaining =
          Duration.zero;
    }

    if (remaining >
        miningDuration) {
      remaining =
          miningDuration;
    }

    /*
     * For a newly started session, the
     * session is ACTIVE as long as the
     * 24-hour end time is in the future.
     */
    final active =
        !finalStarted.isAfter(now) &&
        finalEnds.isAfter(now);

    final returnedRate =
        _toDouble(
      data['total_rate'] ??
          data['mining_rate'] ??
          data['rate'],
    );

    if (!mounted) return;

    /*
     * Never use claim_required here to turn
     * a successful START response into READY.
     *
     * claim_required belongs to an already
     * completed session. A successful start
     * must display the new 24-hour session.
     */
    setState(() {
      _startedAt =
          finalStarted;

      _endsAt =
          finalEnds;

      _remaining =
          remaining;

      if (returnedRate > 0) {
        _rate =
            returnedRate;
      }

      _isMining =
          active;

      _canClaim =
          !active &&
          remaining ==
              Duration.zero;

      if (active) {
        _sessionReward =
            0.0;
      }
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

    _timer =
        Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final started =
            _startedAt;

        final ends =
            _endsAt;

        if (started == null ||
            ends == null) {
          _timer?.cancel();
          return;
        }

        final now =
            DateTime.now();

        var remaining =
            ends.difference(now);

        if (remaining.isNegative) {
          remaining =
              Duration.zero;
        }

        if (remaining >
            miningDuration) {
          remaining =
              miningDuration;
        }

        final finished =
            remaining ==
                Duration.zero;

        if (finished) {
          _timer?.cancel();

          setState(() {
            _remaining =
                Duration.zero;

            _isMining =
                false;

            _canClaim =
                true;

            _sessionReward =
                _rate * 24.0;
          });

          return;
        }

        final elapsedSeconds =
            now.difference(
          started,
        ).inSeconds;

        double displayReward =
            _sessionReward;

        if (elapsedSeconds >= 0) {
          displayReward =
              (elapsedSeconds /
                      3600.0) *
                  _rate;
        }

        setState(() {
          _remaining =
              remaining;

          _sessionReward =
              displayReward;
        });
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
        /*
         * Only a genuine failed START with
         * claim_required should show claim.
         *
         * This is NOT used for a successful
         * START response anymore.
         */
        final claimRequired =
            _toBool(
              result['claim_required'],
            ) ||
            _toBool(
              result['requires_claim'],
            ) ||
            _toBool(
              result['needs_claim'],
            );

        if (claimRequired) {
          if (mounted) {
            setState(() {
              _isMining =
                  false;

              _canClaim =
                  true;

              _remaining =
                  Duration.zero;
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

      /*
       * IMPORTANT:
       *
       * Do not call _loadMining() first.
       *
       * We immediately apply the successful
       * START response so the user sees
       * 24:00:00 without the UI jumping
       * through READY TO CLAIM.
       */
      _applyMiningResult(
        result,
      );

      /*
       * If the response did not contain
       * timestamps, _applyMiningResult()
       * already created the 24-hour timer.
       */
      if (!mounted) return;

      if (!_isMining) {
        /*
         * The RPC succeeded but returned
         * incomplete timing data.
         *
         * Force the new 24-hour session
         * into the UI immediately.
         */
        final now =
            DateTime.now();

        _timer?.cancel();

        setState(() {
          _startedAt =
              now;

          _endsAt =
              now.add(
            miningDuration,
          );

          _remaining =
              miningDuration;

          _isMining =
              true;

          _canClaim =
              false;

          _sessionReward =
              0.0;
        });

        _startTimer();
      }

      await _loadProfile();

      if (!mounted) return;

      /*
       * Do NOT immediately replace the newly
       * started local countdown with a stale
       * completed-session response.
       *
       * The timer is already authoritative
       * from the server start response / new
       * 24-hour fallback.
       */
      _message(
        'Mining started successfully.',
      );
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

      if (claimRequired &&
          mounted) {
        setState(() {
          _isMining =
              false;

          _canClaim =
              true;

          _remaining =
              Duration.zero;
        });

        _message(
          'Your completed mining session is ready to claim.',
        );
      } else if (mounted) {
        _message(
          _error(e),
        );
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

    final ends =
        _endsAt;

    if (ends != null &&
        DateTime.now().isBefore(
          ends,
        )) {
      final difference =
          ends.difference(
        DateTime.now(),
      );

      if (mounted) {
        _message(
          'Mining is still active. ${_formatDuration(difference)} remaining.',
        );
      }

      /*
       * Restart the countdown from the
       * existing server end timestamp.
       */
      setState(() {
        _isMining =
            true;

        _canClaim =
            false;

        _remaining =
            difference;
      });

      _startTimer();

      return;
    }

    setState(() {
      _busy = true;

      _claimAdWaiting =
          true;
    });

    try {
      try {
        await _ads.initialize();
      } catch (_) {}

      final adCompleted =
          Completer<bool>();

      var adCallbackReceived =
          false;

      final shown =
          await _ads.showRewardedAd(
        onRewarded: () {
          if (adCallbackReceived) {
            return;
          }

          adCallbackReceived =
              true;

          if (!adCompleted.isCompleted) {
            adCompleted.complete(
              true,
            );
          }
        },
        onAdClosed: () {},
      );

      if (!shown) {
        throw Exception(
          'Rewarded ad is not ready. Please wait a moment and try again.',
        );
      }

      final adVerified =
          await adCompleted.future
              .timeout(
        const Duration(
          seconds: 30,
        ),
        onTimeout: () => false,
      );

      if (!adVerified) {
        throw Exception(
          'Ad reward could not be verified. Your FAN was not claimed.',
        );
      }

      if (!mounted) return;

      /*
       * Do not require the UI to rediscover
       * the completed session here.
       *
       * The countdown has already reached
       * zero and _canClaim is true.
       */
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

      _timer?.cancel();

      setState(() {
        _sessionReward =
            0.0;

        _canClaim =
            false;

        _isMining =
            false;

        _remaining =
            Duration.zero;

        _startedAt =
            null;

        _endsAt =
            null;

        _adsWatched =
            0;
      });

      await _loadProfile();

      if (!mounted) return;

      /*
       * After CLAIM the button is immediately
       * START MINING again.
       */
      setState(() {
        _isMining =
            false;

        _canClaim =
            false;

        _remaining =
            Duration.zero;

        _startedAt =
            null;

        _endsAt =
            null;

        _sessionReward =
            0.0;

        _adsWatched =
            0;
      });

      _message(
        'Mining reward claimed successfully. You can start a new mining session.',
      );
    } catch (e) {
      if (mounted) {
        _message(
          _error(e),
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _busy = false;

        _claimAdWaiting =
            false;
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

    if (_adsWatched >=
        maxAds) {
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

      final shown =
          await _ads.showRewardedAd(
        onRewarded: () {},
        onAdClosed: () {},
      );

      if (!shown) {
        if (mounted) {
          _message(
            'Rewarded ad is not ready. Please try again.',
          );
        }

        return;
      }

      /*
       * Give the server callback a short
       * moment to update the ad reward before
       * reading the session again.
       */
      await Future<void>.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      await _loadMining();

      if (mounted) {
        if (_adsWatched >=
            maxAds) {
          _message(
            'Maximum 7 ads reached for this mining session.',
          );
        } else {
          _message(
            'Ad completed. Your mining boost has been updated.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _message(
          _error(e),
        );
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

    final task =
        _tasks.first;

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
        _message(
          _error(e),
        );
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
        _kycStatus =
            status;
      });
    } catch (_) {
      // KYC must never block HomeScreen.
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

    unawaited(
      _loadKyc(),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          pageBackground,
      body: SafeArea(
        child:
            RefreshIndicator(
          color:
              primaryPurple,
          onRefresh:
              _load,
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        primaryPurple,
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

                    const SizedBox(
                      height: 12,
                    ),

                    _buildBalanceCard(),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildMiningCard(),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildBoostCard(),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildSocialCard(),

                    const SizedBox(
                      height: 12,
                    ),

                    _buildKycCard(),

                    const SizedBox(
                      height: 10,
                    ),
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
          decoration:
              BoxDecoration(
            color:
                primaryPurple,
            borderRadius:
                BorderRadius.circular(
              15,
            ),
          ),
          alignment:
              Alignment.center,
          child:
              const Text(
            'AFAM',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child:
              Column(
            children: [
              const Text(
                'POWER FAN NETWORK',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      primaryPurple,
                  fontSize:
                      22,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      -0.5,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                'Mine FAN. Earn More',
                style:
                    TextStyle(
                  color:
                      Colors.indigo.shade900,
                  fontSize:
                      14,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Stack(
          clipBehavior:
              Clip.none,
          children: [
            const Icon(
              Icons
                  .notifications_none_rounded,
              color:
                  deepPurple,
              size:
                  35,
            ),

            Positioned(
              right: 0,
              top: 0,
              child:
                  Container(
                width: 9,
                height: 9,
                decoration:
                    const BoxDecoration(
                  color:
                      Colors.red,
                  shape:
                      BoxShape.circle,
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
        (
          (_isMining ||
                  _canClaim)
              ? _sessionReward
              : 0.0
        );

    return Container(
      height: 180,
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(
              0xFF4320B4,
            ),
            Color(
              0xFF29107A,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(
          23,
        ),
        boxShadow: [
          BoxShadow(
            color:
                primaryPurple
                    .withValues(
              alpha:
                  0.18,
            ),
            blurRadius:
                14,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child:
          Stack(
        children: [
          Positioned(
            right:
                -8,
            bottom:
                -16,
            child:
                Opacity(
              opacity:
                  0.20,
              child:
                  const Icon(
                Icons
                    .engineering_rounded,
                size:
                    150,
                color:
                    Colors.white,
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
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                Row(
                  children: [
                    Container(
                      width:
                          58,
                      height:
                          58,
                      decoration:
                          const BoxDecoration(
                        shape:
                            BoxShape.circle,
                        gradient:
                            LinearGradient(
                          colors: [
                            Color(
                              0xFFFFC928,
                            ),
                            Color(
                              0xFFFFA800,
                            ),
                          ],
                        ),
                      ),
                      alignment:
                          Alignment.center,
                      child:
                          Container(
                        width:
                            46,
                        height:
                            46,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFE89100,
                            ),
                            width:
                                2,
                          ),
                        ),
                        alignment:
                            Alignment.center,
                        child:
                            const Text(
                          'F',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFFE58A00,
                            ),
                            fontSize:
                                27,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    Flexible(
                      child:
                          Text(
                        displayedBalance
                            .toStringAsFixed(
                          8,
                        ),
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              31,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing:
                              -1,
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
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  '≈ \$0.00',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        14,
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
        _canClaim &&
        !_isMining;

    final buttonText =
        _claimAdWaiting
            ? 'WATCHING AD...'
            : _busy &&
                    isReadyToClaim
                ? 'PROCESSING...'
                : isReadyToClaim
                    ? 'READY TO CLAIM'
                    : _isMining
                        ? _formatDuration(
                            _remaining,
                          )
                        : 'START MINING';

    final buttonIcon =
        _claimAdWaiting
            ? Icons
                .ondemand_video_rounded
            : _busy &&
                    isReadyToClaim
                ? Icons
                    .hourglass_top_rounded
                : isReadyToClaim
                    ? Icons
                        .card_giftcard_rounded
                    : _isMining
                        ? Icons
                            .timer_rounded
                        : Icons
                            .construction_rounded;

    /*
     * IMPORTANT:
     *
     * No STATUS section.
     * No separate COUNTDOWN section.
     *
     * Only the completion message is
     * displayed when the session is ready.
     */
    final showCompletionMessage =
        isReadyToClaim;

    return _card(
      child:
          Column(
        children: [
          if (showCompletionMessage) ...[
            Row(
              children: [
                _circleIcon(
                  Icons
                      .check_circle_rounded,
                  background:
                      successLight,
                  iconColor:
                      successGreen,
                  size:
                      62,
                ),

                const SizedBox(
                  width: 13,
                ),

                const Expanded(
                  child:
                      Text(
                    'Your 24-hour mining session is complete and ready to claim.',
                    maxLines:
                        3,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      color:
                          Color(
                        0xFF66666F,
                      ),
                      fontSize:
                          13,
                      height:
                          1.35,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            const Divider(
              height: 1,
            ),

            const SizedBox(
              height: 12,
            ),
          ],

          if (!showCompletionMessage)
            const SizedBox(
              height: 2,
            ),

          Row(
            children: [
              Expanded(
                child:
                    _miningInfo(
                  Icons
                      .speed_rounded,
                  'MINING RATE',
                  '${_rate.toStringAsFixed(2)} FAN/H',
                ),
              ),

              Container(
                width:
                    1,
                height:
                    49,
                color:
                    Colors.grey.shade200,
              ),

              Expanded(
                child:
                    _miningInfo(
                  Icons
                      .bolt_rounded,
                  'BOOST',
                  '+${(_adsWatched * 0.10).toStringAsFixed(2)} FAN/H',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            'Per second: ${(_rate / 3600.0).toStringAsFixed(8)} FAN',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  deepPurple,
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          /*
           * THIS IS THE IMPORTANT BUTTON.
           *
           * START MINING
           *       ↓
           * 24:00:00
           *       ↓
           * 23:59:59
           *       ↓
           * ...
           *       ↓
           * 00:00:00
           *       ↓
           * READY TO CLAIM
           */
          SizedBox(
            width:
                double.infinity,
            height:
                55,
            child:
                ElevatedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : isReadyToClaim
                          ? _claimMining
                          : _isMining
                              ? null
                              : _startMining,
              icon:
                  Icon(
                buttonIcon,
                size:
                    23,
              ),
              label:
                  Text(
                buttonText,
                maxLines:
                    1,
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
                            alpha:
                                0.70,
                          )
                        : primaryPurple
                            .withValues(
                            alpha:
                                0.70,
                          ),
                disabledForegroundColor:
                    Colors.white,
                elevation:
                    0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                textStyle:
                    TextStyle(
                  fontSize:
                      _isMining
                          ? 17
                          : 16,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing:
                      _isMining
                          ? 0.6
                          : 0,
                ),
              ),
            ),
          ),

          if (_claimAdWaiting) ...[
            const SizedBox(
              height: 9,
            ),

            const Text(
              'Please complete the rewarded ad. Your FAN will be claimed after the ad is verified.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    deepPurple,
                fontSize:
                    11,
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
        (_adsWatched /
                maxAds)
            .clamp(
              0.0,
              1.0,
            )
            .toDouble();

    final canWatch =
        _isMining &&
        !_busy &&
        _adsWatched <
            maxAds;

    return _card(
      child:
          Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons
                    .rocket_launch_rounded,
                background:
                    const Color(
                  0xFFF0EEFA,
                ),
                iconColor:
                    Colors.red.shade700,
                size:
                    56,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children:
                      const [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style:
                          TextStyle(
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        color:
                            Color(
                          0xFF55555F,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              SizedBox(
                height:
                    48,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      canWatch
                          ? _watchAd
                          : null,
                  icon:
                      const Icon(
                    Icons
                        .ondemand_video_rounded,
                    size:
                        18,
                  ),
                  label:
                      const Text(
                    'WATCH AD',
                    style:
                        TextStyle(
                      fontSize:
                          11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  style:
                      ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty
                            .resolveWith(
                      (states) {
                        if (states
                            .contains(
                          WidgetState
                              .disabled,
                        )) {
                          return primaryPurple
                              .withValues(
                            alpha:
                                0.45,
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
                            12,
                          ),
                        ),
                      ),
                    ),
                    padding:
                        const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(
                        horizontal:
                            12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Row(
            children: [
              Text(
                'Ads watched: $_adsWatched / $maxAds',
                style:
                    const TextStyle(
                  color:
                      deepPurple,
                  fontSize:
                      12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                '+${(_adsWatched * 0.10).toStringAsFixed(1)} FAN/H',
                style:
                    const TextStyle(
                  color:
                      deepPurple,
                  fontSize:
                      12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            child:
                LinearProgressIndicator(
              value:
                  progress,
              minHeight:
                  8,
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

          const SizedBox(
            height: 5,
          ),

          Align(
            alignment:
                Alignment.centerRight,
            child:
                Text(
              _isMining
                  ? '7 ads maximum per session'
                  : 'Start mining before watching ads',
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize:
                    10,
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

    final reward =
        task?.rewardFan ??
            10.0;

    final taskLabel =
        task == null
            ? 'Follow us on social media'
            : task.title.isNotEmpty
                ? task.title
                : 'Complete today’s social task';

    return _card(
      child:
          Row(
        children: [
          _circleIcon(
            Icons
                .assignment_turned_in_rounded,
            background:
                successLight,
            iconColor:
                Colors.green.shade700,
            size:
                56,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY TASK',
                  style:
                      TextStyle(
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  taskLabel,
                  maxLines:
                      2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize:
                        12,
                    color:
                        Color(
                      0xFF55555F,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Reward: ${_formatFan(reward)} FAN',
                  style:
                      const TextStyle(
                    fontSize:
                        11,
                    color:
                        Color(
                      0xFF55555F,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Column(
            children: [
              Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _socialIcon(
                    'X',
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  _socialIcon(
                    '➤',
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  _socialIcon(
                    '◎',
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  _socialIcon(
                    '▶',
                  ),
                ],
              ),

              const SizedBox(
                height: 7,
              ),

              SizedBox(
                height:
                    40,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _socialAction,
                  icon:
                      const Icon(
                    Icons
                        .card_giftcard_rounded,
                    size:
                        16,
                  ),
                  label:
                      Text(
                    task?.canClaim ==
                            true
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
                        10,
                      ),
                    ),
                    textStyle:
                        const TextStyle(
                      fontSize:
                          9,
                      fontWeight:
                          FontWeight.w800,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          9,
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
      child:
          Row(
        children: [
          _circleIcon(
            Icons.shield_rounded,
            background:
                const Color(
              0xFFF0EEFA,
            ),
            iconColor:
                primaryPurple,
            size:
                56,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  verified
                      ? 'KYC VERIFIED'
                      : 'KYC VERIFICATION',
                  style:
                      const TextStyle(
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  verified
                      ? 'Your identity has been verified'
                      : 'Verify your identity to secure your account',
                  maxLines:
                      2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize:
                        11,
                    color:
                        Color(
                      0xFF55555F,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          OutlinedButton(
            onPressed:
                _busy
                    ? null
                    : _openKyc,
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  deepPurple,
              side:
                  const BorderSide(
                color:
                    deepPurple,
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
                horizontal:
                    11,
                vertical:
                    10,
              ),
            ),
            child:
                Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  verified
                      ? 'VIEW KYC'
                      : 'COMPLETE KYC',
                  style:
                      const TextStyle(
                    fontSize:
                        9,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  width: 3,
                ),
                const Icon(
                  Icons
                      .chevron_right_rounded,
                  size:
                      18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GENERAL CARD
  // ============================================================

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  0.045,
            ),
            blurRadius:
                11,
            offset:
                const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child:
          child,
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
      width:
          size,
      height:
          size,
      decoration:
          BoxDecoration(
        color:
            background,
        shape:
            BoxShape.circle,
      ),
      alignment:
          Alignment.center,
      child:
          Icon(
        icon,
        color:
            iconColor,
        size:
            size * 0.55,
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
        horizontal:
            8,
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            color:
                primaryPurple,
            size:
                31,
          ),

          const SizedBox(
            width:
                8,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize:
                        10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  value,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        deepPurple,
                    fontSize:
                        14,
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
  // SOCIAL ICON
  // ============================================================

  Widget _socialIcon(
    String text,
  ) {
    return Container(
      width:
          30,
      height:
          30,
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          8,
        ),
        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      alignment:
          Alignment.center,
      child:
          Text(
        text,
        style:
            const TextStyle(
          fontSize:
              13,
          fontWeight:
              FontWeight.w900,
          color:
              Colors.black,
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
      duration =
          Duration.zero;
    }

    final hours =
        duration.inHours
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minutes =
        (duration.inMinutes %
                60)
            .toString()
            .padLeft(
              2,
              '0',
            );

    final seconds =
        (duration.inSeconds %
                60)
            .toString()
            .padLeft(
              2,
              '0',
            );

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
      return value.toStringAsFixed(
        0,
      );
    }

    return value.toStringAsFixed(
      2,
    );
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
        value
            .toString()
            .trim()
            .toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y';
  }

  // ============================================================
  // DATE
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
        value
            .toString()
            .trim();

    if (text.isEmpty) {
      return null;
    }

    final parsed =
        DateTime.tryParse(
      text,
    );

    if (parsed != null) {
      return parsed.toLocal();
    }

    final numeric =
        num.tryParse(
      text,
    );

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
        isUtc:
            true,
      ).toLocal();
    }

    return DateTime
        .fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc:
          true,
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
      return text.substring(
        11,
      );
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

    ScaffoldMessenger.of(
      context,
    )
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
