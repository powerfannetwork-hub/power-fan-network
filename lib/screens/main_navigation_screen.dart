import 'package:flutter/material.dart';

import '../components/boost/boost_ads_card.dart';
import '../components/daily_social_card.dart';
import '../components/kyc_card.dart';
import '../components/mining_card.dart';
import '../components/referral_card.dart';
import '../services/kyc_service.dart';
import '../services/mining_service.dart';
import '../services/profile_service.dart';
import '../services/referral_service.dart';
import '../services/social_task_service.dart';
import 'profile_screen.dart';
import 'referral_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
  });

  @override
  State<MainNavigationScreen> =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  final MiningService _miningService =
      MiningService.instance;

  final SocialTaskService _socialTaskService =
      SocialTaskService.instance;

  final ReferralService _referralService =
      ReferralService();

  final ProfileService _profileService =
      ProfileService();

  final KycService _kycService =
      KycService();

  int _currentIndex = 0;

  double _fanBalance = 0.0;
  double _afamBalance = 0.0;
  double _miningRate = 0.2;

  bool _isMining = false;

  DateTime? _miningStartedAt;
  DateTime? _miningEndsAt;

  int _adsWatched = 0;

  int _checkInDays = 0;
  int _activeReferrals = 0;

  bool _faceVerified = false;
  bool _kyc1Verified = false;
  bool _kyc2Eligible = false;

  bool _loading = true;
  bool _refreshing = false;

  List<ReferralItem> _referrals =
      <ReferralItem>[];

  List<DailySocialTask> _socialTasks =
      <DailySocialTask>[];

  final List<String> _titles = const [
    'POWER FAN',
    'Referrals',
    'Wallet',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    await _loadData();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait<dynamic>([
        _miningService.getProfile(),
        _miningService.getActiveMining(),
        _miningService.getUserMiningRate(),
        _referralService.getReferralInfo(),
        _kycService.getStatus(),
        _socialTaskService.getDailyTasksForCard(),
        _profileService.getProfile(),
      ]);

      if (!mounted) return;

      final balanceData =
          results[0] as Map<String, dynamic>;

      final miningData =
          results[1] as Map<String, dynamic>;

      final rateData = results[2]; // GYARA 1: Na cire `as Map<String, dynamic>`

      final referralInfo =
          results[3] as ReferralInfo;

      final kycStatus =
          results[4] as KycStatus;

      final socialTasks =
          results[5] as List<DailySocialTask>;

      final miningStarted =
          _parseDateTime(
        miningData['started_at']??
            miningData['mining_started_at']??
            miningData['startedAt'],
      );

      final miningEnds =
          _parseDateTime(
        miningData
