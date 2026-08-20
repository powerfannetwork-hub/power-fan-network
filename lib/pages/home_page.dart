import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color primary = Color(0xFF35129B);
  static const Color green = Color(0xFF239B5A);

  double fanBalance = 20.0000;

  // Base mining rate
  double baseMiningRate = 0.2;

  // Extra mining from watched ads
  double adBoost = 0.0;

  // Number of ads watched today
  int adsWatchedToday = 0;

  // Maximum ads per day
  final int maxAdsPerDay = 7;

  // Mining state
  bool isMining = false;

  // Daily social task
  bool socialFollowCompleted = false;
  bool socialLikeCompleted = false;
  bool socialCommentCompleted = false;
  bool socialClaimed = false;

  // Referral
  int referralCount = 0;
  int activeReferrals = 0;

  // New user reward
  bool newUserRewardClaimed = false;

  // KYC
  bool kycCompleted = false;

  // Notifications
  final List<String> notifications = [];

  Timer? miningTimer;
  Timer? notificationTimer;

  int selectedIndex = 0;

  double get referralBoost => activeReferrals * 0.02;

  double get miningRate {
    return baseMiningRate + adBoost + referralBoost;
  }

  bool get socialTaskCompleted {
    return socialFollowCompleted &&
        socialLikeCompleted &&
        socialCommentCompleted;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    miningTimer?.cancel();
    notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedBalance = prefs.getDouble('fan_balance');
    final savedAds = prefs.getInt('ads_watched_today');
    final savedAdBoost = prefs.getDouble('ad_boost');
    final savedMining = prefs.getBool('is_mining');

    setState(() {
      fanBalance = savedBalance ?? 20.0000;
      adsWatchedToday = savedAds ?? 0;
      adBoost = savedAdBoost ?? 0.0;
      isMining = savedMining ?? false;

      socialFollowCompleted =
          prefs.getBool('social_follow_completed') ?? false;
      socialLikeCompleted =
          prefs.getBool('social_like_completed') ?? false;
      socialCommentCompleted =
          prefs.getBool('social_comment_completed') ?? false;
      socialClaimed = prefs.getBool('social_claimed') ?? false;

      referralCount = prefs.getInt('referral_count') ?? 0;
      activeReferrals = prefs.getInt('active_referrals') ?? 0;

      newUserRewardClaimed =
          prefs.getBool('new_user_reward_claimed') ?? false;

      kycCompleted = prefs.getBool('kyc_completed') ?? false;
    });

    if (isMining) {
      _startMiningTimer();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('fan_balance', fanBalance);
    await prefs.setInt('ads_watched_today', adsWatchedToday);
    await prefs.setDouble('ad_boost', adBoost);
    await prefs.setBool('is_mining', isMining);

    await prefs.setBool(
      'social_follow_completed',
      socialFollowCompleted,
    );

    await prefs.setBool(
      'social_like_completed',
      socialLikeCompleted,
    );

    await prefs.setBool(
      'social_comment_completed',
      socialCommentCompleted,
    );

    await prefs.setBool('social_claimed', socialClaimed);

    await prefs.setInt('referral_count', referralCount);
    await prefs.setInt('active_referrals', activeReferrals);

    await prefs.setBool(
      'new_user_reward_claimed',
      newUserRewardClaimed,
    );

    await prefs.setBool('kyc_completed', kycCompleted);
  }

  void _startMiningTimer() {
    miningTimer?.cancel();

    miningTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (!mounted || !isMining) return;

        // Small simulation update.
        // The real backend should calculate the final balance.
        final earned = miningRate / 360.0;

        setState(() {
          fanBalance += earned;
        });

        _saveData();
      },
    );
  }

  void _startMining() {
    if (isMining) return;

    setState(() {
      isMining = true;
    });

    _startMiningTimer();
    _saveData();

    _addNotification(
      'Mining Started',
      'Your FAN mining session has started.',
    );
  }

  void _stopMining() {
    if (!isMining) return;

    setState(() {
      isMining = false;
    });

    miningTimer?.cancel();
    _saveData();

    _addNotification(
      'Mining Stopped',
      'Your mining session has stopped.',
    );
  }

  void _watchAd() {
    if (adsWatchedToday >= maxAdsPerDay) {
      _showMessage(
        'You have reached today’s maximum of 7 ads.',
      );
      return;
    }

    // Demo ad completion.
    // Connect this button to your real ad provider later.
    setState(() {
      adsWatchedToday++;
      adBoost += 0.1;
    });

    _saveData();

    _addNotification(
      'Mining Boost Added',
      '+0.1 FAN/H has been added to your mining rate.',
    );

    _showMessage(
      'Ad completed! +0.1 FAN/H added.',
    );
  }

  void _completeFollow() {
    setState(() {
      socialFollowCompleted = true;
    });

    _saveData();
    _showMessage('Follow task completed.');
  }

  void _completeLike() {
    setState(() {
      socialLikeCompleted = true;
    });

    _saveData();
    _showMessage('Like task completed.');
  }

  void _completeComment() {
    setState(() {
      socialCommentCompleted = true;
    });

    _saveData();
    _showMessage('Comment task completed.');
  }

  void _claimSocialReward() {
    if (!socialTaskCompleted) {
      _showMessage(
        'Complete Follow, Like and Comment before claiming.',
      );
      return;
    }

    if (socialClaimed) {
      _showMessage(
        'You have already claimed today’s social reward.',
      );
      return;
    }

    setState(() {
      fanBalance += 10;
      socialClaimed = true;
    });

    _saveData();

    _addNotification(
      'Daily Social Reward',
      'You received 10 FAN for completing the social task.',
    );

    _showMessage('Congratulations! You received 10 FAN.');
  }

  void _claimNewUserReward() {
    if (newUserRewardClaimed) {
      _showMessage('New user reward has already been claimed.');
      return;
    }

    setState(() {
      fanBalance += 20;
      newUserRewardClaimed = true;
    });

    _saveData();

    _addNotification(
      'Welcome Reward',
      'You received 20 FAN as a new user reward.',
    );

    _showMessage('Welcome! 20 FAN added to your balance.');
  }

  void _addReferral() {
    setState(() {
      referralCount++;
      activeReferrals++;
      fanBalance += 5;
    });

    _saveData();

    _addNotification(
      'Referral Reward',
      'You received 5 FAN for inviting a new user.',
    );

    _showMessage(
      'Referral added! +5 FAN and +0.02 FAN/H boost.',
    );
  }

  void _notifyInactiveReferrals() {
    if (referralCount == 0) {
      _showMessage('You do not have any referrals yet.');
      return;
    }

    _addNotification(
      'Referral Reminder',
      'Your inactive referrals have been notified to start mining.',
    );

    _showMessage(
      'Reminder sent to inactive referrals.',
    );
  }

  void _addNotification(String title, String message) {
    setState(() {
      notifications.insert(
        0,
        '$title|$message',
      );
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                if (notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text(
                        'No notifications yet.',
                      ),
                    ),
                  )
                else
                  ...notifications.take(8).map(
                    (item) {
                      final parts = item.split('|');

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEDE7FF),
                          child: Icon(
                            Icons.notifications,
                            color: primary,
                          ),
                        ),
                        title: Text(
                          parts.first,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          parts.length > 1 ? parts[1] : '',
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSocialTaskDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Social Task',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Complete all tasks to unlock your 10 FAN reward.',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _taskRow(
                      icon: Icons.close,
                      title: 'Follow us',
                      completed: socialFollowCompleted,
                      onTap: () {
                        _completeFollow();
                        setModalState(() {});
                      },
                    ),

                    _taskRow(
                      icon: Icons.thumb_up,
                      title: 'Like our post',
                      completed: socialLikeCompleted,
                      onTap: () {
                        _completeLike();
                        setModalState(() {});
                      },
                    ),

                    _taskRow(
                      icon: Icons.comment,
                      title: 'Comment',
                      completed: socialCommentCompleted,
                      onTap: () {
                        _completeComment();
                        setModalState(() {});
                      },
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: socialTaskCompleted &&
                                !socialClaimed
                            ? () {
                                _claimSocialReward();
                                Navigator.pop(context);
                              }
                            : null,
                        icon: const Icon(Icons.card_giftcard),
                        label: Text(
                          socialClaimed
                              ? 'REWARD CLAIMED'
                              : 'CLAIM 10 FAN',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _taskRow({
    required IconData icon,
    required String title,
    required bool completed,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: completed
                ? Colors.green.shade100
                : const Color(0xFFEDE7FF),
            child: Icon(
              completed ? Icons.check : icon,
              color: completed ? Colors.green : primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: completed ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              completed ? 'DONE' : 'OPEN',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: [
            _buildHome(),
            _buildReferralPage(),
            _buildWalletPage(),
            _buildSettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHome() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(),
        ),

        SliverToBoxAdapter(
          child: _buildBalanceCard(),
        ),

        SliverToBoxAdapter(
          child: _buildMiningCard(),
        ),

        SliverToBoxAdapter(
          child: _buildAdsCard(),
        ),

        SliverToBoxAdapter(
          child: _buildDailyTaskCard(),
        ),

        SliverToBoxAdapter(
          child: _buildKycCard(),
        ),

        SliverToBoxAdapter(
          child: _buildReferralSummary(),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 25),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        12,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'AFAM',
                style: TextStyle(
                  color: primary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.token,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                children: [
                  IconButton(
                    onPressed: _openNotifications,
                    icon: const Icon(
                      Icons.notifications_none,
                      size: 34,
                      color: primary,
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        width: 10,
                        height: 10,
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

          const SizedBox(height: 2),

          const Text(
            'POWER FAN NETWORK',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),

          const Text(
            'Mine FAN. Earn More',
            style: TextStyle(
              color: primary,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4C1EC8),
            Color(0xFF29106F),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Flexible(
                      child: Text(
                        fanBalance.toStringAsFixed(4),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    const Text(
                      'FAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  '≈ \$0.00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          const Icon(
            Icons.person,
            color: Colors.white24,
            size: 90,
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    return _whiteCard(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                isMining
                    ? Icons.bolt
                    : Icons.pickaxe,
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'STATUS: ',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(
                            text: isMining
                                ? 'MINING'
                                : 'READY',
                            style: TextStyle(
                              color: isMining
                                  ? green
                                  : primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      isMining
                          ? 'Mining is active'
                          : 'Start mining to earn FAN',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
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
                  Icons.speed,
                  'MINING RATE',
                  '${miningRate.toStringAsFixed(2)} FAN/H',
                ),
              ),

              Container(
                width: 1,
                height: 55,
                color: Colors.black12,
              ),

              Expanded(
                child: _infoColumn(
                  Icons.access_time,
                  'SESSION',
                  isMining
                      ? 'ACTIVE'
                      : '00:00:00',
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed:
                  isMining ? _stopMining : _startMining,
              icon: Icon(
                isMining
                    ? Icons.stop_circle
                    : Icons.bolt,
              ),
              label: Text(
                isMining
                    ? 'STOP MINING'
                    : 'START MINING',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsCard() {
    final progress =
        adsWatchedToday / maxAdsPerDay;

    return _whiteCard(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(Icons.rocket_launch),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOST BY WATCHING ADS',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              ElevatedButton.icon(
                onPressed: null,
                icon: Icon(Icons.movie),
                label: Text('WATCH'),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Text(
                'Ads watched today: $adsWatchedToday / $maxAdsPerDay',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '+${adBoost.toStringAsFixed(1)} FAN/H',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: const Color(0xFFE8E5F4),
            color: primary,
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  adsWatchedToday < maxAdsPerDay
                      ? _watchAd
                      : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                adsWatchedToday < maxAdsPerDay
                    ? 'WATCH AD & GET +0.1 FAN/H'
                    : 'DAILY LIMIT REACHED',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(
                  color: primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskCard() {
    final completedCount =
        [
          socialFollowCompleted,
          socialLikeCompleted,
          socialCommentCompleted,
        ].where((item) => item).length;

    return _whiteCard(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIcon(
                Icons.task_alt,
                iconColor: Colors.green,
                background: const Color(0xFFE5F5EA),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Follow, Like & Comment',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete all and earn 10 FAN',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              _socialIcon('X'),
              const SizedBox(width: 8),
              _socialIcon('TG'),
              const SizedBox(width: 8),
              _socialIcon('IG'),
              const SizedBox(width: 8),
              _socialIcon('YT'),
              const Spacer(),
              Text(
                '$completedCount / 3',
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showSocialTaskDialog,
              icon: const Icon(
                Icons.card_giftcard,
              ),
              label: Text(
                socialClaimed
                    ? 'REWARD CLAIMED'
                    : 'FOLLOW & EARN 10 FAN',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(
                  color: primary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycCard() {
    return _whiteCard(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          _circleIcon(
            Icons.verified_user,
            iconColor: Colors.white,
            background: primary,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify your identity to secure your account',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          OutlinedButton(
            onPressed: () {
              _showMessage(
                'KYC verification page will be connected next.',
              );
            },
            child: const Text('COMPLETE KYC'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralSummary() {
    return _whiteCard(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'REFERRAL BOOST',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '$referralCount referrals • '
            '$activeReferrals active',
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '+${referralBoost.toStringAsFixed(2)} FAN/H',
            style: const TextStyle(
              color: primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _addReferral,
                  child: const Text(
                    'DEMO REFERRAL +5 FAN',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _notifyInactiveReferrals,
                icon: const Icon(
                  Icons.notifications_active,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 15),

          const Text(
            'REFERRAL',
            style: TextStyle(
              color: primary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          _whiteCard(
            child: Column(
              children: [
                const Icon(
                  Icons.people_alt,
                  color: primary,
                  size: 70,
                ),

                const SizedBox(height: 15),

                const Text(
                  'Invite friends and earn FAN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'New user gets 20 FAN.\n'
                  'Referrer gets 5 FAN.\n'
                  'Each active referral adds +0.02 FAN/H.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        'REFERRALS',
                        '$referralCount',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statBox(
                        'ACTIVE',
                        '$activeReferrals',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statBox(
                        'BOOST',
                        '+${referralBoost.toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _addReferral,
                    icon: const Icon(Icons.person_add),
                    label: const Text(
                      'INVITE FRIEND',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed:
                        _notifyInactiveReferrals,
                    icon: const Icon(
                      Icons.notifications_active,
                    ),
                    label: const Text(
                      'REMIND INACTIVE REFERRALS',
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

  Widget _buildWalletPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 15),

          const Text(
            'WALLET',
            style: TextStyle(
              color: primary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          _whiteCard(
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: primary,
                  size: 65,
                ),

                const SizedBox(height: 15),

                const Text(
                  'TOTAL FAN BALANCE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  fanBalance.toStringAsFixed(4),
                  style: const TextStyle(
                    color: primary,
                    fontSize: 35,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Wallet and withdrawal features will be connected to the secure backend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 15),

          const Text(
            'SETTINGS',
            style: TextStyle(
              color: primary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          _whiteCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.security,
                    color: primary,
                  ),
                  title: const Text(
                    'One Account • One Device',
                  ),
                  subtitle: const Text(
                    'Device security will be enforced by the backend.',
                  ),
                ),

                const Divider(),

                ListTile(
                  leading: const Icon(
                    Icons.verified_user,
                    color: primary,
                  ),
                  title: const Text(
                    'KYC Verification',
                  ),
                  subtitle: Text(
                    kycCompleted
                        ? 'Verified'
                        : 'Not completed',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    _showMessage(
                      'KYC page will be connected next.',
                    );
                  },
                ),

                const Divider(),

                ListTile(
                  leading: const Icon(
                    Icons.notifications,
                    color: primary,
                  ),
                  title: const Text(
                    'Notifications',
                  ),
                  subtitle: Text(
                    '${notifications.length} notification(s)',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: _openNotifications,
                ),

                const Divider(),

                ListTile(
                  leading: const Icon(
                    Icons.card_giftcard,
                    color: primary,
                  ),
                  title: const Text(
                    'New User Reward',
                  ),
                  subtitle: const Text(
                    '20 FAN welcome reward',
                  ),
                  trailing: newUserRewardClaimed
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                      : TextButton(
                          onPressed:
                              _claimNewUserReward,
                          child: const Text('CLAIM'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey.shade600,
      onTap: (index) {
        setState(() {
          selectedIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'HOME',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'REFERRAL',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'WALLET',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'SETTINGS',
        ),
      ],
    );
  }

  Widget _whiteCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _circleIcon(
    IconData icon, {
    Color iconColor = primary,
    Color background = const Color(0xFFEDE9FA),
  }) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 30,
      ),
    );
  }

  Widget _infoColumn(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: primary,
          size: 32,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: primary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _socialIcon(String text) {
    return Container(
      width: 43,
      height: 43,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statBox(
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F2FF),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
