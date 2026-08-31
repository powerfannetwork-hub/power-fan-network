import 'package:flutter/material.dart';

import '../services/api_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeTab(),
    ReferralTab(),
    WalletTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Referral',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.account_balance_wallet_outlined,
            ),
            selectedIcon: Icon(
              Icons.account_balance_wallet,
            ),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME TAB
// ============================================================

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = true;
  bool _starting = false;
  bool _claiming = false;
  bool _watchingAd = false;

  Map<String, dynamic>? _dashboard;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.dashboard();

      if (!mounted) return;

      setState(() {
        _dashboard = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _startMining() async {
    if (_starting) return;

    setState(() {
      _starting = true;
    });

    try {
      final result = await ApiService.startMining();

      if (!mounted) return;

      _showMessage(
        result['message']?.toString() ??
            'Mining started successfully.',
      );

      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _errorText(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _claimMining() async {
    if (_claiming) return;

    setState(() {
      _claiming = true;
    });

    try {
      final result = await ApiService.claimMining();

      if (!mounted) return;

      _showMessage(
        result['message']?.toString() ??
            'Mining reward claimed.',
      );

      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _errorText(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _claiming = false;
        });
      }
    }
  }

  Future<void> _watchAd() async {
    if (_watchingAd) return;

    setState(() {
      _watchingAd = true;
    });

    try {
      final result = await ApiService.watchAd();

      if (!mounted) return;

      _showMessage(
        result['message']?.toString() ??
            'Ad reward applied.',
      );

      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _errorText(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _watchingAd = false;
        });
      }
    }
  }

  String _errorText(dynamic error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B159B),
          ),
        ),
      );
    }

    if (_error != null && _dashboard == null) {
      return SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 120),
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              const Text(
                'Could not connect to the backend.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: const Text('TRY AGAIN'),
              ),
            ],
          ),
        ),
      );
    }

    final dashboard =
        _dashboard ?? <String, dynamic>{};

    final user =
        dashboard['user'] is Map
            ? Map<String, dynamic>.from(
                dashboard['user'],
              )
            : <String, dynamic>{};

    final rules =
        dashboard['rules'] is Map
            ? Map<String, dynamic>.from(
                dashboard['rules'],
              )
            : <String, dynamic>{};

    final fanBalance =
        _toDouble(user['fanBalance']);

    final afamBalance =
        _toDouble(user['afamBalance']);

    final miningRate =
        _toDouble(
      user['miningRate'],
      fallback: 0.2,
    );

    final activeReferrals =
        _toInt(user['activeReferrals']);

    final dailyAds =
        _toInt(user['dailyAdsWatched']);

    final adBoost =
        _toDouble(user['adBoost']);

    final miningActive =
        user['miningActive'] == true;

    final maxAds =
        _toInt(
      rules['maxDailyAds'],
      fallback: 7,
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            30,
          ),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POWER FAN NETWORK',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF241064),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mining Dashboard',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor:
                      const Color(0xFF3B159B),
                  child: Text(
                    _firstLetter(user['name']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ==================================================
            // FAN BALANCE CARD
            // ==================================================

            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B159B),
                    Color(0xFF241064),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    color: Colors.black.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'FAN Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${fanBalance.toStringAsFixed(4)} FAN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _balanceMiniCard(
                          'AFAM',
                          afamBalance.toStringAsFixed(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _balanceMiniCard(
                          'Mining Rate',
                          '${miningRate.toStringAsFixed(2)} FAN/H',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // MINING SESSION
            // ==================================================

            _sectionCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        color: Color(0xFF3B159B),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Mining Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: miningActive
                              ? Colors.green.withValues(
                                  alpha: 0.12,
                                )
                              : Colors.grey.withValues(
                                  alpha: 0.12,
                                ),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          miningActive
                              ? 'ACTIVE'
                              : 'STOPPED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: miningActive
                                ? Colors.green
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _statItem(
                          'Rate',
                          '${miningRate.toStringAsFixed(2)} FAN/H',
                        ),
                      ),
                      Expanded(
                        child: _statItem(
                          'Referrals',
                          '$activeReferrals',
                        ),
                      ),
                      Expanded(
                        child: _statItem(
                          'Ad Boost',
                          '+${adBoost.toStringAsFixed(1)}',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: miningActive
                          ? (_claiming
                              ? null
                              : _claimMining)
                          : (_starting
                              ? null
                              : _startMining),
                      icon: _starting || _claiming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              miningActive
                                  ? Icons
                                      .check_circle_outline
                                  : Icons
                                      .play_arrow_rounded,
                            ),
                      label: Text(
                        _starting
                            ? 'STARTING...'
                            : _claiming
                                ? 'CLAIMING...'
                                : miningActive
                                    ? 'CLAIM MINING'
                                    : 'START MINING',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF3B159B),
                        foregroundColor: Colors.white,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // AD BOOST
            // ==================================================

            _sectionCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              Colors.orange.withValues(
                            alpha: 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons
                              .ondemand_video_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mining Boost',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '+0.1 FAN/H per completed ad',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '$dailyAds / $maxAds ads watched today',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 9),

                  LinearProgressIndicator(
                    value: maxAds > 0
                        ? (dailyAds / maxAds)
                            .clamp(0.0, 1.0)
                        : 0,
                    minHeight: 7,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed:
                          dailyAds >= maxAds ||
                                  _watchingAd
                              ? null
                              : _watchAd,
                      icon: _watchingAd
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .play_circle_outline,
                            ),
                      label: Text(
                        dailyAds >= maxAds
                            ? 'DAILY LIMIT REACHED'
                            : _watchingAd
                                ? 'PROCESSING...'
                                : 'APPLY AD REWARD',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // REFERRAL SUMMARY
            // ==================================================

            _sectionCard(
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF3B159B)
                              .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF3B159B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Referrals',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$activeReferrals active referral${activeReferrals == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${(activeReferrals * 0.02).toStringAsFixed(2)} FAN/H',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF159B61),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            const Center(
              child: Text(
                'Pull down to refresh your balance',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceMiniCard(
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }

  Widget _statItem(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  int _toInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  String _firstLetter(dynamic value) {
    final name =
        value?.toString().trim() ?? '';

    if (name.isEmpty) {
      return 'P';
    }

    return name.substring(0, 1).toUpperCase();
  }
}

// ============================================================
// REFERRAL TAB
// ============================================================

class ReferralTab extends StatefulWidget {
  const ReferralTab({super.key});

  @override
  State<ReferralTab> createState() =>
      _ReferralTabState();
}

class _ReferralTabState
    extends State<ReferralTab> {
  bool _loading = true;
  String? _error;

  String _referralCode = '';
  int _activeReferrals = 0;
  double _miningRate = 0.2;

  List<dynamic> _referrals = [];

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await ApiService.getReferrals();

      if (!mounted) return;

      final referrals =
          result['referrals'];

      setState(() {
        _loading = false;

        _referralCode =
            result['referralCode']
                    ?.toString() ??
                '';

        _activeReferrals =
            _toInt(
          result['activeReferrals'],
        );

        _miningRate =
            _toDouble(
          result['miningRate'],
          fallback: 0.2,
        );

        _referrals =
            referrals is List
                ? referrals
                : [];
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            )
            .trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B159B),
          ),
        ),
      );
    }

    if (_error != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.grey,
                ),
                const SizedBox(height: 15),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadReferrals,
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadReferrals,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Referral',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xFF241064),
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Invite users and increase your mining rate.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // REFERRAL CODE
            // ==================================================

            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3B159B),
                    Color(0xFF241064),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Text(
                    'YOUR REFERRAL CODE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _referralCode.isEmpty
                        ? 'N/A'
                        : _referralCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    '$_activeReferrals active referrals',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==================================================
            // RATE
            // ==================================================

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: Color(0xFF159B61),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Current Mining Rate',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${_miningRate.toStringAsFixed(2)} FAN/H',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF159B61),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Your Referrals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (_referrals.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 50,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No referrals yet.',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._referrals.map(
                (item) {
                  final referral =
                      item is Map
                          ? Map<String, dynamic>.from(
                              item,
                            )
                          : <String, dynamic>{};

                  final name =
                      referral['name']
                              ?.toString() ??
                          'User';

                  final active =
                      referral['miningActive'] ==
                          true;

                  return Container(
                    margin:
                        const EdgeInsets.only(
                      bottom: 10,
                    ),
                    padding:
                        const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF3B159B),
                          child: Text(
                            _firstLetter(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                referral['email']
                                        ?.toString() ??
                                    '',
                                style:
                                    const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          active
                              ? 'ACTIVE'
                              : 'INACTIVE',
                          style: TextStyle(
                            color: active
                                ? Colors.green
                                : Colors.grey,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _firstLetter(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      return 'U';
    }

    return name.substring(0, 1).toUpperCase();
  }
}

// ============================================================
// WALLET TAB
// ============================================================

class WalletTab extends StatelessWidget {
  const WalletTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF3B159B)
                          .withValues(
                    alpha: 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .account_balance_wallet_rounded,
                  size: 55,
                  color: Color(0xFF3B159B),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Wallet',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'COMING SOON',
                style: TextStyle(
                  color: Color(0xFF3B159B),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Wallet and withdrawal features will be available in a future update.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SETTINGS TAB
// ============================================================

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _logout(
    BuildContext context,
  ) async {
    try {
      await ApiService.clearToken();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const LoginFallbackScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    }
  }

  Future<void> _showLogoutDialog(
    BuildContext context,
  ) async {
    final shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Log out?',
          ),
          content: const Text(
            'Are you sure you want to log out of POWER FAN NETWORK?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'CANCEL',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'LOG OUT',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true &&
        context.mounted) {
      await _logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF241064),
            ),
          ),

          const SizedBox(height: 20),

          _settingTile(
            icon: Icons.person_outline,
            title: 'Account',
            subtitle: 'Manage your account',
            onTap: () {},
          ),

          _settingTile(
            icon: Icons.security_outlined,
            title: 'Security',
            subtitle:
                'Password and account security',
            onTap: () {},
          ),

          _settingTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle:
                'App language settings',
            onTap: () {},
          ),

          _settingTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle:
                'POWER FAN NETWORK',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName:
                    'POWER FAN NETWORK',
                applicationVersion:
                    '1.0.0',
                applicationLegalese:
                    'POWER FAN NETWORK - AFAM',
              );
            },
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showLogoutDialog(
                context,
              ),
              icon: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              label: const Text(
                'LOG OUT',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.red,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: const Color(0xFF3B159B),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN FALLBACK SCREEN
// ============================================================
//
// This replaces the missing LoginFallbackScreen that caused
// the previous analyzer error.
//
// If your project already has a real AuthPage/LoginPage,
// you can later replace this screen with that page.
//

class LoginFallbackScreen extends StatelessWidget {
  const LoginFallbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF3B159B)
                            .withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons
                        .account_circle_outlined,
                    size: 70,
                    color:
                        Color(0xFF3B159B),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'POWER FAN NETWORK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You have been logged out.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pop();
                    },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF3B159B,
                      ),
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    child: const Text(
                      'GO BACK',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
