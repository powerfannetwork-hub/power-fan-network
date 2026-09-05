import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
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

  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color background = Color(0xFFF8F8FC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _HomeInterface(),
          ReferralScreen(),
          WalletScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                context,
                Icons.home_rounded,
                'home',
                0,
              ),
              _navItem(
                context,
                Icons.people_alt_rounded,
                'referral',
                1,
              ),
              _navItem(
                context,
                Icons.account_balance_wallet_rounded,
                'wallet',
                2,
              ),
              _navItem(
                context,
                Icons.settings_rounded,
                'settings',
                3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String key,
    int index,
  ) {
    final selected = _currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected
                  ? primaryPurple
                  : const Color(0xFF60616C),
            ),
            const SizedBox(height: 3),
            Text(
              _tr(context, key),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: selected
                    ? primaryPurple
                    : const Color(0xFF60616C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tr(BuildContext context, String key) {
    return AppLocalizations.of(context).translate(key);
  }
}

class _HomeInterface extends StatefulWidget {
  const _HomeInterface();

  @override
  State<_HomeInterface> createState() => _HomeInterfaceState();
}

class _HomeInterfaceState extends State<_HomeInterface> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);

  final MiningService _miningService = MiningService.instance;
  final SocialTaskService _socialTaskService =
      SocialTaskService();

  Timer? _timer;

  bool _loading = true;
  bool _actionLoading = false;

  double _fanBalance = 0;
  double _afamBalance = 0;
  double _miningRate = 0.20;

  bool _isMining = false;
  bool _canClaim = false;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Duration _remaining = Duration.zero;
  Duration _elapsed = Duration.zero;

  double _estimatedEarned = 0;
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

  String _tr(BuildContext context, String key) {
    return AppLocalizations.of(context).translate(key);
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() => _loading = true);

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
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadProfile() async {
    final profile = await _miningService.getProfile();

    if (!mounted) return;

    setState(() {
      _fanBalance = _toDouble(profile['fan_balance']);
      _afamBalance = _toDouble(profile['afam_balance']);
    });
  }

  Future<void> _loadMining() async {
    final active = await _miningService.getActiveMining();
    final rate = await _miningService.getUserMiningRate();

    final startedAt = _parseDateTime(
      active['started_at'] ?? active['start_time'],
    );

    final endsAt = _parseDateTime(
      active['ends_at'] ??
          active['end_time'] ??
          active['expires_at'],
    );

    final isMining =
        active['active'] == true ||
        active['is_mining'] == true ||
        active['is_active'] == true;

    final canClaim =
        active['claimable'] == true ||
        active['expired'] == true;

    final ads = _toInt(
      active['ads_watched'] ??
          active['ad_count'] ??
          active['ads_count'] ??
          0,
    );

    final activeRate = _toDouble(
      active['rate'] ??
          active['mining_rate'] ??
          rate,
    );

    if (!mounted) return;

    _timer?.cancel();

    setState(() {
      _isMining = isMining;
      _canClaim = canClaim;

      _startedAt = startedAt;
      _endsAt = endsAt;

      _miningRate = activeRate > 0
          ? activeRate
          : rate > 0
              ? rate
              : 0.20;

      _adsWatched = ads.clamp(0, 7);

      _remaining = _calculateRemaining();
      _elapsed = _calculateElapsed();
      _estimatedEarned = _calculateEstimatedEarned();
    });

    if (_isMining && _endsAt != null) {
      _startCountdown();
    }
  }

  Future<void> _loadTasks() async {
    final tasks =
        await _socialTaskService.getDailyTasksForCard();

    if (!mounted) return;

    setState(() => _tasks = tasks);
  }

  Duration _calculateRemaining() {
    if (!_isMining || _endsAt == null) {
      return Duration.zero;
    }

    final value = _endsAt!.difference(DateTime.now());

    return value.isNegative ? Duration.zero : value;
  }

  Duration _calculateElapsed() {
    if (_startedAt == null) {
      return Duration.zero;
    }

    final value =
        DateTime.now().difference(_startedAt!);

    if (value.isNegative) {
      return Duration.zero;
    }

    const total = Duration(hours: 24);

    return value > total ? total : value;
  }

  double _calculateEstimatedEarned() {
    if (!_isMining || _miningRate <= 0) {
      return 0;
    }

    return _miningRate *
        (_elapsed.inSeconds / 3600.0);
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final remaining = _calculateRemaining();
        final elapsed = _calculateElapsed();

        if (remaining <= Duration.zero) {
          _timer?.cancel();

          setState(() {
            _remaining = Duration.zero;
            _elapsed = const Duration(hours: 24);
            _estimatedEarned = _miningRate * 24;
            _isMining = false;
            _canClaim = true;
          });

          return;
        }

        setState(() {
          _remaining = remaining;
          _elapsed = elapsed;
          _estimatedEarned =
              _calculateEstimatedEarned();
        });
      },
    );
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<void> _startMining() async {
    if (_actionLoading) return;

    setState(() => _actionLoading = true);

    try {
      final result =
          await _miningService.startMining();

      if (result['success'] == false) {
        throw Exception(
          result['message'] ??
              'Unable to start mining.',
        );
      }

      await _loadMining();

      if (mounted) {
        _showMessage(
          _tr(
            context,
            'mining_started_successfully',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<void> _claimMining() async {
    if (_actionLoading || !_canClaim) return;

    setState(() => _actionLoading = true);

    try {
      final result =
          await _miningService.claimMining();

      if (result['success'] != true) {
        throw Exception(
          result['message'] ??
              'Unable to claim mining reward.',
        );
      }

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

      _timer?.cancel();

      if (!mounted) return;

      setState(() {
        _isMining = false;
        _canClaim = false;
        _startedAt = null;
        _endsAt = null;
        _remaining = Duration.zero;
        _elapsed = Duration.zero;
        _estimatedEarned = 0;
        _adsWatched = 0;
      });

      _showMessage(
        earned > 0
            ? '${earned.toStringAsFixed(4)} FAN '
                '${_tr(context, 'claimed_successfully')}'
            : _tr(
                context,
                'mining_reward_claimed',
              ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  // ============================================================
  // REWARDED AD TEST DIALOG
  // ============================================================

  Future<bool> _showRewardedAdForBoost() async {
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            int seconds = 3;

            return StatefulBuilder(
              builder: (
                context,
                setDialogState,
              ) {
                if (seconds > 0) {
                  Future.delayed(
                    const Duration(seconds: 1),
                    () {
                      if (!context.mounted) return;

                      setDialogState(() {
                        seconds--;
                      });
                    },
                  );
                }

                return AlertDialog(
                  title: const Text('Rewarded Ad'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        size: 50,
                        color: primaryPurple,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Watch the rewarded ad to receive +0.10 FAN/H.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        seconds > 0
                            ? 'Ad playing... $seconds'
                            : 'Reward received',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    if (seconds == 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(
                              dialogContext,
                            ).pop(true);
                          },
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                primaryPurple,
                            foregroundColor:
                                Colors.white,
                          ),
                          child:
                              const Text('CLAIM BOOST'),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _watchBoostAd() async {
    if (_actionLoading ||
        !_isMining ||
        _adsWatched >= 7) {
      return;
    }

    setState(() => _actionLoading = true);

    try {
      final completed =
          await _showRewardedAdForBoost();

      if (!completed) return;

      final result =
          await _miningService
              .recordAndVerifyRewardedAd(
        adReference: 'test_rewarded_ad',
      );

      final success =
          result['verified'] == true ||
          result['success'] == true ||
          result['boost_amount'] != null;

      if (!success) {
        throw Exception(
          result['message'] ??
              'Rewarded ad verification failed.',
        );
      }

      await _loadMining();

      if (mounted) {
        _showMessage('+0.10 FAN/H');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  // ============================================================
  // SOCIAL TASKS
  // ============================================================

  Future<void> _openSocialTask(
    DailySocialTask task,
  ) async {
    if (_actionLoading || task.claimed) {
      return;
    }

    setState(() => _actionLoading = true);

    try {
      final startResult =
          await _socialTaskService.startTask(
        taskId: task.id,
      );

      if (startResult['success'] == false) {
        throw Exception(
          startResult['message'] ??
              _tr(
                context,
                'unable_start_task',
              ),
        );
      }

      final opened =
          await _socialTaskService.openTaskUrl(
        task.url,
      );

      if (!opened) {
        throw Exception(
          _tr(
            context,
            'unable_open_task',
          ),
        );
      }

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      await _loadTasks();

      final updated = _tasks.cast<DailySocialTask?>().firstWhere(
            (item) => item?.id == task.id,
            orElse: () => null,
          );

      if (updated == null) return;

      if (updated.claimed) {
        await _loadProfile();

        if (mounted) {
          _showMessage(
            _tr(
              context,
              'task_already_claimed',
            ),
          );
        }

        return;
      }

      if (!updated.canClaim) {
        if (mounted) {
          _showSocialVerificationMessage(updated);
        }

        return;
      }

      final claim =
          await _socialTaskService.verifyAndClaim(
        taskId: task.id,
      );

      if (claim['success'] != true) {
        throw Exception(
          claim['message'] ??
              _tr(
                context,
                'social_reward_failed',
              ),
        );
      }

      await _loadTasks();
      await _loadProfile();

      final reward =
          _toDouble(claim['reward_fan']);

      if (mounted) {
        final amount = reward > 0
            ? reward.toStringAsFixed(0)
            : task.rewardFan.toStringAsFixed(0);

        _showMessage(
          '+$amount FAN '
          '${_tr(context, 'earned')}',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  void _showSocialVerificationMessage(
    DailySocialTask task,
  ) {
    final missing = <String>[];

    if (task.requiresFollow &&
        !task.followVerified) {
      missing.add(_tr(context, 'follow'));
    }

    if (task.requiresComment &&
        !task.commentVerified) {
      missing.add(_tr(context, 'comment'));
    }

    if (task.requiresShare &&
        !task.shareVerified) {
      missing.add(_tr(context, 'share'));
    }

    final message = missing.isEmpty
        ? _tr(
            context,
            'verification_pending',
          )
        : '${_tr(context, 'complete')}: '
            '${missing.join(', ')}. '
            '${_tr(context, 'verification_pending')}';

    _showMessage(message);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            28,
          ),
          children: [
            _buildHeader(context),
            const SizedBox(height: 17),
            _buildBalanceCard(context),
            const SizedBox(height: 15),
            _buildMiningCard(context),
            const SizedBox(height: 14),
            _buildBoostCard(context),
            const SizedBox(height: 16),
            _buildDailyTasks(context),
            const SizedBox(height: 16),
            _buildKycCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            borderRadius: BorderRadius.circular(13),
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
                _tr(
                  context,
                  'mine_fan_earn_more',
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
            borderRadius: BorderRadius.circular(13),
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

  Widget _buildBalanceCard(BuildContext context) {
    final displayedBalance =
        _fanBalance + _estimatedEarned;

    return Container(
      height: 184,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4520B6),
            Color(0xFF28106D),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.20),
            blurRadius: 17,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -40,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 10,
            child: _buildMiningIllustration(),
          ),
          Padding(
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
                  _tr(context, 'balance'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _loading
                    ? const SizedBox(
                        width: 100,
                        height: 30,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '${displayedBalance.toStringAsFixed(4)} FAN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                if (_isMining &&
                    _estimatedEarned > 0)
                  Text(
                    '+${_estimatedEarned.toStringAsFixed(6)} FAN mining',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
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
                  'AFAM ${_afamBalance.toStringAsFixed(4)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
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
    return SizedBox(
      width: 135,
      height: 115,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 18,
            child: Icon(
              Icons.construction_rounded,
              color: Colors.white,
              size: 70,
            ),
          ),
          const Positioned(
            right: 5,
            bottom: 10,
            child: Icon(
              Icons.diamond_rounded,
              color: Color(0xFF9B7BFF),
              size: 32,
            ),
          ),
          const Positioned(
            right: 34,
            top: 8,
            child: Icon(
              Icons.stars_rounded,
              color: Color(0xFFFFD54F),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard(BuildContext context) {
    final showClaim = _canClaim && !_isMining;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      primaryPurple.withOpacity(0.09),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hardware_rounded,
                  color: primaryPurple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_tr(context, 'status')}: '
                      '${_statusText(context)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _isMining
                            ? Colors.orange
                            : showClaim
                                ? Colors.blue
                                : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMining
                          ? _tr(
                              context,
                              'mining_fan_active',
                            )
                          : showClaim
                              ? _tr(
                                  context,
                                  'mining_session_ended',
                                )
                              : _tr(
                                  context,
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
                child: _infoColumn(
                  context,
                  Icons.speed_rounded,
                  'mining_rate',
                  '${_miningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              Container(
                width: 1,
                height: 47,
                color: const Color(0xFFE4E1EC),
              ),
              Expanded(
                child: _infoColumn(
                  context,
                  Icons.access_time_rounded,
                  'session_time',
                  _isMining
                      ? '${_formatDuration(_remaining)} / 24:00:00'
                      : showClaim
                          ? '24:00:00 / 24:00:00'
                          : '00:00:00 / 24:00:00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progressValue(),
              minHeight: 6,
              backgroundColor:
                  const Color(0xFFEDEAF7),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: ElevatedButton(
              onPressed: _actionLoading
                  ? null
                  : _isMining
                      ? null
                      : showClaim
                          ? _claimMining
                          : _startMining,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                disabledBackgroundColor:
                    primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
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
                  : Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.hardware_rounded,
                          size: 22,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          showClaim
                              ? _tr(
                                  context,
                                  'claim_mining',
                                )
                              : _isMining
                                  ? _tr(
                                      context,
                                      'mining_loading',
                                    )
                                  : _tr(
                                      context,
                                      'start_mining',
                                    ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(
    BuildContext context,
    IconData icon,
    String key,
    String value,
  ) {
    return Row(
      children: [
        const SizedBox(width: 5),
        Icon(
          icon,
          color: primaryPurple,
          size: 29,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                _tr(context, key),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
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

  String _statusText(BuildContext context) {
    if (_isMining) {
      return _tr(context, 'mining');
    }

    if (_canClaim) {
      return _tr(context, 'ready_to_claim');
    }

    return _tr(context, 'ready');
  }

  double _progressValue() {
    if (_canClaim) return 1;

    const total = 24 * 60 * 60;

    if (_elapsed.inSeconds <= 0) return 0;

    return (_elapsed.inSeconds / total)
        .clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
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

  Widget _buildBoostCard(BuildContext context) {
    final limitReached = _adsWatched >= 7;
    final boost =
        (_adsWatched * 0.1).clamp(0.0, 0.7);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.deepOrange,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        context,
                        'boost_by_watching_ads',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tr(
                        context,
                        'each_ad_adds',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$_adsWatched / 7',
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
                  value: _adsWatched / 7,
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
              const SizedBox(width: 12),
              Text(
                '+${boost.toStringAsFixed(1)} FAN/H',
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
                  limitReached ||
                          !_isMining ||
                          _actionLoading
                      ? null
                      : _watchBoostAd,
              icon: const Icon(
                Icons.ondemand_video_rounded,
              ),
              label: Text(
                limitReached
                    ? _tr(
                        context,
                        'daily_limit_reached',
                      )
                    : !_isMining
                        ? _tr(
                            context,
                            'start_mining_watch_ads',
                          )
                        : _tr(
                            context,
                            'watch_ad',
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTasks(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _tr(context, 'daily_task'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _tr(
            context,
            'complete_social_tasks',
          ),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 11),
        if (_tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: Center(
              child: Text(
                _tr(
                  context,
                  'no_daily_tasks',
                ),
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ..._tasks.map(
            (task) => _socialTask(context, task),
          ),
      ],
    );
  }

  Widget _socialTask(
    BuildContext context,
    DailySocialTask task,
  ) {
    return InkWell(
      onTap: task.claimed
          ? null
          : () => _openSocialTask(task),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    primaryPurple.withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                _platformIcon(task.platform),
                color: primaryPurple,
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
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              task.claimed
                  ? _tr(context, 'claimed')
                  : '+${task.rewardFan.toStringAsFixed(0)} FAN',
              style: TextStyle(
                color: task.claimed
                    ? Colors.green
                    : primaryPurple,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildKycCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_rounded,
            color: primaryPurple,
            size: 45,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _tr(
                    context,
                    'kyc_verification',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tr(
                    context,
                    'verify_identity',
                  ),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _tr(context, 'coming_soon'),
            style: const TextStyle(
              color: primaryPurple,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  double _extractNumber(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;

      final value = _toDouble(data[key]);

      if (value != 0) {
        return value;
      }
    }

    return 0;
  }

  String _errorMessage(Object error) {
    var message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    return message;
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
}
