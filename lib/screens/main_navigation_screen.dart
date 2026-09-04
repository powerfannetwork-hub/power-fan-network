import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mining_service.dart';
import '../services/social_task_service.dart';
import 'referral_screen.dart';
import 'wallet_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const _HomeInterface(),
      const ReferralScreen(),
      const WalletScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: 'HOME',
                index: 0,
              ),
              _navItem(
                icon: Icons.people_alt_rounded,
                label: 'REFERRAL',
                index: 1,
              ),
              _navItem(
                icon:
                    Icons.account_balance_wallet_rounded,
                label: 'WALLET',
                index: 2,
              ),
              _navItem(
                icon: Icons.settings_rounded,
                label: 'SETTINGS',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected
                  ? const Color(0xFF3B159B)
                  : Colors.grey.shade500,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: selected
                    ? const Color(0xFF3B159B)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeInterface extends StatefulWidget {
  const _HomeInterface();

  @override
  State<_HomeInterface> createState() =>
      _HomeInterfaceState();
}

class _HomeInterfaceState extends State<_HomeInterface> {
  static const Color primaryPurple =
      Color(0xFF3B159B);

  static const Color deepPurple =
      Color(0xFF241064);

  final MiningService _miningService =
      MiningService.instance;

  final SocialTaskService _socialTaskService =
      SocialTaskService();

  Timer? _timer;

  bool _loading = true;
  bool _actionLoading = false;

  double _fanBalance = 0;
  double _afamBalance = 0;
  double _miningRate = 0.20;

  bool _isMining = false;

  DateTime? _endsAt;

  Duration _remaining = Duration.zero;

  int _adsWatched = 0;

  List<DailySocialTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
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
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    final profile =
        await _miningService.getProfile();

    if (!mounted) return;

    setState(() {
      _fanBalance =
          _toDouble(profile['fan_balance']);

      _afamBalance =
          _toDouble(profile['afam_balance']);
    });
  }

  Future<void> _loadMining() async {
    final active =
        await _miningService.getActiveMining();

    final rate =
        await _miningService.getUserMiningRate();

    final endsAt = _parseDateTime(
      active['ends_at'] ??
          active['end_time'] ??
          active['expires_at'],
    );

    final mining =
        active['is_mining'] ??
            active['is_active'] ??
            false;

    final ads =
        active['ads_watched'] ??
            active['ad_count'] ??
            active['ads_count'] ??
            0;

    if (!mounted) return;

    setState(() {
      _isMining = mining == true;
      _endsAt = endsAt;

      _miningRate =
          rate <= 0 ? 0.20 : rate;

      _adsWatched =
          _toInt(ads).clamp(0, 7);

      _remaining =
          _calculateRemaining();

      if (_isMining && _endsAt != null) {
        _startCountdown();
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _loadTasks() async {
    final tasks =
        await _socialTaskService
            .getDailyTasksForCard();

    if (!mounted) return;

    setState(() {
      _tasks = tasks;
    });
  }

  Duration _calculateRemaining() {
    if (!_isMining || _endsAt == null) {
      return Duration.zero;
    }

    final difference =
        _endsAt!.difference(DateTime.now());

    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final remaining =
            _calculateRemaining();

        if (remaining <= Duration.zero) {
          _timer?.cancel();

          setState(() {
            _remaining = Duration.zero;
            _isMining = false;
          });

          _loadMining();
          return;
        }

        setState(() {
          _remaining = remaining;
        });
      },
    );
  }

  Future<void> _startMining() async {
    if (_actionLoading) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      await _miningService.startMining();

      await _loadMining();

      if (mounted) {
        _showMessage(
          'Mining started successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _claimMining() async {
    if (_actionLoading) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final result =
          await _miningService.claimMining();

      final earned = _extractNumber(
        result,
        [
          'earned',
          'earned_fan',
          'reward',
          'reward_fan',
          'amount',
        ],
      );

      await _loadProfile();
      await _loadMining();

      if (mounted) {
        if (earned > 0) {
          _showMessage(
            '${earned.toStringAsFixed(4)} FAN claimed successfully.',
          );
        } else {
          _showMessage(
            'Mining reward claimed successfully.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _openSocialTask(
    DailySocialTask task,
  ) async {
    if (task.claimed || _actionLoading) {
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      /*
       * Step 1:
       * Register/start the task on Supabase.
       */
      final startResult =
          await _socialTaskService.startTask(
        taskId: task.id,
      );

      if (startResult['success'] == false) {
        throw Exception(
          startResult['message'] ??
              'Unable to start this task.',
        );
      }

      /*
       * Step 2:
       * Open the social-media URL.
       */
      final opened =
          await _socialTaskService.openTaskUrl(
        task.url,
      );

      if (!opened) {
        throw Exception(
          'Unable to open the social task link.',
        );
      }

      /*
       * Step 3:
       * Reload the task status from Supabase.
       *
       * We intentionally DO NOT fake verification
       * by waiting for 2 seconds.
       */
      await _loadTasks();

      final updatedTask =
          _findTaskById(task.id);

      if (updatedTask == null) {
        throw Exception(
          'Task status could not be refreshed.',
        );
      }

      /*
       * Step 4:
       * The backend decides whether this task can
       * actually be claimed.
       */
      if (updatedTask.claimed) {
        await _loadProfile();

        if (mounted) {
          _showMessage(
            'This task has already been claimed.',
          );
        }

        return;
      }

      if (!updatedTask.canClaim) {
        if (mounted) {
          _showSocialVerificationMessage(
            updatedTask,
          );
        }

        return;
      }

      /*
       * Step 5:
       * Claim only when Supabase says can_claim = true.
       */
      final claimResult =
          await _socialTaskService.verifyAndClaim(
        taskId: task.id,
      );

      final success =
          claimResult['success'] == true;

      if (!success) {
        throw Exception(
          claimResult['message'] ??
              'Social reward could not be claimed.',
        );
      }

      await _loadTasks();
      await _loadProfile();

      final reward = _toDouble(
        claimResult['reward_fan'],
      );

      if (mounted) {
        _showMessage(
          '+${reward > 0 ? reward.toStringAsFixed(0) : task.rewardFan.toStringAsFixed(0)} FAN earned.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  DailySocialTask? _findTaskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }

    return null;
  }

  void _showSocialVerificationMessage(
    DailySocialTask task,
  ) {
    final missing = <String>[];

    if (task.requiresFollow &&
        !task.followVerified) {
      missing.add('Follow');
    }

    if (task.requiresComment &&
        !task.commentVerified) {
      missing.add('Comment');
    }

    if (task.requiresShare &&
        !task.shareVerified) {
      missing.add('Share');
    }

    /*
     * Your current Supabase claim function requires
     * all three verification flags. Therefore, if the
     * backend has not verified them yet, we simply tell
     * the user that verification is still pending.
     */
    final message = missing.isEmpty
        ? 'Verification is still pending. Please complete the task and try again.'
        : 'Complete: ${missing.join(', ')}. Verification is still pending.';

    _showMessage(message);
  }

  String _miningStatusText() {
    if (_isMining) {
      return 'MINING';
    }

    if (_endsAt != null &&
        _remaining == Duration.zero) {
      return 'READY TO CLAIM';
    }

    return 'READY';
  }

  String _formatDuration(
    Duration duration,
  ) {
    final hours = duration.inHours
        .toString()
        .padLeft(2, '0');

    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  double _progressValue() {
    const totalSeconds =
        24 * 60 * 60;

    final remainingSeconds =
        _remaining.inSeconds;

    final elapsed =
        totalSeconds - remainingSeconds;

    if (elapsed <= 0) return 0;
    if (elapsed >= totalSeconds) return 1;

    return elapsed / totalSeconds;
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildMiningCard(),
            const SizedBox(height: 14),
            _buildBoostCard(),
            const SizedBox(height: 20),
            _buildDailyTaskSection(),
            const SizedBox(height: 20),
            _buildKycCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: primaryPurple,
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: const Center(
            child: Text(
              'PF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'POWER FAN',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w800,
                  color: deepPurple,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Mine FAN. Earn More',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: deepPurple,
            size: 25,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primaryPurple,
            deepPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                primaryPurple.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -30,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            child: _buildMiningIllustration(),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              15,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'FAN BALANCE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 7),
                _loading
                    ? const SizedBox(
                        width: 100,
                        height: 31,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '${_fanBalance.toStringAsFixed(4)} FAN',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                const SizedBox(height: 12),
                const Text(
                  'AFAM Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_afamBalance.toStringAsFixed(4)} AFAM',
                  style:
                      const TextStyle(
                    color: Colors.white,
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

  Widget _buildMiningIllustration() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.engineering_rounded,
            color: Colors.white,
            size: 51,
          ),
          Positioned(
            bottom: 8,
            right: 11,
            child: Icon(
              Icons.bolt_rounded,
              color: Colors.amber,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    final canClaim =
        !_isMining &&
            _endsAt != null &&
            _remaining == Duration.zero;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color:
                      primaryPurple.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: primaryPurple,
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mining Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _miningStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isMining
                            ? Colors.orange
                            : canClaim
                                ? Colors.blue
                                : Colors.green,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_miningRate.toStringAsFixed(2)} FAN/H',
                style: const TextStyle(
                  color: primaryPurple,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Session Time',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              Text(
                '${_formatDuration(_remaining)} / 24:00:00',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child:
                LinearProgressIndicator(
              value: _progressValue(),
              minHeight: 7,
              backgroundColor:
                  const Color(0xFFEDEAF7),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _actionLoading
                  ? null
                  : _isMining
                      ? null
                      : canClaim
                          ? _claimMining
                          : _startMining,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryPurple,
                disabledBackgroundColor:
                    primaryPurple,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                elevation: 0,
              ),
              child: _actionLoading
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
                      canClaim
                          ? 'CLAIM MINING'
                          : _isMining
                              ? 'MINING...'
                              : 'START MINING',
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostCard() {
    final limitReached =
        _adsWatched >= 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
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
              color:
                  Colors.orange.withOpacity(0.10),
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
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Boost by Watching Ads',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '+0.1 FAN/H per ad',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
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
              color:
                  primaryPurple.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Text(
              '$_adsWatched / 7',
              style: TextStyle(
                color: limitReached
                    ? Colors.grey
                    : primaryPurple,
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Task',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        if (_tasks.isEmpty)
          Container(
            padding:
                const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: const Center(
              child: Text(
                'No daily tasks available.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ..._tasks.map(
            (task) => _socialTask(task),
          ),
      ],
    );
  }

  Widget _socialTask(
    DailySocialTask task,
  ) {
    final waitingForVerification =
        !task.claimed &&
            !task.canClaim;

    return InkWell(
      borderRadius:
          BorderRadius.circular(15),
      onTap: task.claimed
          ? null
          : () => _openSocialTask(task),
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 9),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color: Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    primaryPurple.withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Icon(
                _platformIcon(task.platform),
                color: primaryPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  if (task.description
                      .isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            _taskStatusWidget(
              task,
              waitingForVerification,
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskStatusWidget(
    DailySocialTask task,
    bool waitingForVerification,
  ) {
    if (task.claimed) {
      return const Text(
        'CLAIMED',
        style: TextStyle(
          color: Colors.green,
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
        ),
      );
    }

    if (task.canClaim) {
      return Text(
        'CLAIM ${task.rewardFan.toStringAsFixed(0)} FAN',
        style: const TextStyle(
          color: primaryPurple,
          fontSize: 10,
          fontWeight:
              FontWeight.w800,
        ),
      );
    }

    if (waitingForVerification) {
      return const Text(
        'OPEN',
        style: TextStyle(
          color: primaryPurple,
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
        ),
      );
    }

    return Text(
      '${task.rewardFan.toStringAsFixed(0)} FAN',
      style: const TextStyle(
        color: primaryPurple,
        fontSize: 11,
        fontWeight:
            FontWeight.w800,
      ),
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

  Widget _buildKycCard() {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
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
              color:
                  primaryPurple.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: primaryPurple,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC Verification',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

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

  DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    final parsed =
        DateTime.tryParse(
      value.toString(),
    );

    return parsed?.toLocal();
  }

  double _extractNumber(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data.containsKey(key)) {
        final value =
            _toDouble(data[key]);

        if (value != 0) {
          return value;
        }
      }
    }

    return 0;
  }

  String _errorMessage(
    Object error,
  ) {
    final message = error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(11);
    }

    return message;
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
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}
