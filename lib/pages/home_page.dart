
import 'dart:async';
import 'dart:io';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';

import 'app_constants.dart';
import 'app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ============================================================
  // POWER FAN NETWORK THEME
  // ============================================================

  static const Color primary = Color(0xFF6C4BC4);
  static const Color darkPurple = Color(0xFF34205F);
  static const Color green = Color(0xFF20A464);
  static const Color background = Color(0xFFF8F7FC);
  static const Color softPurple = Color(0xFFF0EDFA);

  // ============================================================
  // APPLOVIN MAX
  // ============================================================
  //
  // Replace these with the REAL AppLovin MAX Rewarded Ad Unit IDs.
  //
  // Do NOT put your SDK Key here.
  // SDK initialization belongs in main.dart.
  //
  static const String _androidRewardedAdUnitId =
      'YOUR_ANDROID_REWARDED_AD_UNIT_ID';

  static const String _iosRewardedAdUnitId =
      'YOUR_IOS_REWARDED_AD_UNIT_ID';

  String get _rewardedAdUnitId {
    if (Platform.isIOS) {
      return _iosRewardedAdUnitId;
    }

    return _androidRewardedAdUnitId;
  }

  bool _adReady = false;
  bool _adShowing = false;
  bool _adLoading = false;

  int _rewardedAdRetryAttempt = 0;

  Timer? _uiTimer;

  AppState get _state => AppState.of(context);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRewardedAds();
      _startUiTimer();
    });
  }

  // ============================================================
  // APPLOVIN REWARDED ADS
  // ============================================================

  void _setupRewardedAds() {
    if (_rewardedAdUnitId.startsWith('YOUR_')) {
      return;
    }

    AppLovinMAX.setRewardedAdListener(
      RewardedAdListener(
        onAdLoadedCallback: (ad) {
          if (!mounted) return;

          setState(() {
            _adReady = true;
            _adLoading = false;
            _rewardedAdRetryAttempt = 0;
          });
        },

        onAdLoadFailedCallback: (adUnitId, error) {
          if (!mounted) return;

          setState(() {
            _adReady = false;
            _adLoading = false;
          });

          _scheduleRewardedAdRetry();
        },

        onAdDisplayedCallback: (ad) {
          if (!mounted) return;

          setState(() {
            _adShowing = true;
          });
        },

        onAdDisplayFailedCallback: (ad, error) {
          if (!mounted) return;

          setState(() {
            _adShowing = false;
            _adReady = false;
          });

          _showMessage(
            'The ad could not be displayed. Please try again.',
            isError: true,
          );

          _loadRewardedAd();
        },

        onAdClickedCallback: (ad) {
          // No reward is given here.
          //
          // Reward is given ONLY from:
          // onAdReceivedRewardCallback.
        },

        onAdHiddenCallback: (ad) {
          if (!mounted) return;

          setState(() {
            _adShowing = false;
            _adReady = false;
          });

          // Prepare the next rewarded ad.
          _loadRewardedAd();
        },

        onAdReceivedRewardCallback: (ad, reward) {
          if (!mounted) return;

          // ======================================================
          // IMPORTANT SECURITY RULE
          // ======================================================
          //
          // This is the ONLY place in HomePage where the local
          // rewarded-ad counter is registered.
          //
          // The button itself NEVER gives a reward.
          //
          final registered =
              _state.registerCompletedRewardedAd();

          if (!registered) {
            _showMessage(
              'Daily ad limit reached.',
              isError: true,
            );
            return;
          }

          _showMessage(
            'Reward confirmed. Your ad boost has been recorded.',
          );

          setState(() {});
        },
      ),
    );

    _loadRewardedAd();
  }

  Future<void> _loadRewardedAd() async {
    if (_rewardedAdUnitId.startsWith('YOUR_')) {
      return;
    }

    if (_adLoading || _adReady || _adShowing) {
      return;
    }

    _adLoading = true;

    AppLovinMAX.loadRewardedAd(
      _rewardedAdUnitId,
    );
  }

  void _scheduleRewardedAdRetry() {
    _rewardedAdRetryAttempt++;

    if (_rewardedAdRetryAttempt > 6) {
      _rewardedAdRetryAttempt = 6;
    }

    final seconds =
        1 << _rewardedAdRetryAttempt;

    Future.delayed(
      Duration(
        seconds: seconds > 64 ? 64 : seconds,
      ),
      () {
        if (!mounted) return;

        _loadRewardedAd();
      },
    );
  }

  // ============================================================
  // WATCH REWARDED AD
  // ============================================================

  Future<void> _watchRewardedAd() async {
    if (_adShowing) {
      return;
    }

    if (!_state.canWatchRewardedAd()) {
      _showMessage(
        'You have reached today\'s ad limit.',
        isError: true,
      );
      return;
    }

    if (_rewardedAdUnitId.startsWith('YOUR_')) {
      _showMessage(
        'AppLovin Rewarded Ad Unit ID has not been configured yet.',
        isError: true,
      );
      return;
    }

    final ready =
        await AppLovinMAX.isRewardedAdReady(
      _rewardedAdUnitId,
    );

    if (!mounted) return;

    if (ready != true) {
      setState(() {
        _adReady = false;
      });

      _loadRewardedAd();

      _showMessage(
        'Rewarded ad is not ready yet. Please try again.',
        isError: true,
      );

      return;
    }

    setState(() {
      _adShowing = true;
    });

    AppLovinMAX.showRewardedAd(
      _rewardedAdUnitId,
    );
  }

  // ============================================================
  // UI TIMER
  // ============================================================

  void _startUiTimer() {
    _uiTimer?.cancel();

    _uiTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {});
      },
    );
  }

  // ============================================================
  // MINING
  // ============================================================

  void _startMining() {
    final started = _state.startMining();

    if (!started) {
      _showMessage(
        'Mining is already active.',
        isError: true,
      );
      return;
    }

    _showMessage(
      'Mining started successfully.',
    );

    setState(() {});
  }

  void _claimMining() {
    final reward =
        _state.claimMiningReward();

    if (reward <= 0) {
      _showMessage(
        'Mining is not ready for claiming yet.',
        isError: true,
      );
      return;
    }

    _showMessage(
      '+${reward.toStringAsFixed(4)} FAN added to your balance.',
    );

    setState(() {});
  }

  // ============================================================
  // DAILY CHECK-IN
  // ============================================================

  void _dailyCheckIn() {
    final success =
        _state.dailyCheckIn();

    if (!success) {
      _showMessage(
        'You have already checked in today.',
        isError: true,
      );
      return;
    }

    _showMessage(
      'Daily check-in reward claimed.',
    );

    setState(() {});
  }

  // ============================================================
  // SOCIAL TASK
  // ============================================================

  void _claimSocialTask() {
    if (!_state.canClaimSocialTask()) {
      _showMessage(
        'Complete and verify today\'s social task before claiming.',
        isError: true,
      );
      return;
    }

    final reward =
        _state.claimSocialTask();

    if (reward <= 0) {
      _showMessage(
        'Social task reward could not be claimed.',
        isError: true,
      );
      return;
    }

    _showMessage(
      '+${reward.toStringAsFixed(2)} FAN social reward claimed.',
    );

    setState(() {});
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatDuration(Duration duration) {
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

  String _formatNumber(double value) {
    return value.toStringAsFixed(4);
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Colors.red.shade700 : darkPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        10,
        12,
        5,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'AFAM',
                  style: TextStyle(
                    color: primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'POWER FAN NETWORK',
                  style: TextStyle(
                    color: darkPurple,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Mine FAN. Earn More',
                  style: TextStyle(
                    color: darkPurple,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: _showNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: primary,
                  size: 32,
                ),

                if (_state.unreadNotificationCount > 0)
                  Positioned(
                    right: -1,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration:
                          const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
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
  // BALANCE HEADER
  // ============================================================

  Widget _buildBalanceHeader() {
    return _card(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL FAN BALANCE',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatNumber(
                    _state.fanBalance,
                  ),
                  style: const TextStyle(
                    color: darkPurple,
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const Text(
                'FAN',
                style: TextStyle(
                  color: primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _smallStat(
                  Icons.people_alt_outlined,
                  'REFERRALS',
                  '${_state.referralCount}',
                ),
              ),
              Expanded(
                child: _smallStat(
                  Icons.local_fire_department,
                  'STREAK',
                  '${_state.checkInStreak} DAYS',
                ),
              ),
              Expanded(
                child: _smallStat(
                  Icons.play_circle_outline,
                  'ADS LEFT',
                  '${_state.adsRemainingToday}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  _state.isTodayCheckedIn
                      ? null
                      : _dailyCheckIn,
              icon: const Icon(
                Icons.calendar_today,
              ),
              label: Text(
                _state.isTodayCheckedIn
                    ? 'CHECKED IN TODAY'
                    : 'DAILY CHECK-IN',
              ),
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
    final isMining =
        _state.miningStatus ==
            AppConstants.miningStatusMining;

    final completed =
        _state.miningStatus ==
            AppConstants.miningStatusCompleted;

    final progress =
        _state.miningProgress;

    final remaining =
        _state.miningRemainingTime;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.bolt,
                color:
                    isMining
                        ? Colors.orange.shade700
                        : primary,
                background:
                    isMining
                        ? const Color(0xFFFFF2DD)
                        : softPurple,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAN MINING',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isMining
                          ? 'Mining is active'
                          : completed
                              ? 'Mining completed'
                              : 'Ready to start mining',
                      style: TextStyle(
                        color:
                            completed
                                ? green
                                : const Color(
                                    0xFF45415B,
                                  ),
                        fontSize: 14,
                        fontWeight:
                            completed
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${_state.currentMiningRate.toStringAsFixed(2)} FAN/H',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Divider(),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _statItem(
                  Icons.speed,
                  'MINING RATE',
                  '${_state.currentMiningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),

              Container(
                width: 1,
                height: 55,
                color: Colors.grey.shade300,
              ),

              Expanded(
                child: _statItem(
                  Icons.access_time,
                  'SESSION TIME',
                  isMining
                      ? _formatDuration(
                          remaining,
                        )
                      : completed
                          ? 'COMPLETED'
                          : '24:00:00',
                ),
              ),
            ],
          ),

          if (isMining) ...[
            const SizedBox(height: 18),

            LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  const Color(0xFFE9E5F5),
              valueColor:
                  const AlwaysStoppedAnimation(
                primary,
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed:
                  completed
                      ? _claimMining
                      : isMining
                          ? null
                          : _startMining,
              icon: Icon(
                completed
                    ? Icons.account_balance_wallet
                    : isMining
                        ? Icons.bolt
                        : Icons.hardware,
              ),
              label: Text(
                completed
                    ? 'CLAIM MINING REWARD'
                    : isMining
                        ? 'MINING ACTIVE'
                        : 'START MINING',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    completed
                        ? green
                        : primary,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade400,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REWARDED ADS CARD
  // ============================================================

  Widget _buildAdsCard() {
    final remaining =
        _state.adsRemainingToday;

    final maxAds =
        AppConstants.maxDailyAds;

    final watched =
        maxAds - remaining;

    final progress =
        maxAds <= 0
            ? 0.0
            : (watched / maxAds)
                .clamp(0.0, 1.0);

    final limitReached =
        remaining <= 0;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.ondemand_video,
                color: Colors.deepPurple,
                background:
                    const Color(0xFFEDE7F8),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AD BOOST',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Watch rewarded ads to increase your mining rate.',
                      style: TextStyle(
                        color:
                            Color(0xFF45415B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$remaining LEFT',
                style: TextStyle(
                  color:
                      limitReached
                          ? Colors.grey
                          : green,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TODAY\'S ADS',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$watched / $maxAds',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor:
                  const Color(0xFFE9E5F5),
              valueColor:
                  const AlwaysStoppedAnimation(
                primary,
              ),
            ),
          ),

          const SizedBox(height: 15),

          if (!_adReady &&
              !limitReached &&
              !_adShowing)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    _adLoading
                        ? Icons.hourglass_top
                        : Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _adLoading
                          ? 'Loading rewarded ad...'
                          : 'Rewarded ad is preparing...',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  limitReached ||
                          _adShowing ||
                          !_adReady
                      ? null
                      : _watchRewardedAd,
              icon: Icon(
                _adShowing
                    ? Icons.hourglass_top
                    : Icons.play_circle,
              ),
              label: Text(
                limitReached
                    ? 'DAILY LIMIT REACHED'
                    : _adShowing
                        ? 'WATCHING AD...'
                        : !_adReady
                            ? 'AD NOT READY'
                            : 'WATCH AD & GET BOOST',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade300,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'Reward is granted only after AppLovin confirms completion.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAILY SOCIAL TASK
  // ============================================================

  Widget _buildSocialCard() {
    final verified =
        _state.socialTaskVerified;

    final claimed =
        _state.socialTaskClaimed;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.task_alt,
                color:
                    Colors.green.shade800,
                background:
                    const Color(0xFFE7F5EC),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY TASK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Complete social media tasks',
                      style: TextStyle(
                        color:
                            Color(0xFF45415B),
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '+${AppConstants.dailySocialTaskReward.toStringAsFixed(0)} FAN',
                style: const TextStyle(
                  color: green,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          _taskStatus(
            'Complete today\'s social task',
            verified,
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  verified
                      ? const Color(
                          0xFFE7F5EC,
                        )
                      : const Color(
                          0xFFFFF4E5,
                        ),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  verified
                      ? Icons.verified
                      : Icons.lock_outline,
                  color:
                      verified
                          ? green
                          : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    verified
                        ? 'Task verified. You can claim the reward.'
                        : 'Task must be verified before claiming.',
                    style: TextStyle(
                      color:
                          verified
                              ? green
                              : Colors
                                  .orange
                                  .shade800,
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  !verified || claimed
                      ? null
                      : _claimSocialTask,
              icon: const Icon(
                Icons.card_giftcard,
              ),
              label: Text(
                claimed
                    ? 'REWARD CLAIMED'
                    : verified
                        ? 'CLAIM SOCIAL REWARD'
                        : 'VERIFY TASK FIRST',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade300,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          if (!verified && !claimed)
            const Padding(
              padding:
                  EdgeInsets.only(top: 10),
              child: Text(
                'You cannot claim until the task has been verified.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // REFERRAL CARD
  // ============================================================

  Widget _buildReferralCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.people_alt,
                color: primary,
                background: softPurple,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFERRAL NETWORK',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Build your network and increase your mining rate.',
                      style: TextStyle(
                        color:
                            Color(0xFF45415B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _referralStat(
                  'TOTAL',
                  '${_state.referralCount}',
                  Icons.people,
                ),
              ),
              Expanded(
                child: _referralStat(
                  'ACTIVE',
                  '${_state.activeReferralCount}',
                  Icons.bolt,
                ),
              ),
              Expanded(
                child: _referralStat(
                  'BOOST',
                  '+${_state.referralMiningBoost.toStringAsFixed(2)}',
                  Icons.trending_up,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                _showMessage(
                  'Referral page will be connected to the referral system.',
                );
              },
              icon: const Icon(
                Icons.share,
              ),
              label: const Text(
                'INVITE FRIENDS',
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
    final status =
        _state.kyc1Status;

    final available =
        status ==
            AppConstants.kycStatusAvailable;

    final verified =
        status ==
            AppConstants.kycStatusVerified;

    return _card(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      child: Row(
        children: [
          _iconCircle(
            Icons.verified_user,
            color:
                verified
                    ? green
                    : primary,
            background:
                verified
                    ? const Color(
                        0xFFE7F5EC,
                      )
                    : softPurple,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'KYC VERIFICATION',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  verified
                      ? 'Your identity is verified.'
                      : available
                          ? 'KYC is available for your account.'
                          : 'Continue using the app to unlock KYC.',
                  style: const TextStyle(
                    color:
                        Color(0xFF45415B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          OutlinedButton(
            onPressed:
                verified
                    ? null
                    : () {
                        _showMessage(
                          available
                              ? 'KYC verification module is ready for backend connection.'
                              : 'KYC is currently locked.',
                        );
                      },
            child: Text(
              verified
                  ? 'VERIFIED'
                  : available
                      ? 'VERIFY'
                      : 'LOCKED',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.72,
          decoration:
              const BoxDecoration(
            color: background,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 45,
                height: 5,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade300,
                  borderRadius:
                      BorderRadius.circular(20),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  18,
                  12,
                  10,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          color: darkPurple,
                          fontSize: 22,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _state
                            .markAllNotificationsRead();

                        setState(() {});

                        Navigator.pop(
                          context,
                        );
                      },
                      child:
                          const Text(
                        'MARK ALL READ',
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child:
                    _state.notifications.isEmpty
                        ? const Center(
                            child: Text(
                              'No notifications yet.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets
                                    .all(
                              16,
                            ),
                            itemCount:
                                _state
                                    .notifications
                                    .length,
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final item =
                                  _state
                                      .notifications[
                                index
                              ];

                              return _notificationTile(
                                item,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _notificationTile(
    AppNotification item,
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
            BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () {
          _state
              .markNotificationRead(
            item.id,
          );

          setState(() {});
        },
        leading: CircleAvatar(
          backgroundColor:
              softPurple,
          child: Icon(
            item.type ==
                    'mining_completed'
                ? Icons.bolt
                : Icons.notifications,
            color: primary,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight:
                item.read
                    ? FontWeight.normal
                    : FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 5,
          ),
          child: Text(
            item.message,
          ),
        ),
        trailing:
            item.read
                ? null
                : Container(
                    width: 8,
                    height: 8,
                    decoration:
                        const BoxDecoration(
                      color: Colors.red,
                      shape:
                          BoxShape.circle,
                    ),
                  ),
      ),
    );
  }

  // ============================================================
  // GENERIC CARD
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // ICON CIRCLE
  // ============================================================

  Widget _iconCircle(
    IconData icon, {
    Color color = primary,
    Color background = softPurple,
  }) {
    return Container(
      width: 58,
      height: 58,
      decoration:
          BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 30,
      ),
    );
  }

  // ============================================================
  // SMALL STAT
  // ============================================================

  Widget _smallStat(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: primary,
          size: 21,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: darkPurple,
            fontSize: 13,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT ITEM
  // ============================================================

  Widget _statItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: primary,
          size: 24,
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign:
              TextAlign.center,
          style: const TextStyle(
            color: darkPurple,
            fontSize: 14,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REFERRAL STAT
  // ============================================================

  Widget _referralStat(
    String title,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: primary,
          size: 23,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: darkPurple,
            fontSize: 15,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 9,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TASK STATUS
  // ============================================================

  Widget _taskStatus(
    String title,
    bool completed,
  ) {
    return Row(
      children: [
        Icon(
          completed
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color:
              completed
                  ? green
                  : Colors.grey,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color:
                  completed
                      ? green
                      : const Color(
                          0xFF45415B,
                        ),
              fontWeight:
                  completed
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),
        ),
        Text(
          completed
              ? 'DONE'
              : 'PENDING',
          style: TextStyle(
            color:
                completed
                    ? green
                    : Colors.grey,
            fontSize: 11,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (
        context,
        child,
      ) {
        return Scaffold(
          backgroundColor:
              background,

          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child:
                      RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        16,
                        10,
                        16,
                        30,
                      ),
                      children: [
                        _buildBalanceHeader(),

                        const SizedBox(
                          height: 16,
                        ),

                        _buildMiningCard(),

                        const SizedBox(
                          height: 16,
                        ),

                        _buildAdsCard(),

                        const SizedBox(
                          height: 16,
                        ),

                        _buildSocialCard(),

                        const SizedBox(
                          height: 16,
                        ),

                        _buildReferralCard(),

                        const SizedBox(
                          height: 16,
                        ),

                        _buildKycCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _uiTimer?.cancel();

    super.dispose();
  }
}
