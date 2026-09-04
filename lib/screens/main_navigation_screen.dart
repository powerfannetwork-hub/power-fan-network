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
  static const Color deepPurple = Color(0xFF241064);
  static const Color background = Color(0xFFF8F8FC);

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const _HomeInterface(),
      const ReferralScreen(),
      const WalletScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(
        context,
      ),
    );
  }

  Widget _buildBottomNavigationBar(
    BuildContext context,
  ) {
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
          padding: const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            7,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                context: context,
                icon: Icons.home_rounded,
                label: _tr(context, 'home'),
                index: 0,
              ),
              _navItem(
                context: context,
                icon: Icons.people_alt_rounded,
                label: _tr(context, 'referral'),
                index: 1,
              ),
              _navItem(
                context: context,
                icon:
                    Icons.account_balance_wallet_rounded,
                label: _tr(context, 'wallet'),
                index: 2,
              ),
              _navItem(
                context: context,
                icon: Icons.settings_rounded,
                label: _tr(context, 'settings'),
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
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
              label,
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
}

class _HomeInterface extends StatefulWidget {
  const _HomeInterface();

  @override
  State<_HomeInterface> createState() =>
      _HomeInterfaceState();
}

class _HomeInterfaceState
    extends State<_HomeInterface> {
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

  double _fanBalance = 0.0;
  double _afamBalance = 0.0;
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

  String _tr(
    BuildContext context,
    String key,
  ) {
    return AppLocalizations.of(context)
        .translate(key);
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
        _showMessage(
          _errorMessage(e),
        );
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
          _toInt(ads).clamp(0, 7).toInt();

      _remaining =
          _calculateRemaining();

      if (_isMining &&
          _endsAt != null) {
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
    if (!_isMining ||
        _endsAt == null) {
      return Duration.zero;
    }

    final difference =
        _endsAt!.difference(
      DateTime.now(),
    );

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

        if (remaining <=
            Duration.zero) {
          _timer?.cancel();

          setState(() {
            _remaining =
                Duration.zero;

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
          _tr(
            context,
            'mining_started_successfully',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          _errorMessage(e),
        );
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

      final earned =
          _extractNumber(
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
            '${earned.toStringAsFixed(4)} FAN '
            '${_tr(context, 'claimed_successfully')}',
          );
        } else {
          _showMessage(
            _tr(
              context,
              'mining_reward_claimed',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          _errorMessage(e),
        );
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
    if (task.claimed ||
        _actionLoading) {
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      final startResult =
          await _socialTaskService.startTask(
        taskId: task.id,
      );

      if (startResult['success'] ==
          false) {
        throw Exception(
          startResult['message'] ??
              _tr(
                context,
                'unable_start_task',
              ),
        );
      }

      final opened =
          await _socialTaskService
              .openTaskUrl(task.url);

      if (!opened) {
        throw Exception(
          _tr(
            context,
            'unable_open_task',
          ),
        );
      }

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      await _loadTasks();

      final updatedTask =
          _findTaskById(task.id);

      if (updatedTask == null) {
        return;
      }

      if (updatedTask.claimed) {
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

      if (!updatedTask.canClaim) {
        if (mounted) {
          _showSocialVerificationMessage(
            updatedTask,
          );
        }

        return;
      }

      final claimResult =
          await _socialTaskService
              .verifyAndClaim(
        taskId: task.id,
      );

      if (claimResult['success'] !=
          true) {
        throw Exception(
          claimResult['message'] ??
              _tr(
                context,
                'social_reward_failed',
              ),
        );
      }

      await _loadTasks();
      await _loadProfile();

      final reward =
          _toDouble(
        claimResult['reward_fan'],
      );

      if (mounted) {
        final amount =
            reward > 0
                ? reward.toStringAsFixed(0)
                : task.rewardFan
                    .toStringAsFixed(0);

        _showMessage(
          '+$amount FAN '
          '${_tr(context, 'earned')}',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          _errorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  DailySocialTask? _findTaskById(
    String id,
  ) {
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
      missing.add(
        _tr(context, 'follow'),
      );
    }

    if (task.requiresComment &&
        !task.commentVerified) {
      missing.add(
        _tr(context, 'comment'),
      );
    }

    if (task.requiresShare &&
        !task.shareVerified) {
      missing.add(
        _tr(context, 'share'),
      );
    }

    final message =
        missing.isEmpty
            ? _tr(
                context,
                'verification_pending',
              )
            : '${_tr(context, 'complete')}: '
              '${missing.join(', ')}. '
              '${_tr(context, 'verification_pending')}';

    _showMessage(message);
  }

  String _miningStatusText() {
    if (_isMining) {
      return _tr(context, 'mining');
    }

    if (_endsAt != null &&
        _remaining ==
            Duration.zero) {
      return _tr(
        context,
        'ready_to_claim',
      );
    }

    return _tr(context, 'ready');
  }

  String _formatDuration(
    Duration duration,
  ) {
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

  double _progressValue() {
    const totalSeconds =
        24 * 60 * 60;

    final remainingSeconds =
        _remaining.inSeconds;

    final elapsed =
        totalSeconds -
            remainingSeconds;

    if (elapsed <= 0) {
      return 0;
    }

    if (elapsed >= totalSeconds) {
      return 1;
    }

    return elapsed / totalSeconds;
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _refresh,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
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
            _buildDailyTaskSection(context),
            const SizedBox(height: 16),
            _buildKycCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
  ) {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(
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
                fontWeight:
                    FontWeight.w900,
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
                  fontWeight:
                      FontWeight.w900,
                  color: deepPurple,
                ),
              ),
              const SizedBox(height: 1),
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
              child: const Icon(
                Icons
                    .notifications_none_rounded,
                color: deepPurple,
                size: 28,
              ),
            ),
            Positioned(
              top: 2,
              right: 3,
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
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
  ) {
    return Container(
      height: 184,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF4520B6),
            Color(0xFF28106D),
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color:
                primaryPurple.withOpacity(
              0.20,
            ),
            blurRadius: 17,
            offset:
                const Offset(0, 7),
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
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(
                  0.06,
                ),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 10,
            child:
                _buildMiningIllustration(),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
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
                  _tr(
                    context,
                    'balance',
                  ),
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        0.7,
                  ),
                ),
                const SizedBox(height: 8),
                _loading
                    ? const SizedBox(
                        width: 100,
                        height: 30,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              Colors.white,
                        ),
                      )
                    : Text(
                        '${_fanBalance.toStringAsFixed(4)} FAN',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 29,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                const SizedBox(height: 8),
                Text(
                  '≈ \$0.00',
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(
                      0.95,
                    ),
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'AFAM ${_afamBalance.toStringAsFixed(4)}',
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
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
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(
                  0.08,
                ),
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
              color:
                  Color(0xFF9B7BFF),
              size: 32,
            ),
          ),
          const Positioned(
            right: 34,
            top: 8,
            child: Icon(
              Icons.stars_rounded,
              color:
                  Color(0xFFFFD54F),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard(
    BuildContext context,
  ) {
    final canClaim =
        !_isMining &&
        _endsAt != null &&
        _remaining ==
            Duration.zero;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        17,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(
                  color:
                      primaryPurple
                          .withOpacity(
                    0.09,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .hardware_rounded,
                  color:
                      primaryPurple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      '${_tr(context, 'status')}: '
                      '${_miningStatusText()}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .w800,
                        color: _isMining
                            ? Colors.orange
                            : canClaim
                                ? Colors.blue
                                : Colors.green,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      _isMining
                          ? _tr(
                              context,
                              'mining_fan_active',
                            )
                          : canClaim
                              ? _tr(
                                  context,
                                  'mining_session_ended',
                                )
                              : _tr(
                                  context,
                                  'start_mining_earn_fan',
                                ),
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Color(
                          0xFF646477,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(
            height: 1,
            color:
                Color(0xFFEAE8F1),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color:
                    primaryPurple,
                size: 29,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      _tr(
                        context,
                        'mining_rate',
                      ),
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${_miningRate.toStringAsFixed(2)} FAN/H',
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 47,
                color:
                    const Color(
                  0xFFE4E1EC,
                ),
              ),
              const SizedBox(width: 18),
              const Icon(
                Icons
                    .access_time_rounded,
                color:
                    primaryPurple,
                size: 29,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      _tr(
                        context,
                        'session_time',
                      ),
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      '${_formatDuration(_remaining)} / 24:00:00',
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child:
                LinearProgressIndicator(
              value:
                  _progressValue(),
              minHeight: 6,
              backgroundColor:
                  const Color(
                0xFFEDEAF7,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width:
                double.infinity,
            height: 49,
            child:
                ElevatedButton(
              onPressed:
                  _actionLoading
                      ? null
                      : _isMining
                          ? null
                          : canClaim
                              ? _claimMining
                              : _startMining,
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    primaryPurple,
                disabledBackgroundColor:
                    primaryPurple,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child:
                  _actionLoading
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            const Icon(
                              Icons
                                  .hardware_rounded,
                              color:
                                  Colors.white,
                              size: 22,
                            ),
                            const SizedBox(
                              width: 9,
                            ),
                            Text(
                              canClaim
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
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    14,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                letterSpacing:
                                    0.4,
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

  Widget _buildBoostCard(
    BuildContext context,
  ) {
    final limitReached =
        _adsWatched >= 7;

    final boost =
        (_adsWatched * 0.1)
            .clamp(0.0, 0.7);

    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.025,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.orange
                          .withOpacity(
                    0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .rocket_launch_rounded,
                  color:
                      Colors.deepOrange,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      _tr(
                        context,
                        'boost_by_watching_ads',
                      ),
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      _tr(
                        context,
                        'each_ad_adds',
                      ),
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      primaryPurple
                          .withOpacity(
                    0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Text(
                  '$_adsWatched / 7',
                  style: TextStyle(
                    color:
                        limitReached
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  child:
                      LinearProgressIndicator(
                    value:
                        _adsWatched / 7,
                    minHeight: 7,
                    backgroundColor:
                        const Color(
                      0xFFEDEAF7,
                    ),
                    valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                      primaryPurple,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '+${boost.toStringAsFixed(1)} FAN/H',
                style:
                    const TextStyle(
                  color:
                      primaryPurple,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width:
                double.infinity,
            height: 43,
            child:
                OutlinedButton.icon(
              onPressed:
                  limitReached ||
                          !_isMining
                      ? null
                      : () {
                          _showMessage(
                            _tr(
                              context,
                              'rewarded_ad_next',
                            ),
                          );
                        },
              icon: const Icon(
                Icons
                    .ondemand_video_rounded,
                size: 20,
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
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    primaryPurple,
                disabledForegroundColor:
                    Colors.grey,
                side: BorderSide(
                  color:
                      limitReached ||
                              !_isMining
                          ? Colors
                              .grey
                              .shade300
                          : primaryPurple,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskSection(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _tr(
            context,
            'daily_task',
          ),
          style:
              const TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _tr(
            context,
            'complete_social_tasks',
          ),
          style:
              const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 11),
        if (_tasks.isEmpty)
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              19,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: Center(
              child: Text(
                _tr(
                  context,
                  'no_daily_tasks',
                ),
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ..._tasks.map(
            (task) =>
                _socialTask(
              context,
              task,
            ),
          ),
      ],
    );
  }

  Widget _socialTask(
    BuildContext context,
    DailySocialTask task,
  ) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      onTap: task.claimed
          ? null
          : () =>
              _openSocialTask(
                task,
              ),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 9,
        ),
        padding:
            const EdgeInsets.all(
          12,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border: Border.all(
            color:
                Colors.grey.shade100,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    primaryPurple
                        .withOpacity(
                  0.08,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                _platformIcon(
                  task.platform,
                ),
                color:
                    primaryPurple,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  if (task
                      .description
                      .isNotEmpty)
                    Text(
                      task.description,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            _taskStatusWidget(
              context,
              task,
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskStatusWidget(
    BuildContext context,
    DailySocialTask task,
  ) {
    if (task.claimed) {
      return Text(
        _tr(
          context,
          'claimed',
        ),
        style:
            const TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight:
              FontWeight.w900,
        ),
      );
    }

    if (task.canClaim) {
      return Text(
        '${_tr(context, 'claim')} '
        '${task.rewardFan.toStringAsFixed(0)} FAN',
        style:
            const TextStyle(
          color:
              primaryPurple,
          fontSize: 9,
          fontWeight:
              FontWeight.w900,
        ),
      );
    }

    return Text(
      '+${task.rewardFan.toStringAsFixed(0)} FAN',
      style:
          const TextStyle(
        color:
            primaryPurple,
        fontSize: 10,
        fontWeight:
            FontWeight.w800,
      ),
    );
  }

  IconData _platformIcon(
    String platform,
  ) {
    switch (
        platform.toLowerCase()) {
      case 'facebook':
        return Icons
            .facebook_rounded;

      case 'telegram':
        return Icons
            .send_rounded;

      case 'instagram':
        return Icons
            .camera_alt_rounded;

      case 'youtube':
        return Icons
            .play_arrow_rounded;

      case 'tiktok':
        return Icons
            .music_note_rounded;

      case 'x':
      case 'twitter':
        return Icons.close_rounded;

      default:
        return Icons
            .public_rounded;
    }
  }

  Widget _buildKycCard(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color:
                  primaryPurple
                      .withOpacity(
                0.08,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_rounded,
              color:
                  primaryPurple,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  _tr(
                    context,
                    'kyc_verification',
                  ),
                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  _tr(
                    context,
                    'verify_identity',
                  ),
                  maxLines: 2,
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration:
                BoxDecoration(
              border: Border.all(
                color:
                    primaryPurple,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Text(
              _tr(
                context,
                'coming_soon',
              ),
              style:
                  const TextStyle(
                color:
                    primaryPurple,
                fontSize: 9,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
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

  DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

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
      if (data.containsKey(key)) {
        final value =
            _toDouble(data[key]);

        if (value != 0) {
          return value;
        }
      }
    }

    return 0.0;
  }

  String _errorMessage(
    Object error,
  ) {
    var message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      message =
          message.substring(11);
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
          content:
              Text(message),
          behavior:
              SnackBarBehavior
                  .floating,
        ),
      );
  }
}
