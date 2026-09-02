import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mining_service.dart';
import '../services/auth_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final MiningService _miningService = MiningService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  int _currentIndex = 0;

  double _balance = 0.0;
  double _afamBalance = 0.0;
  double _miningRate = 0.2;

  int _adsWatched = 0;
  bool _loading = true;
  bool _actionLoading = false;

  MiningSession? _session;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    _loadMiningData();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {});

        if (_session != null && !_session!.isActive) {
          _refreshMiningData();
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMiningData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final rate = await _miningService.getMiningRate();
      final session = await _miningService.getSession();

      double fanBalance = _balance;
      double afamBalance = _afamBalance;

      try {
        final user = _supabase.auth.currentUser;

        if (user != null) {
          final profile = await _supabase
              .from('profiles')
              .select('fan_balance, afam_balance')
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null) {
            fanBalance = _toDouble(profile['fan_balance']);
            afamBalance = _toDouble(profile['afam_balance']);
          }
        }
      } catch (_) {
        // Keep the currently displayed balance if profile columns
        // are unavailable.
      }

      if (!mounted) return;

      setState(() {
        _miningRate = rate;
        _session = session;
        _balance = fanBalance;
        _afamBalance = afamBalance;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Unable to load mining information.',
      );
    }
  }

  Future<void> _refreshMiningData() async {
    try {
      final rate = await _miningService.getMiningRate();
      final session = await _miningService.getSession();

      if (!mounted) return;

      setState(() {
        _miningRate = rate;
        _session = session;
      });

      await _loadBalance();
    } catch (_) {}
  }

  Future<void> _loadBalance() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('fan_balance, afam_balance')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || !mounted) return;

      setState(() {
        _balance = _toDouble(profile['fan_balance']);
        _afamBalance = _toDouble(profile['afam_balance']);
      });
    } catch (_) {}
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> _startMining() async {
    if (_actionLoading) return;

    setState(() {
      _actionLoading = true;
    });

    try {
      final result = await _miningService.startMining();

      if (!mounted) return;

      if (result['success'] == true) {
        _showMessage(
          'Mining started successfully.',
        );
      } else if (result['already_active'] == true) {
        _showMessage(
          'Your mining session is already active.',
        );
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Unable to start mining.',
        );
      }

      await _loadMiningData();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(e),
      );
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
      final result = await _miningService.claimMining();

      if (!mounted) return;

      if (result['success'] == true) {
        final reward = _toDouble(result['earned_fan']);

        _showMessage(
          reward > 0
              ? 'Mining completed! You earned ${reward.toStringAsFixed(4)} FAN.'
              : 'Mining reward claimed successfully.',
        );
      } else {
        _showMessage(
          result['message']?.toString() ??
              'Unable to claim mining reward.',
        );
      }

      await _loadMiningData();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  Future<void> _watchAd() async {
    if (_actionLoading) return;

    if (_adsWatched >= 7) {
      _showMessage(
        'You have reached today\'s 7 ads limit.',
      );
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      /*
       * The database function records the rewarded-ad event.
       *
       * The actual advertising provider should later verify the
       * reward server-side before the mining boost is permanently
       * awarded.
       */
      final result = await _supabase.rpc(
        'record_rewarded_ad',
        params: {
          'p_ad_ref': null,
        },
      );

      if (!mounted) return;

      if (result is Map) {
        final data = Map<String, dynamic>.from(result);

        if (data['success'] == false) {
          _showMessage(
            data['message']?.toString() ??
                'Unable to record rewarded ad.',
          );
          return;
        }
      }

      setState(() {
        _adsWatched++;
      });

      await _refreshMiningData();

      _showMessage(
        'Rewarded ad recorded. Mining rate will update after verification.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionLoading = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('Authentication required')) {
      return 'Please login again.';
    }

    if (text.contains('already active')) {
      return 'Your mining session is already active.';
    }

    if (text.contains('No active mining session')) {
      return 'There is no active mining session.';
    }

    if (text.contains('PostgrestException')) {
      return 'Something went wrong. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _sessionStatus() {
    if (_session == null) {
      return 'READY';
    }

    if (_session!.isActive) {
      return 'MINING';
    }

    return 'COMPLETED';
  }

  String _sessionDescription() {
    if (_session == null) {
      return 'Start mining to earn FAN';
    }

    if (_session!.isActive) {
      return 'Mining FAN right now';
    }

    return 'Your 24-hour mining session has ended';
  }

  String _sessionTimeText() {
    if (_session == null) {
      return '00:00:00 / 24:00:00';
    }

    final elapsed = _session!.elapsed;

    final capped = elapsed.inSeconds > const Duration(hours: 24).inSeconds
        ? const Duration(hours: 24)
        : elapsed;

    return '${_formatDuration(capped)} / 24:00:00';
  }

  double get _adBoost {
    final value = _miningRate - 0.2;

    if (value <= 0) {
      return 0.0;
    }

    return value > 0.7 ? 0.7 : value;
  }

  int get _estimatedAdsFromRate {
    if (_adBoost <= 0) return 0;

    final count = (_adBoost / 0.1).round();

    if (count < 0) return 0;
    if (count > 7) return 7;

    return count;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _logout() async {
    try {
      await AuthService.instance.logout();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      _buildReferralPage(),
      _buildWalletPage(),
      _buildSettingsPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: pages[_currentIndex],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: const Color(0xFF4A20B9),
      onRefresh: _loadMiningData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              24,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  _buildMiningCard(),
                  const SizedBox(height: 14),
                  _buildAdsCard(),
                  const SizedBox(height: 14),
                  _buildDailyTaskCard(),
                  const SizedBox(height: 14),
                  _buildKycCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5B2BD9),
                  Color(0xFF32148E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B159B)
                      .withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POWER FAN',
                  style: TextStyle(
                    color: Color(0xFF35148F),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                Text(
                  'Mine FAN. Earn More',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  _showMessage(
                    'No new notifications.',
                  );
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 31,
                  color: Color(0xFF28116F),
                ),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
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

  Widget _buildBalanceCard() {
    return Container(
      height: 178,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4820B7),
            Color(0xFF291075),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF35128D)
                .withOpacity(0.28),
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
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 13,
            child: _buildMiningCharacter(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              21,
              15,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 53,
                      height: 53,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFB800),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(0.16),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFE88700),
                        size: 35,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Flexible(
                      child: _loading
                          ? const SizedBox(
                              width: 100,
                              height: 38,
                              child: Center(
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _balance.toStringAsFixed(4),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 37,
                                fontWeight:
                                    FontWeight.w900,
                                letterSpacing: -1.2,
                              ),
                            ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'FAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'AFAM ${_afamBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color:
                        Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCharacter() {
    return SizedBox(
      width: 155,
      height: 140,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 2,
            right: 0,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF743BDF)
                    .withOpacity(0.75),
                border: Border.all(
                  color:
                      Colors.white.withOpacity(0.16),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFFC400),
                  size: 48,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            left: 17,
            child: Transform.rotate(
              angle: -0.65,
              child: Container(
                width: 84,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B4B2A),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 29,
            left: 7,
            child: Transform.rotate(
              angle: -0.65,
              child: const Icon(
                Icons.construction_rounded,
                color: Color(0xFFE7D4FF),
                size: 45,
              ),
            ),
          ),
          Positioned(
            top: 1,
            left: 42,
            child: Container(
              width: 73,
              height: 73,
              decoration: BoxDecoration(
                color: const Color(0xFFF4A261),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      Colors.white.withOpacity(0.45),
                  width: 2,
                ),
              ),
              child: const Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      _Eye(),
                      SizedBox(width: 11),
                      _Eye(),
                    ],
                  ),
                  SizedBox(height: 8),
                  Icon(
                    Icons
                        .sentiment_satisfied_alt_rounded,
                    color: Color(0xFF32148E),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 55,
            left: 30,
            child: Container(
              width: 98,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFF5323B7),
                borderRadius:
                    const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                  bottomLeft:
                      Radius.circular(15),
                  bottomRight:
                      Radius.circular(15),
                ),
                border: Border.all(
                  color:
                      Colors.white.withOpacity(0.12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    final status = _sessionStatus();
    final active = _session?.isActive == true;
    final completed =
        _session != null && !active;

    return _whiteCard(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                active
                    ? Icons.bolt_rounded
                    : completed
                        ? Icons.task_alt_rounded
                        : Icons.handyman_rounded,
                active
                    ? const Color(0xFFE8F8F0)
                    : const Color(0xFFEAE5FF),
                active
                    ? const Color(0xFF159B61)
                    : const Color(0xFF4520AA),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'STATUS: ',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Color(0xFF159B61),
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sessionDescription(),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Divider(
            color: Colors.grey.shade200,
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miningInfo(
                  Icons.speed_rounded,
                  'MINING RATE',
                  '${_miningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),
              Container(
                width: 1,
                height: 58,
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: _miningInfo(
                  Icons.access_time_rounded,
                  active
                      ? 'SESSION TIME'
                      : completed
                          ? 'SESSION ENDED'
                          : 'SESSION TIME',
                  _sessionTimeText(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: _actionButton(
              active
                  ? 'MINING IN PROGRESS'
                  : completed
                      ? 'CLAIM MINING'
                      : 'START MINING',
              active
                  ? Icons.bolt_rounded
                  : completed
                      ? Icons.redeem_rounded
                      : Icons.hardware_rounded,
              active
                  ? null
                  : completed
                      ? _claimMining
                      : _startMining,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: _actionLoading
          ? null
          : onPressed,
      icon: _actionLoading
          ? const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Icon(
              icon,
              size: 26,
            ),
      label: Text(
        _actionLoading
            ? 'PLEASE WAIT'
            : label,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            const Color(0xFF4A20B9),
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            const Color(0xFF9B88D0),
        disabledForegroundColor:
            Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(17),
        ),
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
          const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF3C169B),
            size: 43,
          ),
          const SizedBox(width: 10),
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
                  style: const TextStyle(
                    color: Color(0xFF341490),
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

  Widget _buildAdsCard() {
    final displayedAds =
        _adsWatched > 7 ? 7 : _adsWatched;

    final progress = displayedAds / 7;

    return _whiteCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.rocket_launch_rounded,
                const Color(0xFFF0EBFF),
                const Color(0xFFE64949),
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
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 49,
                child: ElevatedButton.icon(
                  onPressed: _actionLoading
                      ? null
                      : _watchAd,
                  icon: const Icon(
                    Icons
                        .video_collection_rounded,
                    size: 20,
                  ),
                  label: const Text(
                    'WATCH AD',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4A20B9),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF9B88D0),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            'Ads watched today: $displayedAds / 7',
            style: const TextStyle(
              color: Color(0xFF35148F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  const Color(0xFFE9E4FA),
              valueColor:
                  const AlwaysStoppedAnimation(
                Color(0xFF5A2AD0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment:
                Alignment.centerRight,
            child: Text(
              '+${_adBoost.toStringAsFixed(1)} FAN/H',
              style: const TextStyle(
                color: Color(0xFF35148F),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_estimatedAdsFromRate > 0)
            Padding(
              padding:
                  const EdgeInsets.only(top: 3),
              child: Align(
                alignment:
                    Alignment.centerRight,
                child: Text(
                  'Verified boost: $_estimatedAdsFromRate ad${_estimatedAdsFromRate == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskCard() {
    return _whiteCard(
      child: Row(
        children: [
          _circleIcon(
            Icons.assignment_turned_in_rounded,
            const Color(0xFFE8F8F0),
            const Color(0xFF159B61),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY TASK',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Follow us on social media',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Follow and get 10 FAN reward',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _socialIcon('X'),
                  const SizedBox(width: 6),
                  _socialIcon('T'),
                  const SizedBox(width: 6),
                  _socialIcon('I'),
                  const SizedBox(width: 6),
                  _socialIcon('Y'),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(
                      'Daily social task will be connected soon.',
                    );
                  },
                  icon: const Icon(
                    Icons.card_giftcard_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'FOLLOW & EARN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xFF35148F),
                    side: const BorderSide(
                      color:
                          Color(0xFF35148F),
                      width: 1.3,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
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

  Widget _socialIcon(String letter) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildKycCard() {
    return _whiteCard(
      child: Row(
        children: [
          _circleIcon(
            Icons.verified_user_rounded,
            const Color(0xFFECE8FF),
            const Color(0xFF4320A5),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC VERIFICATION',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify your identity to secure your account',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              _showMessage(
                'KYC verification is Coming Soon.',
              );
            },
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  const Color(0xFF35148F),
              side: const BorderSide(
                color: Color(0xFF35148F),
                width: 1.3,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
            ),
            child: const Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'COMPLETE KYC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
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

  Widget _whiteCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _circleIcon(
    IconData icon,
    Color background,
    Color foreground,
  ) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: foreground,
        size: 31,
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.07),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            8,
            7,
            8,
            6,
          ),
          child: Row(
            children: [
              _navItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'HOME',
              ),
              _navItem(
                index: 1,
                icon: Icons.groups_rounded,
                label: 'REFERRAL',
              ),
              _navItem(
                index: 2,
                icon: Icons
                    .account_balance_wallet_rounded,
                label: 'WALLET',
              ),
              _navItem(
                index: 3,
                icon: Icons.settings_rounded,
                label: 'SETTINGS',
              ),
            ],
          ),
        ),
      ),
    );
