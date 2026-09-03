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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final MiningService _miningService = MiningService.instance;
  final SocialTaskService _socialTaskService = SocialTaskService.instance;
  final ReferralService _referralService = ReferralService();
  final ProfileService _profileService = ProfileService();
  final KycService _kycService = KycService();

  Timer? _countdownTimer; // SABO: Don countdown na gaske
  Duration _timeLeft = Duration.zero; // SABO

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
    _startCountdownTimer(); // FARA TIMER
  }

  @override
  void dispose() {
    _countdownTimer?.cancel(); // KASHE TIMER IDAN KA FITO
    super.dispose();
  }

  // SABO GABA DAYA: WANNAN SHINE COUNTDOWN NA GASKI
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_miningEndsAt == null) return;
      final diff = _miningEndsAt!.difference(DateTime.now());
      if (mounted) {
        setState(() {
          _timeLeft = diff.isNegative? Duration.zero : diff;
          if (_timeLeft == Duration.zero && _isMining) {
            _isMining = false; // Idan lokaci ya cika ya koma claimable
          }
        });
      }
    });
  }

  String get _formattedTimeLeft {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(_timeLeft.inHours);
    final minutes = twoDigits(_timeLeft.inMinutes.remainder(60));
    final seconds = twoDigits(_timeLeft.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
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
        _miningService.getUserMiningRate(), // Wannan zai dawo da rate na gaske yanzu
        _referralService.getReferralInfo(),
        _kycService.getStatus(),
        _socialTaskService.getDailyTasksForCard(),
        _profileService.getProfile(),
      ]);
      if (!mounted) return;

      final balanceData = results[0] as Map<String, dynamic>;
      final miningData = results[1] as Map<String, dynamic>;
      final rateData = results[2];

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
      _startCountdownTimer(); // SAKE FARAR TIMER BAYAN LOAD
      await _refreshAdCount();
      await _loadReferralItems();
    } catch (error) {
      if (!mounted) return;
      _showMessage(_cleanError(error));
    }
  }

  // SAURAN FUNCTIONS DINKA NA TSOFA: _refreshAdCount, _loadReferralItems, _refreshDashboard, _startMining, _claimMining, _onBoostUpdated, _completeSocialTask, _faceVerification, _pingReferral, _buildHome, _buildWelcomeHeader, _buildBalanceSummary, _balanceItem, _buildQuickReferral, _buildCurrentPage, build, _extractRate, _toDouble, _toBool, _parseDateTime, _cleanError, _showMessage
  // KADA KA TABA SU. KA BARI SU YADDA SUKE.

  // GYARA WANNAN FUNCTION KAWAI A KASA
  double _extractRate(dynamic data) {
    final parsed = _toDouble(data);
    return parsed > 0? parsed : 0.2;
  }

  double _toDouble(dynamic value) { if (value is num) return value.toDouble(); return double.tryParse(value?.toString()?? '')?? 0.0; }
  bool _toBool(dynamic value) { if (value is bool) return value; if (value is num) return value!= 0; final text = value?.toString().trim().toLowerCase(); return text == 'true' || text == '1' || text == 'yes'; }
  DateTime? _parseDateTime(dynamic value) { if (value == null) return null; if (value is DateTime) return value.toLocal(); final text = value.toString().trim(); if (text.isEmpty) return null; return DateTime.tryParse(text)?.toLocal(); }
  String _cleanError(Object error) { var text = error.toString().trim(); if (text.startsWith('Exception: ')) text = text.substring(11); return text.isEmpty? 'Something went wrong' : text; }
  void _showMessage(String message) { if (!mounted) return; ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message))); }
}
  
