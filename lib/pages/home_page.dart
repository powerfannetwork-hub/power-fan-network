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
  static const Color darkPurple = Color(0xFF24106F);
  static const Color green = Color(0xFF199B59);

  SharedPreferences? _prefs;
  Timer? _timer;

  double _balance = 20.0;

  // Mining
  bool _isMining = false;
  DateTime? _miningStarted;
  DateTime? _miningEnds;

  // Base mining rate
  double _baseMiningRate = 0.2;

  // Ads
  int _adsWatchedToday = 0;
  static const int _maxAdsPerDay = 7;
  static const double _adBoost = 0.1;

  // Daily social task
  bool _socialFollow = false;
  bool _socialLike = false;
  bool _socialComment = false;
  bool _socialClaimed = false;

  static const double _socialReward = 10.0;

  // Referrals
  int _referralCount = 0;
  int _activeReferrals = 0;

  // Notification
  final List<String> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();

    final today = _todayKey();
    final savedAdsDate = _prefs!.getString('ads_date');

    if (savedAdsDate != today) {
      await _prefs!.setInt('ads_watched_today', 0);
      await _prefs!.setString('ads_date', today);
    }

    final socialDate = _prefs!.getString('social_task_date');

    if (socialDate != today) {
      await _prefs!.setBool('social_follow', false);
      await _prefs!.setBool('social_like', false);
      await _prefs!.setBool('social_comment', false);
      await _prefs!.setBool('social_claimed', false);
      await _prefs!.setString('social_task_date', today);
    }

    setState(() {
      _balance = _prefs!.getDouble('fan_balance') ?? 20.0;

      _isMining = _prefs!.getBool('is_mining') ?? false;

      final start = _prefs!.getString('mining_start');
      final end = _prefs!.getString('mining_end');

      _miningStarted =
          start == null ? null : DateTime.tryParse(start);

      _miningEnds =
          end == null ? null : DateTime.tryParse(end);

      _adsWatchedToday =
          _prefs!.getInt('ads_watched_today') ?? 0;

      _socialFollow =
          _prefs!.getBool('social_follow') ?? false;

      _socialLike =
          _prefs!.getBool('social_like') ?? false;

      _socialComment =
          _prefs!.getBool('social_comment') ?? false;

      _socialClaimed =
          _prefs!.getBool('social_claimed') ?? false;

      _referralCount =
          _prefs!.getInt('referral_count') ?? 0;

      _activeReferrals =
          _prefs!.getInt('active_referrals') ?? 0;
    });

    _startTimer();

    _checkMiningStatus();
  }

  String _todayKey() {
    final now = DateTime.now();

    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  double get _miningRate {
    return _baseMiningRate +
        (_adsWatchedToday * _adBoost) +
        (_activeReferrals * 0.02);
  }

  double get _sessionEarned {
    if (!_isMining || _miningStarted == null) {
      return 0;
    }

    final now = DateTime.now();

    final end = _miningEnds ?? now;

    final current = now.isAfter(end) ? end : now;

    final seconds =
        current.difference(_miningStarted!).inSeconds;

    if (seconds <= 0) {
      return 0;
    }

    return (seconds / 3600) * _miningRate;
  }

  Duration get _remainingTime {
    if (!_isMining || _miningEnds == null) {
      return Duration.zero;
    }

    final remaining =
        _miningEnds!.difference(DateTime.now());

    return remaining.isNegative
        ? Duration.zero
        : remaining;
  }

  Future<void> _save() async {
    if (_prefs == null) return;

    await _prefs!.setDouble('fan_balance', _balance);

    await _prefs!.setBool('is_mining', _isMining);

    if (_miningStarted != null) {
      await _prefs!.setString(
        'mining_start',
        _miningStarted!.toIso8601String(),
      );
    } else {
      await _prefs!.remove('mining_start');
    }

    if (_miningEnds != null) {
      await _prefs!.setString(
        'mining_end',
        _miningEnds!.toIso8601String(),
      );
    } else {
      await _prefs!.remove('mining_end');
    }

    await _prefs!.setInt(
      'ads_watched_today',
      _adsWatchedToday,
    );

    await _prefs!.setBool(
      'social_follow',
      _socialFollow,
    );

    await _prefs!.setBool(
      'social_like',
      _socialLike,
    );

    await _prefs!.setBool(
      'social_comment',
      _socialComment,
    );

    await _prefs!.setBool(
      'social_claimed',
      _socialClaimed,
    );

    await _prefs!.setInt(
      'referral_count',
      _referralCount,
    );

    await _prefs!.setInt(
      'active_referrals',
      _activeReferrals,
    );
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        _checkMiningStatus();

        setState(() {});
      },
    );
  }

  Future<void> _checkMiningStatus() async {
    if (!_isMining || _miningEnds == null) {
      return;
    }

    if (DateTime.now().isAfter(_miningEnds!)) {
      final earned = _sessionEarned;

      _balance += earned;

      _isMining = false;
      _miningStarted = null;
      _miningEnds = null;

      _notifications.insert(
        0,
        'Mining session completed. ${earned.toStringAsFixed(4)} FAN added.',
      );

      await _save();

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _startMining() async {
    if (_isMining) {
      return;
    }

    final now = DateTime.now();

    setState(() {
      _isMining = true;
      _miningStarted = now;
      _miningEnds = now.add(
        const Duration(hours: 24),
      );

      _notifications.insert(
        0,
        'Mining started at ${_formatTime(now)}.',
      );
    });

    await _save();
  }

  Future<void> _watchAd() async {
    if (_adsWatchedToday >= _maxAdsPerDay) {
      _showMessage(
        'You have reached today\'s maximum of 7 ads.',
      );
      return;
    }

    // Wannan wurin za mu haɗa real AdMob reward daga baya.
    //
    // Bayan real rewarded ad ya kammala:
    // _adsWatchedToday++;
    // sannan mining rate ya ƙaru da 0.1 FAN/H.

    setState(() {
      _adsWatchedToday++;

      _notifications.insert(
        0,
        'Ad reward received: +0.1 FAN/H.',
      );
    });

    await _save();

    _showMessage(
      'Ad reward added. Mining rate is now '
      '${_miningRate.toStringAsFixed(2)} FAN/H.',
    );
  }

  bool get _socialTaskComplete {
    return _socialFollow &&
        _socialLike &&
        _socialComment;
  }

  Future<void> _claimSocialReward() async {
    if (_socialClaimed) {
      _showMessage(
        'Daily social reward already claimed.',
      );
      return;
    }

    if (!_socialTaskComplete) {
      _showMessage(
        'You must complete Follow, Like and Comment first.',
      );
      return;
    }

    setState(() {
      _balance += _socialReward;
      _socialClaimed = true;

      _notifications.insert(
        0,
        '+10 FAN social task reward claimed.',
      );
    });

    await _save();

    _showMessage(
      '+10 FAN added to your balance.',
    );
  }

  Future<void> _setSocialTask(
    String task,
    bool value,
  ) async {
    setState(() {
      if (task == 'follow') {
        _socialFollow = value;
      }

      if (task == 'like') {
        _socialLike = value;
      }

      if (task == 'comment') {
        _socialComment = value;
      }
    });

    await _save();
  }

  double _referralMiningBonus() {
    return _activeReferrals * 0.02;
  }

  Future<void> _sendReferralReminder() async {
    if (_referralCount == 0) {
      _showMessage(
        'You do not have referrals yet.',
      );
      return;
    }

    final inactive =
        _referralCount - _activeReferrals;

    if (inactive <= 0) {
      _showMessage(
        'All your referrals are currently active.',
      );
      return;
    }

    setState(() {
      _notifications.insert(
        0,
        'Mining reminder sent to $inactive inactive referral(s).',
      );
    });

    _showMessage(
      'Reminder sent to inactive referrals.',
    );
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour.toString().padLeft(2, '0');

    final minute =
        time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDuration(Duration duration) {
    final hours =
        duration.inHours.toString().padLeft(2, '0');

    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

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
        ),
      );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Text(
                            'No notifications yet.',
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              _notifications.length,
                          itemBuilder:
                              (context, index) {
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor:
                                    Color(0xFFEDE7F6),
                                child: Icon(
                                  Icons.notifications,
                                  color: primary,
                                ),
                              ),
                              title: Text(
                                _notifications[index],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconCircle(
    IconData icon, {
    Color color = primary,
    Color background = const Color(0xFFF0EDFA),
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
        color: color,
        size: 30,
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        12,
        24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF35129B),
            Color(0xFF4A18C9),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.orange,
                      size: 48,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${_balance.toStringAsFixed(4)} FAN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '≈ \$${(_balance * 0.01).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.diamond,
            color: Colors.deepPurpleAccent,
            size: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildMiningCard() {
    final remaining = _remainingTime;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                _isMining
                    ? Icons.bolt
                    : Icons.handyman,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                        ),
                        children: [
                          const TextSpan(
                            text: 'STATUS: ',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: _isMining
                                ? 'MINING'
                                : 'READY',
                            style: TextStyle(
                              color: _isMining
                                  ? green
                                  : green,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _isMining
                          ? 'Mining is active'
                          : 'Start mining to earn FAN',
                      style: const TextStyle(
                        color: Color(0xFF45415B),
                        fontSize: 15,
                      ),
                    ),
                  ],
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
                  '${_miningRate.toStringAsFixed(2)} FAN/H',
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
                  _isMining
                      ? _formatDuration(remaining)
                      : '00:00:00 / 24:00:00',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed:
                  _isMining ? null : _startMining,
              icon: Icon(
                _isMining
                    ? Icons.bolt
                    : Icons.hardware,
              ),
              label: Text(
                _isMining
                    ? 'MINING ACTIVE'
                    : 'START MINING',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade400,
                shape: RoundedRectangleBorder(
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

  Widget _statItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Icon(
          icon,
          color: primary,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdsCard() {
    final progress =
        _adsWatchedToday / _maxAdsPerDay;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.rocket_launch,
                color: Colors.deepOrange,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Each ad adds +0.1 FAN/H',
                      style: TextStyle(
                        color: Color(0xFF45415B),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: null,
                icon: Icon(Icons.movie),
                label: Text('WATCH AD'),
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStatePropertyAll(primary),
                  foregroundColor:
                      WidgetStatePropertyAll(
                    Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ads watched today: '
                  '$_adsWatchedToday / $_maxAdsPerDay',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '+${(_adsWatchedToday * _adBoost).toStringAsFixed(1)} FAN/H',
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _adsWatchedToday >= _maxAdsPerDay
                      ? null
                      : _watchAd,
              icon: const Icon(
                Icons.play_circle,
              ),
              label: Text(
                _adsWatchedToday >= _maxAdsPerDay
                    ? 'DAILY LIMIT REACHED'
                    : 'TEST REWARD AD',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard() {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.task_alt,
                color: Colors.green.shade800,
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
                        color: Color(0xFF45415B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+10 FAN',
                style: TextStyle(
                  color: green,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _taskCheck(
            'Follow official social media',
            _socialFollow,
            () => _setSocialTask(
              'follow',
              !_socialFollow,
            ),
          ),
          _taskCheck(
            'Like official post',
            _socialLike,
            () => _setSocialTask(
              'like',
              !_socialLike,
            ),
          ),
          _taskCheck(
            'Comment on official post',
            _socialComment,
            () => _setSocialTask(
              'comment',
              !_socialComment,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _socialTaskComplete &&
                      !_socialClaimed
                  ? _claimSocialReward
                  : null,
              icon: const Icon(Icons.card_giftcard),
              label: Text(
                _socialClaimed
                    ? 'REWARD CLAIMED'
                    : 'VERIFY & CLAIM 10 FAN',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (!_socialTaskComplete &&
              !_socialClaimed)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Complete all 3 tasks before claiming.',
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

  Widget _taskCheck(
    String title,
    bool checked,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        checked
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        color: checked ? green : Colors.grey,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: checked
          ? const Text(
              'DONE',
              style: TextStyle(
                color: green,
                fontWeight: FontWeight.bold,
              ),
            )
          : const Text(
              'PENDING',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
    );
  }

  Widget _buildReferralCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconCircle(
                Icons.people,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFERRAL REWARD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Invite users and earn rewards',
                      style: TextStyle(
                        color: Color(0xFF45415B),
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
                  'REFERRALS',
                  '$_referralCount',
                ),
              ),
              Expanded(
                child: _referralStat(
                  'ACTIVE',
                  '$_activeReferrals',
                ),
              ),
              Expanded(
                child: _referralStat(
                  'BONUS RATE',
                  '+${_referralMiningBonus().toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'New user: +20 FAN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inviter: +5 FAN',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active referral bonus: +0.02 FAN/H each',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendReferralReminder,
              icon: const Icon(Icons.notifications_active),
              label: const Text(
                'REMIND INACTIVE REFERRALS',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referralStat(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildKycCard() {
    return _card(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      child: Row(
        children: [
          _iconCircle(
            Icons.verified_user,
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verify your identity to secure your account',
                  style: TextStyle(
                    color: Color(0xFF45415B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              _showMessage(
                'KYC module will be connected to the backend.',
              );
            },
            child: const Text('COMPLETE KYC'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    30,
                  ),
                  children: [
                    _buildBalanceHeader(),
                    const SizedBox(height: 16),
                    _buildMiningCard(),
                    const SizedBox(height: 16),
                    _buildAdsCard(),
                    const SizedBox(height: 16),
                    _buildSocialCard(),
                    const SizedBox(height: 16),
                    _buildReferralCard(),
                    const SizedBox(height: 16),
                    _buildKycCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                if (_notifications.isNotEmpty)
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
}
