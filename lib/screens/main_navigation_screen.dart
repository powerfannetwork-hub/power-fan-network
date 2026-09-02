import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mining_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  final MiningService _miningService =
      MiningService.instance;

  int _currentIndex = 0;

  double _balance = 0.0;
  double _afamBalance = 0.0;
  double _miningRate = 0.2;

  int _adsWatched = 0;

  bool _isMining = false;
  bool _loading = true;
  bool _busy = false;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Timer? _timer;

  Duration get _sessionRemaining {
    if (_endsAt == null) {
      return Duration.zero;
    }

    final remaining =
        _endsAt!.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  Duration get _sessionElapsed {
    if (_startedAt == null) {
      return Duration.zero;
    }

    final elapsed =
        DateTime.now().difference(_startedAt!);

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return elapsed;
  }

  bool get _sessionFinished {
    if (!_isMining || _endsAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(_endsAt!);
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    String? firstError;

    try {
      await _loadProfile();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    try {
      await _loadMining();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    try {
      await _loadMiningRate();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    try {
      await _loadAdsCount();
    } catch (e) {
      firstError ??= _cleanError(e);
    }

    _startUiTimer();

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }

    if (firstError != null && mounted) {
      _showMessage(firstError);
    }
  }

  Future<void> _loadProfile() async {
    final result =
        await _miningService.getProfile();

    final fan =
        result['fan_balance'] ??
        result['fanBalance'] ??
        0;

    final afam =
        result['afam_balance'] ??
        result['afamBalance'] ??
        0;

    if (!mounted) return;

    setState(() {
      _balance = _toDouble(fan);
      _afamBalance = _toDouble(afam);
    });
  }

  Future<void> _loadAdsCount() async {
    final count =
        await _miningService.getAdsWatchedToday();

    if (!mounted) return;

    setState(() {
      _adsWatched = count.clamp(0, 7);
    });
  }

  Future<void> _loadMiningRate() async {
    final result =
        await _miningService.getUserMiningRate();

    final possibleRate = [
      result['rate'],
      result['mining_rate'],
      result['value'],
    ];

    for (final value in possibleRate) {
      if (value != null) {
        if (!mounted) return;

        setState(() {
          _miningRate = _toDouble(value);
        });

        return;
      }
    }
  }

  Future<void> _loadMining() async {
    final result =
        await _miningService.getActiveMining();

    final active =
        result['active'] == true ||
        result['is_active'] == true;

    if (!active) {
      if (!mounted) return;

      setState(() {
        _isMining = false;
        _startedAt = null;
        _endsAt = null;
      });

      return;
    }

    final started =
        _parseDate(result['started_at']);

    final ends =
        _parseDate(result['ends_at']);

    if (!mounted) return;

    setState(() {
      _isMining = true;
      _startedAt = started;
      _endsAt = ends;
    });
  }

  void _startUiTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        if (!mounted) return;

        if (_isMining &&
            _endsAt != null &&
            !DateTime.now().isBefore(_endsAt!)) {
          await _loadMining();
          await _loadProfile();
          await _loadMiningRate();
        }

        if (mounted) {
          setState(() {});
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
      final result =
          await _miningService.startMining();

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Unable to start mining.',
        );
        return;
      }

      await _loadMining();
      await _loadMiningRate();

      _showMessage(
        'Mining started successfully.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
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
     * Mining cannot be claimed before the full 24-hour
     * session has finished.
     */
    if (!_sessionFinished) {
      final remaining = _sessionRemaining;

      _showMessage(
        'Mining is still running. '
        'You can claim after '
        '${_formatDuration(remaining)}.',
      );

      return;
    }

    /*
     * The final claim should be protected by a real rewarded
     * advertisement flow. Until the actual rewarded-ad SDK is
     * connected, we do not pretend that an ad was watched.
     */
    _showMessage(
      'Please watch the required rewarded ad before claiming.',
    );
  }

  Future<void> _watchAd() async {
    if (_busy) return;

    if (_adsWatched >= 7) {
      _showMessage(
        'You have reached today\'s 7 ads limit.',
      );
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final adReference =
          'mobile_${DateTime.now().millisecondsSinceEpoch}';

      final result =
          await _miningService.recordRewardedAd(
        adRef: adReference,
      );

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Unable to record rewarded ad.',
        );
        return;
      }

      /*
       * Re-read from database instead of trusting a local
       * counter.
       */
      await _loadAdsCount();
      await _loadMiningRate();

      _showMessage(
        'Rewarded ad recorded successfully.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _dailyCheckin() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      final result =
          await _miningService.dailyCheckin();

      if (result['success'] == false) {
        _showMessage(
          result['message']?.toString() ??
              'Daily check-in failed.',
        );
        return;
      }

      await _loadProfile();

      _showMessage(
        'Daily check-in completed successfully.',
      );
    } catch (e) {
      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadDashboard();
  }

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

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    if (text.startsWith('PostgrestException: ')) {
      text = text.substring(19);
    }

    return text.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : text.trim();
  }

  String _formatDuration(Duration duration) {
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
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
      backgroundColor:
          const Color(0xFFF8F8FC),
      body: SafeArea(
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      Color(0xFF4A20B9),
                ),
              )
            : pages[_currentIndex],
      ),
      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: const Color(0xFF4A20B9),
      onRefresh: _refresh,
      child: CustomScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),
          SliverPadding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              24,
            ),
            sliver: SliverList(
              delegate:
                  SliverChildListDelegate(
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
      padding:
          const EdgeInsets.fromLTRB(
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
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(15),
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xFF5B2BD9),
                  Color(0xFF32148E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xFF3B159B)
                          .withOpacity(0.22),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'P',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'POWER FAN',
                  style: TextStyle(
                    color:
                        Color(0xFF35148F),
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                Text(
                  'Mine FAN. Earn More',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior:
                Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  _showMessage(
                    'No new notifications.',
                  );
                },
                icon: const Icon(
                  Icons
                      .notifications_none_rounded,
                  size: 31,
                  color:
                      Color(0xFF28116F),
                ),
              ),
              Positioned(
                top: 7,
                right: 7,
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
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      height: 178,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(25),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xFF4820B7),
            Color(0xFF291075),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF35128D)
                    .withOpacity(0.28),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
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
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 15,
            bottom: 5,
            child:
                _buildMiningCharacter(),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              21,
              15,
              18,
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
                    fontWeight:
                        FontWeight.w700,
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
                      decoration:
                          const BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            Color(0xFFFFB800),
                      ),
                      child:
                          const Icon(
                        Icons
                            .star_rounded,
                        color:
                            Color(0xFFE88700),
                        size: 35,
                      ),
                    ),
                    const SizedBox(
                      width: 11,
                    ),
                    Flexible(
                      child: Text(
                        _balance
                            .toStringAsFixed(
                          4,
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 37,
                          fontWeight:
                              FontWeight
                                  .w900,
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
                        fontSize: 20,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'AFAM ${_afamBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.85),
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w500,
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
        alignment:
            Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 2,
            right: 0,
            child: Container(
              width: 76,
              height: 76,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    const Color(
                  0xFF743BDF,
                ).withOpacity(0.75),
              ),
              child: const Center(
                child: Icon(
                  Icons.bolt_rounded,
                  color:
                      Color(0xFFFFC400),
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
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF7B4B2A,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
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
                Icons
                    .construction_rounded,
                color:
                    Color(0xFFE7D4FF),
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
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFF4A261),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Column(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
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
                    color:
                        Color(0xFF32148E),
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
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFF5323B7),
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      Radius.circular(28),
                  topRight:
                      Radius.circular(28),
                  bottomLeft:
                      Radius.circular(15),
                  bottomRight:
                      Radius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    final remaining =
        _sessionRemaining;

    final elapsed =
        _sessionElapsed;

    final sessionText =
        _isMining
            ? _sessionFinished
                ? '24:00:00'
                : _formatDuration(
                    elapsed,
                  )
            : '00:00:00';

    final buttonLabel =
        _busy
            ? 'PLEASE WAIT...'
            : _isMining
                ? 'CLAIM MINING'
                : 'START MINING';

    return _whiteCard(
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.handyman_rounded,
                const Color(0xFFEAE5FF),
                const Color(0xFF4520AA),
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
                          style:
                              TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        Text(
                          _isMining
                              ? 'MINING'
                              : 'READY',
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF159B61,
                            ),
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isMining
                          ? _sessionFinished
                              ? 'Mining session completed'
                              : 'Mining FAN right now'
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
          const SizedBox(height: 17),
          Divider(
            color:
                Colors.grey.shade200,
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
                color:
                    Colors.grey.shade200,
              ),
              Expanded(
                child: _miningInfo(
                  Icons.access_time_rounded,
                  'SESSION TIME',
                  '$sessionText / 24:00:00',
                ),
              ),
            ],
          ),
          if (_isMining) ...[
            const SizedBox(height: 10),
            Text(
              _sessionFinished
                  ? 'Session completed. Watch the required ad before claiming.'
                  : 'Time remaining: ${_formatDuration(remaining)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    _sessionFinished
                        ? const Color(
                            0xFF159B61,
                          )
                        : Colors.black54,
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 58,
            child:
                ElevatedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : _isMining
                          ? _claimMining
                          : _startMining,
              icon: Icon(
                _busy
                    ? Icons
                        .hourglass_top_rounded
                    : _isMining
                        ? Icons
                            .card_giftcard_rounded
                        : Icons
                            .hardware_rounded,
                size: 26,
              ),
              label: Text(
                buttonLabel,
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF4A20B9,
                ),
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    const Color(
                  0xFF8D76CF,
                ),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
              ),
            ),
          ),
        ],
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
        horizontal: 9,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                const Color(0xFF3C169B),
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
                    color:
                        Color(0xFF341490),
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
    final progress =
        (_adsWatched / 7)
            .clamp(0.0, 1.0);

    final boost =
        (_miningRate - 0.2)
            .clamp(0.0, 0.7);

    return _whiteCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIcon(
                Icons
                    .rocket_launch_rounded,
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
                      style:
                          TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style:
                          TextStyle(
                        fontSize: 13,
                        color:
                            Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 49,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _busy ||
                              _adsWatched >= 7
                          ? null
                          : _watchAd,
                  icon:
                      const Icon(
                    Icons
                        .video_collection_rounded,
                    size: 20,
                  ),
                  label:
                      const Text(
                    'WATCH AD',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF4A20B9,
                    ),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        const Color(
                      0xFF8D76CF,
                    ),
                    elevation: 0,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 14,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            'Ads watched today: $_adsWatched / 7',
            style:
                const TextStyle(
              color:
                  Color(0xFF35148F),
              fontSize: 14,
              fontWeight:
                  FontWeight.w700,
            ),
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
                0xFFE9E4FA,
              ),
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
              '+${boost.toStringAsFixed(1)} FAN/H',
              style:
                  const TextStyle(
                color:
                    Color(0xFF35148F),
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
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
            Icons
                .assignment_turned_in_rounded,
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
                  style:
                      TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Follow us on social media',
                  style:
                      TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Follow and get 10 FAN reward',
                  style:
                      TextStyle(
                    color:
                        Colors.black54,
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
                  const SizedBox(
                    width: 6,
                  ),
                  _socialIcon('T'),
                  const SizedBox(
                    width: 6,
                  ),
                  _socialIcon('I'),
                  const SizedBox(
                    width: 6,
                  ),
                  _socialIcon('Y'),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 42,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _dailyCheckin,
                  icon:
                      const Icon(
                    Icons
                        .card_giftcard_rounded,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'FOLLOW & EARN',
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        const Color(
                      0xFF35148F,
                    ),
                    side:
                        const BorderSide(
                      color:
                          Color(0xFF35148F),
                      width: 1.3,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
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
      decoration:
          BoxDecoration(
        color: Colors.black,
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Center(
        child: Text(
          letter,
          style:
              const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight:
                FontWeight.w900,
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
            Icons
                .verified_user_rounded,
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
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify your identity to secure your account',
                  style:
                      TextStyle(
                    color:
                        Colors.black54,
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
                  const Color(
                0xFF35148F,
              ),
              side:
                  const BorderSide(
                color:
                    Color(0xFF35148F),
                width: 1.3,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
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
                  style:
                      TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(width: 5),
                Icon(
                  Icons
                      .chevron_right_rounded,
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
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.045,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
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
      decoration:
          BoxDecoration(
        color: background,
        shape:
            BoxShape.circle,
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
      decoration:
          BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.07,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, -3),
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
                icon:
                    Icons.home_rounded,
                label: 'HOME',
              ),
              _navItem(
                index: 1,
                icon:
                    Icons.groups_rounded,
                label: 'REFERRAL',
              ),
              _navItem(
                index: 2,
                icon:
                    Icons
                        .account_balance_wallet_rounded,
                label: 'WALLET',
              ),
              _navItem(
                index: 3,
                icon:
                    Icons.settings_rounded,
                label: 'SETTINGS',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected =
        _currentIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            vertical: 5,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 29,
                color: selected
                    ? const Color(
                        0xFF4A20B9,
                      )
                    : const Color(
                        0xFF606060,
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style:
                    TextStyle(
                  color: selected
                      ? const Color(
                          0xFF35148F,
                        )
                      : const Color(
                          0xFF606060,
                        ),
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight
                          .w900
                      : FontWeight
                          .w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralPage() {
    return _simplePage(
      icon:
          Icons.groups_rounded,
      title: 'REFERRAL',
      subtitle:
          'Invite friends and grow your FAN mining rate.',
      child: Column(
        children: [
          _infoBox(
            'Referral reward',
            '5 FAN',
            Icons
                .card_giftcard_rounded,
          ),
          const SizedBox(height: 12),
          _infoBox(
            'New user reward',
            '20 FAN',
            Icons
                .person_add_alt_1_rounded,
          ),
          const SizedBox(height: 12),
          _infoBox(
            'Mining boost',
            '+0.02 FAN/H per active referral',
            Icons.speed_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletPage() {
    return _simplePage(
      icon:
          Icons
              .account_balance_wallet_rounded,
      title: 'WALLET',
      subtitle:
          'Your AFAM wallet will be available soon.',
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(25),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color:
                  Color(0xFF4320A5),
              size: 58,
            ),
            const SizedBox(height: 15),
            const Text(
              'COMING SOON',
              style:
                  TextStyle(
                color:
                    Color(0xFF4320A5),
                fontSize: 20,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AFAM Balance: ${_afamBalance.toStringAsFixed(2)}',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return _simplePage(
      icon:
          Icons.settings_rounded,
      title: 'SETTINGS',
      subtitle:
          'Manage your POWER FAN account.',
      child: Column(
        children: [
          _settingsItem(
            Icons
                .person_outline_rounded,
            'Profile',
            'Manage your account information',
          ),
          _settingsItem(
            Icons
                .notifications_none_rounded,
            'Notifications',
            'Manage notifications',
          ),
          _settingsItem(
            Icons.language_rounded,
            'Language',
            'English',
          ),
          _settingsItem(
            Icons.security_rounded,
            'Security',
            'Account security',
          ),
          _settingsItem(
            Icons.info_outline_rounded,
            'About POWER FAN',
            'Version 1.0.0',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                OutlinedButton.icon(
              onPressed: () async {
                await Supabase
                    .instance
                    .client
                    .auth
                    .signOut();
              },
              icon:
                  const Icon(
                Icons.logout_rounded,
              ),
              label:
                  const Text(
                'LOG OUT',
                style:
                    TextStyle(
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

  Widget _simplePage({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        25,
        18,
        30,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 53,
                height: 53,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFEDE8FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF4320A5,
                  ),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF35148F,
                        ),
                        fontSize: 25,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _infoBox(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          _circleIcon(
            icon,
            const Color(0xFFEDE8FF),
            const Color(0xFF4320A5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style:
                      const TextStyle(
                    color:
                        Color(0xFF35148F),
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsItem(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Icon(
          icon,
          color:
              const Color(0xFF4320A5),
          size: 27,
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        subtitle:
            Text(subtitle),
        trailing:
            const Icon(
          Icons.chevron_right_rounded,
          color: Colors.black45,
        ),
        onTap: () {
          _showMessage(
            '$title will be connected soon.',
          );
        },
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 13,
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF291075),
        borderRadius:
            BorderRadius.circular(8),
      ),
    );
  }
}
