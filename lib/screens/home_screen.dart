import 'dart:async';

import 'package:flutter/material.dart';

import '../components/boost_ads_card.dart';
import '../localization/app_localizations.dart';
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

  static const Duration miningDuration =
      Duration(hours: 24);

  final MiningService _mining =
      MiningService.instance;

  final SocialTaskService _social =
      SocialTaskService();

  Timer? _timer;

  bool _loading = true;
  bool _busy = false;
  bool _isMining = false;
  bool _canClaim = false;

  double _fan = 0;
  double _afam = 0;
  double _rate = 0.20;

  int _ads = 0;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Duration _remaining = Duration.zero;
  Duration _elapsed = Duration.zero;

  List<DailySocialTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _t(
    String key, [
    String fallback = '',
  ]) {
    final value =
        AppLocalizations.of(context).translate(key);

    if (value.isEmpty || value == key) {
      return fallback.isEmpty ? key : fallback;
    }

    return value;
  }

  // ============================================================
  // LOAD EVERYTHING
  // ============================================================

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
      ]);
    } catch (e) {
      _message(_error(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final data =
        await _mining.getProfile();

    if (!mounted) return;

    setState(() {
      _fan = _num(data['fan_balance']);
      _afam = _num(data['afam_balance']);
    });
  }

  // ============================================================
  // MINING
  // ============================================================

  Future<void> _loadMining() async {
    final data =
        await _mining.getActiveMining();

    final serverRate =
        await _mining.getUserMiningRate();

    final started = _date(
      data['started_at'] ??
          data['start_time'] ??
          data['started'],
    );

    final ends = _date(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'],
    );

    final active =
        data['active'] ??
        data['is_mining'] ??
        data['is_active'] ??
        false;

    final claimable =
        data['claimable'] ?? false;

    final ads =
        data['ads_watched'] ??
        data['ad_count'] ??
        data['ads_count'] ??
        0;

    final rate = _num(
      data['rate'] ??
          data['mining_rate'] ??
          serverRate,
    );

    final serverRemaining =
        _int(data['remaining_seconds']);

    final serverElapsed =
        _int(data['elapsed_seconds']);

    if (!mounted) return;

    _timer?.cancel();

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

    setState(() {
      _isMining = active == true;
      _canClaim = claimable == true;

      _startedAt = finalStarted;
      _endsAt = finalEnds;

      _rate =
          rate > 0 ? rate : serverRate;

      _ads = _int(ads).clamp(0, 7);

      if (serverRemaining > 0) {
        _remaining = Duration(
          seconds: serverRemaining,
        );
      } else {
        _updateTime();
      }

      if (serverElapsed > 0) {
        _elapsed = Duration(
          seconds: serverElapsed.clamp(
            0,
            miningDuration.inSeconds,
          ),
        );
      } else {
        _updateTime();
      }
    });

    if (_isMining) {
      _startTimer();
    }
  }

  // ============================================================
  // TIMER
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

        _updateTime();

        if (_remaining <= Duration.zero) {
          _timer?.cancel();

          _finishMiningLocally();

          _refreshMiningAfterEnd();

          return;
        }

        setState(() {});
      },
    );
  }

  void _updateTime() {
    final now = DateTime.now();

    if (_endsAt != null) {
      final remaining =
          _endsAt!.difference(now);

      _remaining = remaining.isNegative
          ? Duration.zero
          : remaining;
    } else {
      _remaining = Duration.zero;
    }

    if (_startedAt != null) {
      final elapsed =
          now.difference(_startedAt!);

      if (elapsed.isNegative) {
        _elapsed = Duration.zero;
      } else if (elapsed > miningDuration) {
        _elapsed = miningDuration;
      } else {
        _elapsed = elapsed;
      }
    } else if (_endsAt != null) {
      final calculatedStart =
          _endsAt!.subtract(miningDuration);

      final elapsed =
          now.difference(calculatedStart);

      if (elapsed.isNegative) {
        _elapsed = Duration.zero;
      } else if (elapsed > miningDuration) {
        _elapsed = miningDuration;
      } else {
        _elapsed = elapsed;
      }
    }
  }

  void _finishMiningLocally() {
    if (!mounted) return;

    setState(() {
      _isMining = false;
      _canClaim = true;
      _remaining = Duration.zero;
      _elapsed = miningDuration;
    });
  }

  Future<void> _refreshMiningAfterEnd() async {
    try {
      final data =
          await _mining.getActiveMining();

      if (!mounted) return;

      final active =
          data['active'] ??
          data['is_mining'] ??
          data['is_active'] ??
          false;

      final claimable =
          data['claimable'] ?? true;

      setState(() {
        _isMining = active == true;
        _canClaim = claimable == true;

        if (_isMining) {
          _updateTime();
          _startTimer();
        } else {
          _remaining = Duration.zero;
          _elapsed = miningDuration;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isMining = false;
        _canClaim = true;
        _remaining = Duration.zero;
        _elapsed = miningDuration;
      });
    }
  }

  // ============================================================
  // LIVE FAN EARNINGS
  // ============================================================

  double get _earned {
    if (!_isMining) return 0;

    if (_rate <= 0) return 0;

    if (_elapsed.inSeconds <= 0) return 0;

    return _rate *
        (_elapsed.inSeconds / 3600.0);
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<void> _startMining() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _mining.startMining();

      if (result['success'] == false) {
        throw Exception(
          result['message'] ??
              'Unable to start mining.',
        );
      }

      await _loadMining();

      _message(
        _t(
          'mining_started_successfully',
          'Mining started successfully.',
        ),
      );
    } catch (e) {
      _message(_error(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<void> _claimMining() async {
    if (_busy) return;

    try {
      final latest =
          await _mining.getActiveMining();

      if (!mounted) return;

      final active =
          latest['active'] ??
          latest['is_mining'] ??
          latest['is_active'] ??
          false;

      final claimable =
          latest['claimable'] ?? false;

      if (active == true ||
          claimable != true) {
        await _loadMining();

        _message(
          _t(
            'mining_session_still_active',
            'Mining session is still active.',
          ),
        );

        return;
      }

      setState(() {
        _canClaim = true;
        _isMining = false;
        _remaining = Duration.zero;
        _elapsed = miningDuration;
      });
    } catch (e) {
      _message(_error(e));
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _mining.claimMining();

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to claim mining reward.',
        );
      }

      final earned =
          _num(result['earned']);

      await _loadProfile();
      await _loadMining();

      _message(
        '${earned.toStringAsFixed(4)} FAN '
        '${_t(
          'claimed_successfully',
          'claimed successfully.',
        )}',
      );
    } catch (e) {
      _message(_error(e));
      await _loadMining();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
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

  Future<void> _openTask(
    DailySocialTask task,
  ) async {
    if (_busy || task.claimed) return;

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _social.startTask(
        taskId: task.id,
      );

      if (result['success'] == false) {
        throw Exception(
          result['message'] ??
              _t(
                'unable_start_task',
                'Unable to start task.',
              ),
        );
      }

      final opened =
          await _social.openTaskUrl(
        task.url,
      );

      if (!opened) {
        throw Exception(
          _t(
            'unable_open_task',
            'Unable to open task.',
          ),
        );
      }

      await _loadTasks();

      final updated = _tasks.firstWhere(
        (x) => x.id == task.id,
        orElse: () => task,
      );

      if (updated.canClaim &&
          !updated.claimed) {
        final claim =
            await _social.verifyAndClaim(
          taskId: task.id,
        );

        if (claim['success'] == true) {
          await _loadProfile();
          await _loadTasks();

          _message(
            '+${task.rewardFan.toStringAsFixed(0)} FAN '
            '${_t('earned', 'earned')}',
          );
        }
      }
    } catch (e) {
      _message(_error(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            color: primaryPurple,
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _load,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            28,
          ),
          children: [
            _header(),
            const SizedBox(height: 17),
            _balanceCard(),
            const SizedBox(height: 15),
            _miningCard(),
            const SizedBox(height: 14),
            _boostCard(),
            const SizedBox(height: 16),
            _tasksSection(),
            const SizedBox(height: 16),
            _kycCard(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                primaryPurple,
                deepPurple,
              ],
            ),
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: const Center(
            child: Text(
              'PF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'POWER FAN',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: deepPurple,
                ),
              ),
              Text(
                _t(
                  'mine_fan_earn_more',
                  'Mine FAN. Earn More',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: deepPurple,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: deepPurple,
            size: 28,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BALANCE
  // ============================================================

  Widget _balanceCard() {
    final balance =
        _fan + (_isMining ? _earned : 0);

    return Container(
      height: 184,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4520B6),
            Color(0xFF28106D),
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      padding: const EdgeInsets.fromLTRB(
        21,
        20,
        20,
        16,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            _t('balance', 'Balance'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(4)} FAN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '≈ \$0.00',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'AFAM ${_afam.toStringAsFixed(4)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MINING CARD
  // ============================================================

  Widget _miningCard() {
    final status = _isMining
        ? _t('mining', 'Mining')
        : _canClaim
            ? _t(
                'ready_to_claim',
                'Ready to Claim',
              )
            : _t('ready', 'Ready');

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.hardware_rounded,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_t('status', 'Status')}: $status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                        color: _isMining
                            ? Colors.orange
                            : _canClaim
                                ? Colors.blue
                                : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMining
                          ? _t(
                              'mining_fan_active',
                              'FAN mining is active',
                            )
                          : _canClaim
                              ? _t(
                                  'mining_session_ended',
                                  'Mining session ended. Claim your reward.',
                                )
                              : _t(
                                  'start_mining_earn_fan',
                                  'Start mining and earn FAN.',
                                ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF646477),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _info(
                  Icons.speed_rounded,
                  _t(
                    'mining_rate',
                    'Mining Rate',
                  ),
                  '${_rate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              Container(
                width: 1,
                height: 47,
                color: Colors.grey.shade300,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _info(
                  Icons.access_time_rounded,
                  _t(
                    'session_time',
                    'Session Time',
                  ),
                  '${_format(_remaining)} / 24:00:00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _progress(),
            minHeight: 6,
            backgroundColor:
                const Color(0xFFEDEAF7),
            valueColor:
                const AlwaysStoppedAnimation(
              primaryPurple,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton(
              onPressed: _busy
                  ? null
                  : _canClaim
                      ? _claimMining
                      : _isMining
                          ? null
                          : _startMining,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                disabledBackgroundColor:
                    primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _canClaim
                          ? _t(
                              'claim_mining',
                              'CLAIM MINING',
                            )
                          : _isMining
                              ? _t(
                                  'mining_active',
                                  'MINING',
                                )
                              : _t(
                                  'start_mining',
                                  'START MINING',
                                ),
                      style: const TextStyle(
                        color: Colors.white,
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

  // ============================================================
  // REAL REWARDED ADS BOOST
  // ============================================================

  Widget _boostCard() {
    return BoostAdsCard(
      isMining: _isMining,
      onRewarded: _onRewardedAdCompleted,
    );
  }

  Future<void> _onRewardedAdCompleted() async {
    if (!mounted) return;

    /*
     * AppLovin reward callback has already happened
     * and BoostAdsCard has already called:
     *
     * recordRewardedAd()
     * verifyRewardedAd(adId)
     *
     * Now refresh Home data from Supabase.
     */
    try {
      await Future.wait([
        _loadProfile(),
        _loadMining(),
      ]);
    } catch (_) {
      // Reward already verified; refresh failure
      // should not remove the reward.
    }

    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // SOCIAL TASK SECTION
  // ============================================================

  Widget _tasksSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            'daily_task',
            'Daily Tasks',
          ),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            'complete_social_tasks',
            'Complete social tasks and earn FAN.',
          ),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 11),
        if (_tasks.isEmpty)
          _card(
            child: Center(
              child: Text(
                _t(
                  'no_daily_tasks',
                  'No daily tasks available.',
                ),
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ..._tasks.map(_task),
      ],
    );
  }

  Widget _task(
    DailySocialTask task,
  ) {
    return InkWell(
      onTap: task.claimed
          ? null
          : () => _openTask(task),
      borderRadius:
          BorderRadius.circular(19),
      child: _card(
        margin:
            const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            _circleIcon(
              _platformIcon(task.platform),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (task.description
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              task.claimed
                  ? _t(
                      'claimed',
                      'Claimed',
                    )
                  : '+${task.rewardFan.toStringAsFixed(0)} FAN',
              style: TextStyle(
                color: task.claimed
                    ? Colors.green
                    : primaryPurple,
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // KYC
  // ============================================================

  Widget _kycCard() {
    return _card(
      child: Row(
        children: [
          _circleIcon(
            Icons.shield_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _t(
                'kyc_verification',
                'KYC Verification',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _t(
              'coming_soon',
              'COMING SOON',
            ),
            style: const TextStyle(
              color: primaryPurple,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(17),
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: child,
    );
  }

  Widget _circleIcon(
    IconData icon, {
    bool orange = false,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: orange
            ? Colors.orange.withOpacity(.10)
            : primaryPurple.withOpacity(.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: orange
            ? Colors.deepOrange
            : primaryPurple,
      ),
    );
  }

  Widget _info(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryPurple,
          size: 29,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryPurple,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _platformIcon(
    String platform,
  ) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook_rounded;

      case 'telegram':
        return Icons.send_rounded;

      case 'instagram':
        return Icons.camera_alt_rounded;

      case 'youtube':
        return Icons.play_arrow_rounded;

      case 'tiktok':
        return Icons.music_note_rounded;

      case 'x':
      case 'twitter':
        return Icons.close_rounded;

      default:
        return Icons.public_rounded;
    }
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  double _progress() {
    final total =
        miningDuration.inSeconds;

    final elapsed =
        _elapsed.inSeconds;

    if (elapsed <= 0) return 0;

    if (elapsed >= total) return 1;

    return elapsed / total;
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _format(Duration duration) {
    final h = duration.inHours
        .toString()
        .padLeft(2, '0');

    final m = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final s = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$h:$m:$s';
  }

  // ============================================================
  // NUMBER HELPERS
  // ============================================================

  double _num(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _int(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // DATE HELPER
  // ============================================================

  DateTime? _date(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is num) {
      return _timestamp(value);
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final iso =
        DateTime.tryParse(text);

    if (iso != null) {
      return iso.toLocal();
    }

    final numeric =
        num.tryParse(text);

    if (numeric != null) {
      return _timestamp(numeric);
    }

    return null;
  }

  DateTime? _timestamp(num value) {
    try {
      final timestamp = value.toInt();

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
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _error(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    if (text.trim().isEmpty) {
      return _t(
        'somethingWentWrong',
        'Something went wrong.',
      );
    }

    return text.trim();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}
