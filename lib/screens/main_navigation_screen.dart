import 'package:flutter/material.dart';

import '../components/boost_ads_card.dart';
import '../components/daily_social_card.dart';
import '../components/kyc_card.dart';
import '../components/mining_card.dart';
import '../components/referral_card.dart';
import '../services/boost_ads_service.dart';
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
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  final MiningService _miningService =
      MiningService.instance;

  final ProfileService _profileService =
      ProfileService.instance;

  final ReferralService _referralService =
      ReferralService();

  final SocialTaskService _socialTaskService =
      SocialTaskService.instance;

  final KycService _kycService =
      KycService.instance;

  final BoostAdsService _boostAdsService =
      BoostAdsService.instance;

  int _currentIndex = 0;

  bool _loading = true;
  bool _actionLoading = false;

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

  List<DailySocialTask> _socialTasks = [];

  final List<String> _titles = const [
    'POWER FAN',
    'Referrals',
    'Wallet',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final profileFuture =
          _profileService.getProfile();

      final miningFuture =
          _miningService.getActiveMining();

      final rateFuture =
          _miningService.getUserMiningRate();

      final referralFuture =
          _referralService.getReferralInfo();

      final kycFuture =
          _kycService.getStatus();

      final socialFuture =
          _loadSocialTasksSafely();

      final results = await Future.wait<dynamic>([
        profileFuture,
        miningFuture,
        rateFuture,
        referralFuture,
        kycFuture,
        socialFuture,
      ]);

      if (!mounted) return;

      final profile = results[0] as ProfileData?;
      final mining =
          results[1] as Map<String, dynamic>;
      final rate =
          results[2] as Map<String, dynamic>;
      final referral =
          results[3] as ReferralInfo;
      final kyc =
          results[4] as KycStatus;
      final social =
          results[5] as List<DailySocialTask>;

      _fanBalance =
          _toDouble(
            profile?.fanBalance ??
                mining['fan_balance'],
          );

      _afamBalance =
          _toDouble(
            profile?.afamBalance ??
                mining['afam_balance'],
          );

      _miningRate =
          _extractMiningRate(
            rate,
            profile?.miningRate,
          );

      _isMining =
          _toBool(
            mining['mining_active'] ??
                mining['is_mining'] ??
                mining['active'] ??
                profile?.miningActive,
          );

      _miningStartedAt =
          _parseDate(
            mining['started_at'] ??
                mining['mining_started_at'] ??
                profile?.miningStartedAt,
          );

      _miningEndsAt =
          _parseDate(
            mining['ends_at'] ??
                mining['mining_ends_at'] ??
                profile?.miningEndsAt,
          );

      _activeReferrals =
          referral.activeReferrals;

      _checkInDays =
          kyc.checkInDays;

      _activeReferrals =
          kyc.activeReferrals;

      _faceVerified =
          kyc.faceVerified;

      _kyc1Verified =
          kyc.kyc1Verified;

      _kyc2Eligible =
          kyc.kyc2Eligible;

      _socialTasks =
          social;

      await _loadSessionAdCount();

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        _friendlyError(error),
      );
    }
  }

  Future<List<DailySocialTask>>
      _loadSocialTasksSafely() async {
    try {
      return await _socialTaskService
          .getDailyTasksForCard();
    } catch (_) {
      return <DailySocialTask>[];
    }
  }

  Future<void> _loadSessionAdCount() async {
    if (_miningStartedAt == null) {
      if (mounted) {
        setState(() {
          _adsWatched = 0;
        });
      } else {
        _adsWatched = 0;
      }

      return;
    }

    try {
      final count =
          await _miningService
              .getAdsWatchedForSession(
        startedAt: _miningStartedAt!,
      );

      if (!mounted) {
        _adsWatched = count;
        return;
      }

      setState(() {
        _adsWatched = count;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _adsWatched = 0;
      });
    }
  }

  double _extractMiningRate(
    Map<String, dynamic> data,
    double? profileRate,
  ) {
    final value =
        data['rate'] ??
        data['mining_rate'] ??
        data['value'] ??
        profileRate ??
        0.2;

    return _toDouble(value);
  }

  Future<void> _startMining() async {
    if (_actionLoading) return;

    if (_isMining) {
      _showMessage(
        'Your mining session is already active.',
      );
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      final result =
          await _miningService.startMining();

      if (!mounted) return;

      await _refreshMiningState(
        showLoading: false,
      );

      if (!mounted) return;

      setState(() {
        _actionLoading = false;
      });

      final message =
          _stringValue(
            result['message'],
          );

      _showMessage(
        message.isNotEmpty
            ? message
            : 'Mining started for 24 hours.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _actionLoading = false;
      });

      _showMessage(
        _friendlyError(error),
      );
    }
  }

  Future<void> _claimMining() async {
    if (_actionLoading) return;

    if (!_isMining) {
      _showMessage(
        'There is no active mining session.',
      );
      return;
    }

    if (_miningEndsAt != null &&
        DateTime.now().isBefore(
          _miningEndsAt!,
        )) {
      _showMessage(
        'Your mining session is still active.',
      );
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      final result =
          await _miningService.claimMining();

      if (!mounted) return;

      await _refreshMiningState(
        showLoading: false,
      );

      if (!mounted) return;

      setState(() {
        _actionLoading = false;
      });

      final message =
          _stringValue(
            result['message'],
          );

      _showMessage(
        message.isNotEmpty
            ? message
            : 'Mining reward claimed successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _actionLoading = false;
      });

      _showMessage(
        _friendlyError(error),
      );
    }
  }

  Future<void> _watchAd() async {
    if (_actionLoading) return;

    if (!_isMining) {
      _showMessage(
        'Start mining before watching rewarded ads.',
      );
      return;
    }

    if (_adsWatched >= 7) {
      _showMessage(
        'You have reached the 7 ads limit for this session.',
      );
      return;
    }

    if (_miningStartedAt == null) {
      _showMessage(
        'Mining session information is not available yet.',
      );
      return;
    }

    setState(() {
      _actionLoading = true;
    });

    try {
      final watched =
          await _boostAdsService
              .watchAdAndRecord();

      if (!mounted) return;

      if (watched) {
        await _loadSessionAdCount();
        await _refreshMiningRate();

        if (!mounted) return;

        _showMessage(
          'Ad completed. Mining rate increased by +0.10 FAN/H.',
        );
      }

      if (!mounted) return;

      setState(() {
        _actionLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _actionLoading = false;
      });

      _showMessage(
        _friendlyError(error),
      );
    }
  }

  Future<void> _refreshMiningState({
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final profile =
          await _profileService.getProfile();

      final mining =
          await _miningService.getActiveMining();

      final rate =
          await _miningService.getUserMiningRate();

      if (!mounted) return;

      setState(() {
        _fanBalance =
            _toDouble(
              profile?.fanBalance ??
                  mining['fan_balance'],
            );

        _afamBalance =
            _toDouble(
              profile?.afamBalance ??
                  mining['afam_balance'],
            );

        _miningRate =
            _extractMiningRate(
              rate,
              profile?.miningRate,
            );

        _isMining =
            _toBool(
              mining['mining_active'] ??
                  mining['is_mining'] ??
                  mining['active'] ??
                  profile?.miningActive,
            );

        _miningStartedAt =
            _parseDate(
              mining['started_at'] ??
                  mining['mining_started_at'] ??
                  profile?.miningStartedAt,
            );

        _miningEndsAt =
            _parseDate(
              mining['ends_at'] ??
                  mining['mining_ends_at'] ??
                  profile?.miningEndsAt,
            );
      });

      await _loadSessionAdCount();

      if (showLoading && mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;

      if (showLoading) {
        setState(() {
          _loading = false;
        });
      }

      throw Exception(
        _friendlyError(error),
      );
    }
  }

  Future<void> _refreshMiningRate() async {
    try {
      final rate =
          await _miningService.getUserMiningRate();

      if (!mounted) return;

      setState(() {
        _miningRate =
            _extractMiningRate(
          rate,
          null,
        );
      });
    } catch (_) {
      // Keep the existing displayed rate if the
      // refresh fails temporarily.
    }
  }

  Future<void> _refreshReferralAndKyc() async {
    try {
      final referral =
          await _referralService
              .getReferralInfo();

      final kyc =
          await _kycService.getStatus();

      if (!mounted) return;

      setState(() {
        _activeReferrals =
            referral.activeReferrals;

        _checkInDays =
            kyc.checkInDays;

        _faceVerified =
            kyc.faceVerified;

        _kyc1Verified =
            kyc.kyc1Verified;

        _kyc2Eligible =
            kyc.kyc2Eligible;
      });
    } catch (_) {
      // Preserve existing values when a secondary
      // refresh is temporarily unavailable.
    }
  }

  Future<void> _refreshEverything() async {
    try {
      await _loadAllData();
    } catch (_) {
      // _loadAllData handles its own UI errors.
    }
  }

  Future<void> _completeSocialTask(
    DailySocialTask task,
  ) async {
    try {
      final serviceTask =
          await _socialTaskService
              .findTask(task.id);

      if (serviceTask == null) {
        _showMessage(
          'This social task is no longer available.',
        );
        return;
      }

      final result =
          await _socialTaskService
              .verifyAndClaim(
        taskId: serviceTask.id,
      );

      if (!mounted) return;

      if (result.success) {
        await _refreshMiningState(
          showLoading: false,
        );

        await _loadAllData();

        if (!mounted) return;

        _showMessage(
          result.message.isNotEmpty
              ? result.message
              : '+${result.rewardFan.toStringAsFixed(0)} FAN reward claimed.',
        );
      } else {
        _showMessage(
          result.message.isNotEmpty
              ? result.message
              : 'The social task has not been fully verified yet.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(error),
      );
    }
  }

  Future<void> _faceVerification() async {
    try {
      final result =
          await _kycService
              .startFaceVerification();

      if (!mounted) return;

      final message =
          _stringValue(
            result['message'],
          );

      _showMessage(
        message.isNotEmpty
            ? message
            : 'Face verification will be available soon.',
      );

      await _refreshReferralAndKyc();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(error),
      );
    }
  }

  Future<void> _pingReferral(
    ReferralItem referral,
  ) async {
    // The current referral service does not expose
    // a trusted "ping referral" RPC yet.
    //
    // Therefore this button only informs the user
    // that the reminder feature is pending its
    // notification backend instead of pretending
    // that a server notification was sent.
    _showMessage(
      'Mining reminder will be available with notifications.',
    );
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _refreshEverything,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          30,
        ),
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 16),

          MiningCard(
            fanBalance: _fanBalance,
            miningRate: _miningRate,
            isMining: _isMining,
            startedAt: _miningStartedAt,
            endsAt: _miningEndsAt,
            adsWatched: _adsWatched,
            maxAds: 7,
            onStartMining:
                _actionLoading
                    ? null
                    : _startMining,
            onClaimMining:
                _actionLoading
                    ? null
                    : _claimMining,
            onWatchAd:
                _actionLoading
                    ? null
                    : _watchAd,
          ),

          const SizedBox(height: 16),

          BoostAdsCard(
            isMining: _isMining,
            adsWatched: _adsWatched,
            maxAds: 7,
            onWatchAd:
                _actionLoading
                    ? null
                    : _watchAd,
          ),

          const SizedBox(height: 16),

          DailySocialCard(
            tasks: _socialTasks,
            onClaim:
                _completeSocialTask,
          ),

          const SizedBox(height: 16),

          KycCard(
            checkInDays: _checkInDays,
            activeReferrals:
                _activeReferrals,
            faceVerified:
                _faceVerified,
            kyc1Verified:
                _kyc1Verified,
            kyc2Eligible:
                _kyc2Eligible,
            onFaceVerification:
                _faceVerification,
          ),

          const SizedBox(height: 16),

          _buildBalanceSummary(),

          const SizedBox(height: 16),

          _buildQuickReferral(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color:
                const Color(0xFF3B159B),
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'POWER FAN NETWORK',
                style: TextStyle(
                  color:
                      Color(0xFF241064),
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ProfileScreen(),
              ),
            );
          },
          icon: const Icon(
            Icons.person_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSummary() {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Balances',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _balanceItem(
                  title: 'FAN',
                  value:
                      _fanBalance
                          .toStringAsFixed(4),
                  icon:
                      Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _balanceItem(
                  title: 'AFAM',
                  value:
                      _afamBalance
                          .toStringAsFixed(4),
                  icon: Icons
                      .account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF8F8FC),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                const Color(0xFF3B159B),
            size: 23,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
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

  Widget _buildQuickReferral() {
    return ReferralCard(
      referrals:
          const <ReferralItem>[],
      activeReferrals:
          _activeReferrals,
      onPing: _pingReferral,
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHome();

      case 1:
        return const ReferralScreen();

      case 2:
        return WalletScreen(
          fanBalance: _fanBalance,
          afamBalance: _afamBalance,
        );

      case 3:
        return const SettingsScreen();

      default:
        return _buildHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xFFF8F8FC),
        surfaceTintColor:
            Colors.transparent,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color:
                Color(0xFF241064),
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _buildCurrentPage(),
      bottomNavigationBar:
          NavigationBar(
        backgroundColor:
            Colors.white,
        elevation: 8,
        selectedIndex:
            _currentIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.people_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.people_rounded,
            ),
            label: 'Referral',
          ),
          NavigationDestination(
            icon: Icon(
              Icons
                  .account_balance_wallet_outlined,
            ),
            selectedIcon: Icon(
              Icons
                  .account_balance_wallet_rounded,
            ),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),
            selectedIcon: Icon(
              Icons.settings_rounded,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  String _friendlyError(Object error) {
    final text =
        error.toString().trim();

    if (text.startsWith(
      'Exception: ',
    )) {
      return text.substring(11).trim();
    }

    if (text.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    return text;
  }

  static String _stringValue(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }

  static double _toDouble(
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

  static bool _toBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value?.toString()
            .toLowerCase()
            .trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}
