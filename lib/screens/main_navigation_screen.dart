import 'package:flutter/material.dart';

import '../components/boost_ads_card.dart';
import '../components/daily_social_card.dart';
import '../components/kyc_card.dart';
import '../components/mining_card.dart';
import '../components/referral_card.dart';
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

  void _loadInitialData() {
    // Real account data will be loaded here
    // from the application services.
  }

  void _startMining() {
    setState(() {
      _isMining = true;
      _miningStartedAt = DateTime.now();
      _miningEndsAt = DateTime.now().add(
        const Duration(hours: 24),
      );
      _adsWatched = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mining started for 24 hours.',
        ),
      ),
    );
  }

  void _claimMining() {
    if (!_isMining) return;

    if (_miningEndsAt != null &&
        DateTime.now().isBefore(_miningEndsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your mining session is still active.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isMining = false;
      _miningStartedAt = null;
      _miningEndsAt = null;
      _adsWatched = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mining reward claimed successfully.',
        ),
      ),
    );
  }

  void _watchAd() {
    if (!_isMining) return;

    if (_adsWatched >= 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have reached the 7 ads limit for this session.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _adsWatched++;
      _miningRate += 0.1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ad completed. Mining rate increased by '
          '+0.10 FAN/H.',
        ),
      ),
    );
  }

  void _completeSocialTask(
    DailySocialTask task,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${task.platform} task completed.',
        ),
      ),
    );
  }

  void _faceVerification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Face Verification will be available soon.',
        ),
      ),
    );
  }

  void _pingReferral(
    ReferralItem referral,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mining reminder sent to ${referral.name}.',
        ),
      ),
    );
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) return;

        setState(() {});
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
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
            onStartMining: _startMining,
            onClaimMining: _claimMining,
            onWatchAd: _watchAd,
          ),

          const SizedBox(height: 16),

          BoostAdsCard(
            isMining: _isMining,
            adsWatched: _adsWatched,
            maxAds: 7,
            onWatchAd: _watchAd,
          ),

          const SizedBox(height: 16),

          DailySocialCard(
            onClaim: _completeSocialTask,
          ),

          const SizedBox(height: 16),

          KycCard(
            checkInDays: _checkInDays,
            activeReferrals: _activeReferrals,
            faceVerified: _faceVerified,
            kyc1Verified: _kyc1Verified,
            kyc2Eligible: _kyc2Eligible,
            onFaceVerification: _faceVerification,
          ),

          const SizedBox(height: 16),

          _buildBalanceSummary(),

          const SizedBox(height: 16),

          _buildQuickReferral(),

          const SizedBox(height: 10),
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
            color: const Color(0xFF3B159B),
            borderRadius: BorderRadius.circular(16),
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
                  color: Color(0xFF241064),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
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
                builder: (_) => const ProfileScreen(),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Balances',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _balanceItem(
                  title: 'FAN',
                  value:
                      _fanBalance.toStringAsFixed(4),
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _balanceItem(
                  title: 'AFAM',
                  value:
                      _afamBalance.toStringAsFixed(4),
                  icon: Icons.account_balance_wallet_outlined,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF3B159B),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
      referrals: const [],
      activeReferrals: _activeReferrals,
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
        surfaceTintColor: Colors.transparent,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            color: Color(0xFF241064),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: _buildCurrentPage(),

      bottomNavigationBar:
          NavigationBar(
        backgroundColor: Colors.white,
        elevation: 8,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
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
              Icons.account_balance_wallet_outlined,
            ),
            selectedIcon: Icon(
              Icons.account_balance_wallet_rounded,
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
}
