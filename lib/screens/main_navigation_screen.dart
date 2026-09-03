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
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  final MiningService _miningService = MiningService.instance;
  final SocialTaskService _socialTaskService = SocialTaskService.instance;
  final ReferralService _referralService = ReferralService();
  final ProfileService _profileService = ProfileService();
  final KycService _kycService = KycService();

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
  List<ReferralItem> _referrals = <ReferralItem>[];
  List<DailySocialTask> _socialTasks = <DailySocialTask>[];

  final List<String> _titles = const ['POWER FAN', 'Referrals', 'Wallet', 'Settings'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() { _loading = true; });
    await _loadData();
    if (!mounted) return;
    setState(() { _loading = false; });
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

      final balanceData = results[0] as Map<String, dynamic>;
      final miningData = results[1] as Map<String, dynamic>;
      final rateData = results[2]; // KAWAI GYARA NAN

      final referralInfo = results[3] as ReferralInfo;
      final kycStatus = results[4] as KycStatus;
      final socialTasks = results[5] as List<DailySocialTask>;

      final miningStarted = _parseDateTime(miningData['started_at']?? miningData['mining_started_at']?? miningData['startedAt']);
      final miningEnds = _parseDateTime(miningData['ends_at']?? miningData['mining_ends_at']?? miningData['endsAt']);
      final miningActive = _toBool(miningData['is_mining']?? miningData['mining_active']?? miningData['active']);
      final rate = _extractRate(rateData);

      setState(() {
        _fanBalance = _toDouble(balanceData['fan_balance']);
        _afamBalance = _toDouble(balanceData['afam_balance']);
        _miningStartedAt = miningStarted;
        _miningEndsAt = miningEnds;
        _isMining = miningActive && miningStarted!= null && miningEnds!= null && DateTime.now().isBefore(miningEnds);
        _miningRate = rate > 0? rate : 0.2;
        _activeReferrals = referralInfo.activeReferrals;
        _checkInDays = kycStatus.checkInDays;
        _faceVerified = kycStatus.faceVerified;
        _kyc1Verified = kycStatus.kyc1Verified;
        _kyc2Eligible = kycStatus.kyc2Eligible;
        _socialTasks = socialTasks;
      });
      await _refreshAdCount();
      await _loadReferralItems();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(_cleanError(error))));
    }
  }

  Future<void> _refreshAdCount() async {
    if (!_isMining || _miningStartedAt == null) {
      if (!mounted) return;
      setState(() { _adsWatched = 0; });
      return;
    }
    try {
      final count = await _miningService.getAdsWatchedForSession(startedAt: _miningStartedAt!);
      if (!mounted) return;
      setState(() { _adsWatched = count.clamp(0, 7); });
    } catch (_) {}
  }

  Future<void> _loadReferralItems() async {
    try {
      final info = await _referralService.getReferralInfo();
      if (!mounted) return;
      setState(() { _activeReferrals = info.activeReferrals; _referrals = <ReferralItem>[]; });
    } catch (_) {}
  }

  Future<void> _refreshDashboard() async {
    if (_refreshing) return;
    setState(() { _refreshing = true; });
    await _loadData();
    if (!mounted) return;
    setState(() { _refreshing = false; });
  }

  Future<void> _startMining() async {
    if (_loading) return;
    try {
      final result = await _miningService.startMining();
      final startedAt = _parseDateTime(result['started_at']?? result['mining_started_at']?? result['startedAt']);
      final endsAt = _parseDateTime(result['ends_at']?? result['mining_ends_at']?? result['endsAt']);
      final now = DateTime.now();
      final effectiveStartedAt = startedAt?? now;
      final effectiveEndsAt = endsAt?? effectiveStartedAt.add(const Duration(hours: 24));
      if (!mounted) return;
      setState(() { _isMining = true; _miningStartedAt = effectiveStartedAt; _miningEndsAt = effectiveEndsAt; _adsWatched = 0; });
      await _loadData();
      if (!mounted) return;
      _showMessage('Mining started for 24 hours.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }

  Future<void> _claimMining() async {
    if (!_isMining) return;
    final endsAt = _miningEndsAt;
    if (endsAt!= null && DateTime.now().isBefore(endsAt)) {
      _showMessage('Your mining session is still active.');
      return;
    }
    try {
      final result = await _miningService.claimMining();
      final success = result['success']!= false;
      if (!success) { _showMessage(result['message']?.toString()?? 'Unable to claim mining reward.'); return; }
      if (!mounted) return;
      setState(() { _isMining = false; _miningStartedAt = null; _miningEndsAt = null; _adsWatched = 0; });
      await _loadData();
      if (!mounted) return;
      _showMessage('Mining reward claimed successfully.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }

  Future<void> _onBoostUpdated() async { await _loadData(); }

  Future<void> _completeSocialTask(DailySocialTask task) async {
    try {
      final serviceTask = await _socialTaskService.findTask(task.id);
      if (serviceTask == null) { _showMessage('This social task is no longer available.'); return; }
      final result = await _socialTaskService.verifyAndClaim(taskId: serviceTask.id);
      if (!mounted) return;
      if (result.success) {
        setState(() { _fanBalance = result.fanBalance; });
        _showMessage('+${result.rewardFan.toStringAsFixed(0)} FAN reward claimed.');
        await _loadData();
      } else { _showMessage(result.message.isEmpty? 'The social task could not be claimed.' : result.message); }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }

  Future<void> _faceVerification() async {
    try {
      await _kycService.startFaceVerification();
      if (!mounted) return;
      _showMessage('Face Verification will be available soon.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }

  Future<void> _pingReferral(ReferralItem referral) async {
    throw Exception('Referral reminder service is not available yet.');
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 16),
          MiningCard(fanBalance: _fanBalance, miningRate: _miningRate, isMining: _isMining, startedAt: _miningStartedAt, endsAt: _miningEndsAt, adsWatched: _adsWatched, maxAds: 7, onStartMining: _startMining, onClaimMining: _claimMining),
          const SizedBox(height: 16),
          BoostAdsCard(isMining: _isMining, sessionFinished: _sessionFinished, startedAt: _miningStartedAt, endsAt: _miningEndsAt, onMessage: _showMessage, onBoostUpdated: _onBoostUpdated),
          const SizedBox(height: 16),
          DailySocialCard(tasks: _socialTasks, onClaim: _completeSocialTask, loading: _loading),
          const SizedBox(height: 16),
          KycCard(checkInDays: _checkInDays, activeReferrals: _activeReferrals, faceVerified: _faceVerified, kyc1Verified: _kyc1Verified, kyc2Eligible: _kyc2Eligible, onFaceVerification: _faceVerification),
          const SizedBox(height: 16),
          _buildBalanceSummary(),
          const SizedBox(height: 16),
          _buildQuickReferral(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  bool get _sessionFinished { if (!_isMining) return false; final endsAt = _miningEndsAt; if (endsAt == null) return false; return!DateTime.now().isBefore(endsAt); }

  Widget _buildWelcomeHeader() {
    return Row(
      children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFF3B159B), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 29)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome to', style: TextStyle(color: Colors.grey, fontSize: 12)), SizedBox(height: 2), Text('POWER FAN NETWORK', style: TextStyle(color: Color(0xFF241064), fontSize: 17, fontWeight: FontWeight.w900))])),
        IconButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); }, icon: const Icon(Icons.person_outline_rounded)),
      ],
    );
  }

  Widget _buildBalanceSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _balanceItem(title: 'FAN', value: _fanBalance.toStringAsFixed(4), icon: Icons.bolt_rounded)), const SizedBox(width: 12), Expanded(child: _balanceItem(title: 'AFAM', value: _afamBalance.toStringAsFixed(4), icon: Icons.account_balance_wallet_outlined))]),
      ]),
    );
  }

  Widget _balanceItem({required String title, required String value, required IconData icon}) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF8F8FC), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: const Color(0xFF3B159B), size: 23), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]))]));
  }

  Widget _buildQuickReferral() { return ReferralCard(referrals: _referrals, onPing: _pingReferral, loading: _loading); }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0: return _buildHome();
      case 1: return const ReferralScreen();
      case 2: return WalletScreen(fanBalance: _fanBalance, afamBalance: _afamBalance);
      case 3: return const SettingsScreen();
      default: return _buildHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFFF8F8FC), surfaceTintColor: Colors.transparent, title: Text(_titles[_currentIndex], style: const TextStyle(color: Color(0xFF241064), fontWeight: FontWeight.w800)), actions: [if (_refreshing) const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))]),
      body: _loading? const Center(child: CircularProgressIndicator()) : _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(backgroundColor: Colors.white, elevation: 8, selectedIndex: _currentIndex, onDestinationSelected: (index) { setState(() { _currentIndex = index; }); }, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'), NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Referral'), NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'), NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings')]),
    );
  }

  double _extractRate(dynamic data) { final parsed = _toDouble(data); return parsed > 0? parsed : 0.2; }
  double _toDouble(dynamic value) { if (value is num) return value.toDouble(); return double.tryParse(value?.toString()?? '')?? 0.0; }
  bool _toBool(dynamic value) { if (value is bool) return value; if (value is num) return value!= 0; final text = value?.toString().trim().toLowerCase(); return text == 'true' || text == '1' || text == 'yes'; }
  DateTime? _parseDateTime(dynamic value) { if (value == null) return null; if (value is DateTime) return value.toLocal(); final text = value.toString().trim(); if (text.isEmpty) return null; return DateTime.tryParse(text)?.toLocal(); }
  String _cleanError(Object error) { var text = error.toString().trim(); if (text.startsWith('Exception: ')) text = text.substring(11); if (text.startsWith('PostgrestException: ')) text = text.substring(19); return text.isEmpty? 'Something went wrong. Please try again.' : text; }
  void _showMessage(String message) { if (!mounted) return; ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))); }
}
