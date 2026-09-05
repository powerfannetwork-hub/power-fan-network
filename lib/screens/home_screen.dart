import 'dart:async';

import 'package:flutter/material.dart';

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

  final MiningService _mining = MiningService.instance;
  final SocialTaskService _social = SocialTaskService();

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

  String _t(String key) {
    return AppLocalizations.of(context).translate(key);
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

  Future<void> _loadProfile() async {
    final data = await _mining.getProfile();

    if (!mounted) return;

    setState(() {
      _fan = _num(data['fan_balance']);
      _afam = _num(data['afam_balance']);
    });
  }

  Future<void> _loadMining() async {
    final data = await _mining.getActiveMining();

    final serverRate = await _mining.getUserMiningRate();

    final started = _date(
      data['started_at'] ?? data['start_time'],
    );

    final ends = _date(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'],
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

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining = active == true;
      _canClaim = claimable == true;

      _startedAt = started;
      _endsAt = ends;

      _rate = rate > 0 ? rate : serverRate;
      _ads = _int(ads).clamp(0, 7);

      _updateTime();

      if (_isMining && _endsAt != null) {
        _startTimer();
      }
    });
  }

  Future<void> _loadTasks() async {
    final tasks = await _social.getDailyTasksForCard();

    if (!mounted) return;

    setState(() {
      _tasks = tasks;
    });
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        if (!mounted) return;

        _updateTime();

        if (_remaining <= Duration.zero && _isMining) {
          _timer?.cancel();

          /*
           * Ask Supabase again.
           * Supabase is the authority for claimable status.
           */
          try {
            final data = await _mining.getActiveMining();

            if (!mounted) return;

            final active =
                data['active'] ??
                data['is_mining'] ??
                data['is_active'] ??
                false;

            final claimable =
                data['claimable'] ?? false;

            setState(() {
              _isMining = active == true;
              _canClaim = claimable == true;
              _remaining = Duration.zero;

              if (!_isMining) {
                _elapsed = const Duration(hours: 24);
              }
            });
          } catch (_) {
            if (!mounted) return;

            setState(() {
              _isMining = false;
              _canClaim = true;
              _remaining = Duration.zero;
              _elapsed = const Duration(hours: 24);
            });
          }
        } else {
          setState(() {});
        }
      },
    );
  }

  void _updateTime() {
    if (_endsAt != null) {
      final remaining =
          _endsAt!.difference(DateTime.now());

      _remaining = remaining.isNegative
          ? Duration.zero
          : remaining;
    } else {
      _remaining = Duration.zero;
    }

    if (_startedAt != null) {
      final elapsed =
          DateTime.now().difference(_startedAt!);

      _elapsed = elapsed.isNegative
          ? Duration.zero
          : elapsed;

      if (_elapsed >
          const Duration(hours: 24)) {
        _elapsed = const Duration(hours: 24);
      }
    }
  }

  double get _earned {
    if (!_isMining) {
      return 0;
    }

    if (_rate <= 0 || _elapsed.inSeconds <= 0) {
      return 0;
    }

    return _rate * (_elapsed.inSeconds / 3600.0);
  }

  Future<void> _startMining() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final result = await _mining.startMining();

      if (result['success'] == false) {
        throw Exception(
          result['message'] ??
              'Unable to start mining.',
        );
      }

      await _loadMining();

      _message(
        _t('mining_started_successfully'),
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

  Future<void> _claimMining() async {
    if (_busy) return;

    /*
     * Refresh from server immediately before claiming.
     * This prevents the UI from claiming too early.
     */
    try {
      final latest = await _mining.getActiveMining();

      if (!mounted) return;

      final active =
          latest['active'] ??
          latest['is_mining'] ??
          latest['is_active'] ??
          false;

      final claimable =
          latest['claimable'] ?? false;

      if (active == true || claimable != true) {
        await _loadMining();

        _message(
          _t('mining_session_still_active'),
        );

        return;
      }

      setState(() {
        _canClaim = true;
        _isMining = false;
        _remaining = Duration.zero;
      });
    } catch (e) {
      _message(_error(e));
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result = await _mining.claimMining();

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to claim mining reward.',
        );
      }

      final earned = _num(result['earned']);

      await _loadProfile();
      await _loadMining();

      _message(
        '${earned.toStringAsFixed(4)} FAN '
        '${_t('claimed_successfully')}',
      );
    } catch (e) {
      _message(_error(e));

      /*
       * Always reload after a failed claim.
       * The server remains the source of truth.
       */
      await _loadMining();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
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
      final result = await _social.startTask(
        taskId: task.id,
      );

      if (result['success'] == false) {
        throw Exception(
          result['message'] ??
              _t('unable_start_task'),
        );
      }

      final opened =
          await _social.openTaskUrl(task.url);

      if (!opened) {
        throw Exception(
          _t('unable_open_task'),
        );
      }

      await _loadTasks();

      final updated = _tasks.firstWhere(
        (x) => x.id == task.id,
        orElse: () => task,
      );

      /*
       * Claim only when Supabase says can_claim.
       * No fake verification is performed here.
       */
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
            '${_t('earned')}',
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

  /*
   * Rewarded Ad:
   *
   * The actual ad SDK is not called from this screen because
   * MiningService already contains the server-side methods
   * recordAndVerifyRewardedAd().
   *
   * This method records/verifies the completed reward with
   * Supabase. The actual AppLovin/AdMob display should call
   * this only after the ad has genuinely completed.
   */
  Future<void> _rewardAdCompleted({
    String? adReference,
  }) async {
    if (_busy || !_isMining || _ads >= 7) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _mining.recordAndVerifyRewardedAd(
        adReference: adReference,
      );

      if (result['success'] == false) {
        throw Exception(
          result['message'] ??
              'Unable to verify rewarded ad.',
        );
      }

      await _loadMining();

      _message(
        '+0.10 FAN/H ${_t('boost_added')}',
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _load,
        child: ListView(
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
                _t('mine_fan_earn_more'),
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
            _t('balance'),
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

  Widget _miningCard() {
    final status = _isMining
        ? _t('mining')
        : _canClaim
            ? _t('ready_to_claim')
            : _t('ready');

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
                      '${_t('status')}: $status',
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
                          ? _t('mining_fan_active')
                          : _canClaim
                              ? _t(
                                  'mining_session_ended',
                                )
                              : _t(
                                  'start_mining_earn_fan',
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
                  _t('mining_rate'),
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
                  _t('session_time'),
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
                          ? _t('claim_mining')
                          : _isMining
                              ? _t('mining_loading')
                              : _t('start_mining'),
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

  Widget _boostCard() {
    final limit = _ads >= 7;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.rocket_launch_rounded,
                orange: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('boost_by_watching_ads'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$_ads / 7',
                style: const TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _ads / 7,
                  minHeight: 7,
                  backgroundColor:
                      const Color(0xFFEDEAF7),
                  valueColor:
                      const AlwaysStoppedAnimation(
                    primaryPurple,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '+${(_ads * .1).toStringAsFixed(1)} FAN/H',
                style: const TextStyle(
                  color: primaryPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 43,
            child: OutlinedButton.icon(
              onPressed:
                  limit || !_isMining || _busy
                      ? null
                      : () {
                          /*
                           * This callback only verifies a
                           * completed ad. The ad provider's
                           * "reward earned" callback should
                           * call _rewardAdCompleted().
                           */
                          _message(
                            _t('rewarded_ad_not_connected'),
                          );
                        },
              icon: const Icon(
                Icons.ondemand_video_rounded,
              ),
              label: Text(
                limit
                    ? _t('daily_limit_reached')
                    : !_isMining
                        ? _t(
                            'start_mining_watch_ads',
                          )
                        : _t('watch_ad'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tasksSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _t('daily_task'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t('complete_social_tasks'),
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
                _t('no_daily_tasks'),
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

  Widget _task(DailySocialTask task) {
    return InkWell(
      onTap: task.claimed
          ? null
          : () => _openTask(task),
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
              child: Text(
                task.title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              task.claimed
                  ? _t('claimed')
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
              _t('kyc_verification'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _t('coming_soon'),
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
        color:
            orange ? Colors.deepOrange : primaryPurple,
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

  IconData _platformIcon(String platform) {
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

  double _progress() {
    const total = 86400;

    final elapsed =
        total - _remaining.inSeconds;

    if (elapsed <= 0) return 0;
    if (elapsed >= total) return 1;

    return elapsed / total;
  }

  String _format(Duration d) {
    final h = d.inHours
        .toString()
        .padLeft(2, '0');

    final m = d.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final s = d.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$h:$m:$s';
  }

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
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime? _date(dynamic value) {
    if (value is DateTime) {
      return value.toLocal();
    }

    if (value == null) return null;

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  String _error(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    return text;
  }

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
