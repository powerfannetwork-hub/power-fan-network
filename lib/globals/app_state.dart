import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_constants.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}

class AppState extends ChangeNotifier {
  // ============================================================
  // STORAGE
  // ============================================================

  SharedPreferences? _prefs;
  Timer? _ticker;

  bool _initialized = false;

  Future<void> _loadStorage() async {
    _prefs = await SharedPreferences.getInstance();

    _fanBalance = _prefs?.getDouble('fan_balance') ?? 0.0;

    _miningStatus =
        _prefs?.getString('mining_status') ?? 'READY';

    _miningStartTime =
        _prefs?.getInt('mining_start_time');

    _miningEndTime =
        _prefs?.getInt('mining_end_time');

    _miningRateAtStart =
        _prefs?.getDouble('mining_rate_at_start') ??
            AppConstants.baseMiningRate;

    _adsWatchedToday =
        _prefs?.getInt('ads_watched_today') ?? 0;

    _adsDate =
        _prefs?.getString('ads_date');

    _checkInStreak =
        _prefs?.getInt('check_in_streak') ?? 0;

    _lastCheckInDate =
        _prefs?.getString('last_check_in_date');

    _socialTaskClaimed =
        _prefs?.getBool('social_task_claimed') ?? false;

    _socialTaskDate =
        _prefs?.getString('social_task_date');

    _socialFollowCompleted =
        _prefs?.getBool('social_follow_completed') ?? false;

    _socialLikeCompleted =
        _prefs?.getBool('social_like_completed') ?? false;

    _socialCommentCompleted =
        _prefs?.getBool('social_comment_completed') ?? false;

    _referralCount =
        _prefs?.getInt('referral_count') ?? 0;

    _activeReferralCount =
        _prefs?.getInt('active_referral_count') ?? 0;

    _kycPhase1Status =
        _prefs?.getString('kyc_phase1_status') ?? 'LOCKED';

    _kycPhase2Status =
        _prefs?.getString('kyc_phase2_status') ?? 'LOCKED';

    _kycPhase3Status =
        _prefs?.getString('kyc_phase3_status') ?? 'LOCKED';

    _isAuthenticated =
        _prefs?.getBool('is_authenticated') ?? false;

    _deviceId =
        _prefs?.getString('device_id');

    _deviceBlocked =
        _prefs?.getBool('device_blocked') ?? false;

    _migrationEnabled =
        _prefs?.getBool('migration_enabled') ?? false;

    _initialized = true;

    _checkDailyReset();
    _checkMiningCompletion();

    notifyListeners();
  }

  AppState() {
    _loadStorage();
    _startTicker();
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    _prefs?.setBool('is_authenticated', value);
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _prefs?.setBool('is_authenticated', false);
    notifyListeners();
  }

  // ============================================================
  // FAN BALANCE
  // ============================================================

  double _fanBalance = 0.0;

  double get fanBalance => _fanBalance;

  void addFan(double amount) {
    if (amount <= 0) return;

    _fanBalance += amount;

    _persistState();
    notifyListeners();
  }

  // ============================================================
  // MINING
  // ============================================================

  String _miningStatus = 'READY';

  int? _miningStartTime;
  int? _miningEndTime;

  double _miningRateAtStart =
      AppConstants.baseMiningRate;

  String get miningStatus => _miningStatus;

  bool get isMining => _miningStatus == 'MINING';

  bool get miningCompleted =>
      _miningStatus == 'COMPLETED';

  int? get miningStartTime => _miningStartTime;

  int? get miningEndTime => _miningEndTime;

  // ============================================================
  // REFERRAL MINING BOOST
  // ============================================================

  int _referralCount = 0;
  int _activeReferralCount = 0;

  int get referralCount => _referralCount;

  int get activeReferralCount =>
      _activeReferralCount;

  double get referralMiningBoost =>
      _activeReferralCount * 0.02;

  double get currentMiningRate =>
      AppConstants.baseMiningRate +
      referralMiningBoost +
      adBoostRate;

  // ============================================================
  // AD BOOST
  // ============================================================

  int _adsWatchedToday = 0;
  String? _adsDate;

  int get adsWatchedToday => _adsWatchedToday;

  int get maxDailyAds =>
      AppConstants.maxDailyAds;

  double get adBoostRate =>
      _adsWatchedToday *
      AppConstants.adBoostRate;

  double get totalAdBoost =>
      adBoostRate;

  bool get canWatchAd =>
      _adsWatchedToday <
      AppConstants.maxDailyAds;

  // ============================================================
  // MINING SESSION
  // ============================================================

  bool startMining() {
    if (!_initialized) return false;

    if (_deviceBlocked) return false;

    if (_miningStatus == 'MINING') {
      return false;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    _miningStartTime = now;

    _miningEndTime =
        now +
        (AppConstants.miningSessionHours *
            60 *
            60 *
            1000);

    /*
      Muhimmiyar magana:

      Ana ɗaukar currentMiningRate a lokacin
      da aka fara mining.

      Saboda haka idan mutum ya fara da
      0.24 FAN/H, wannan session ɗin zai
      yi amfani da 0.24 FAN/H.
    */
    _miningRateAtStart =
        currentMiningRate;

    _miningStatus = 'MINING';

    _persistState();
    notifyListeners();

    return true;
  }

  // ============================================================
  // LIVE SESSION EARNINGS
  // ============================================================

  double get sessionEarnedFan {
    if (_miningStatus != 'MINING' &&
        _miningStatus != 'COMPLETED') {
      return 0.0;
    }

    if (_miningStartTime == null) {
      return 0.0;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    final end =
        _miningEndTime ??
        (now +
            AppConstants.miningSessionHours *
                60 *
                60 *
                1000);

    final clampedNow =
        now > end ? end : now;

    final elapsedMilliseconds =
        clampedNow - _miningStartTime!;

    final elapsedHours =
        elapsedMilliseconds /
            (1000 * 60 * 60);

    final earned =
        elapsedHours *
        _miningRateAtStart;

    return earned < 0 ? 0.0 : earned;
  }

  double get miningRateAtStart =>
      _miningRateAtStart;

  double get displayedMiningRate =>
      isMining
          ? _miningRateAtStart
          : currentMiningRate;

  // ============================================================
  // MINING TIMER
  // ============================================================

  Duration get miningRemaining {
    if (_miningStatus != 'MINING' ||
        _miningEndTime == null) {
      return Duration.zero;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    final remaining =
        _miningEndTime! - now;

    if (remaining <= 0) {
      return Duration.zero;
    }

    return Duration(milliseconds: remaining);
  }

  String get miningRemainingText {
    final duration = miningRemaining;

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

  String get miningSessionTimeText {
    if (_miningStatus == 'READY') {
      return '00:00:00 / 24:00:00';
    }

    final elapsed =
        _elapsedMiningDuration;

    final hours =
        elapsed.inHours
            .toString()
            .padLeft(2, '0');

    final minutes =
        elapsed.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        elapsed.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    return '$hours:$minutes:$seconds / 24:00:00';
  }

  Duration get _elapsedMiningDuration {
    if (_miningStartTime == null) {
      return Duration.zero;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    var elapsed =
        now - _miningStartTime!;

    const total =
        24 * 60 * 60 * 1000;

    if (elapsed < 0) {
      elapsed = 0;
    }

    if (elapsed > total) {
      elapsed = total;
    }

    return Duration(milliseconds: elapsed);
  }

  // ============================================================
  // AUTOMATIC MINING COMPLETION
  // ============================================================

  void _checkMiningCompletion() {
    if (_miningStatus != 'MINING' ||
        _miningEndTime == null) {
      return;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    if (now >= _miningEndTime!) {
      _miningStatus = 'COMPLETED';

      _addNotification(
        title: 'Mining Completed',
        message:
            'Your 24-hour FAN mining session has finished. Claim your reward.',
      );

      _persistState();
    }
  }

  // ============================================================
  // CLAIM MINING REWARD
  // ============================================================

  double claimMiningReward() {
    if (_miningStatus != 'COMPLETED') {
      return 0.0;
    }

    final reward =
        AppConstants.miningSessionHours *
        _miningRateAtStart;

    if (reward <= 0) {
      return 0.0;
    }

    _fanBalance += reward;

    _miningStatus = 'READY';

    _miningStartTime = null;

    _miningEndTime = null;

    _miningRateAtStart =
        AppConstants.baseMiningRate;

    _persistState();
    notifyListeners();

    return reward;
  }

  // ============================================================
  // WATCH REWARDED AD
  // ============================================================

  /*
    Wannan method ɗin ba zai ƙara reward ba
    sai an tabbatar cewa AdMob rewarded ad
    ya kammala successfully.

    UI/AdMob service zai kira:

       registerSuccessfulRewardedAd();

    bayan Google AdMob ta tabbatar da reward.
  */

  bool registerSuccessfulRewardedAd() {
    _checkDailyReset();

    if (_adsWatchedToday >=
        AppConstants.maxDailyAds) {
      return false;
    }

    _adsWatchedToday++;

    _persistState();
    notifyListeners();

    return true;
  }

  // ============================================================
  // DAILY SOCIAL MEDIA TASK
  // ============================================================

  bool _socialTaskClaimed = false;

  String? _socialTaskDate;

  bool _socialFollowCompleted = false;
  bool _socialLikeCompleted = false;
  bool _socialCommentCompleted = false;

  bool get socialTaskClaimed =>
      _socialTaskClaimed;

  bool get socialFollowCompleted =>
      _socialFollowCompleted;

  bool get socialLikeCompleted =>
      _socialLikeCompleted;

  bool get socialCommentCompleted =>
      _socialCommentCompleted;

  bool get socialTaskCompleted =>
      _socialFollowCompleted &&
      _socialLikeCompleted &&
      _socialCommentCompleted;

  bool get canClaimSocialReward =>
      socialTaskCompleted &&
      !_socialTaskClaimed;

  // ============================================================
  // SOCIAL TASK ACTIONS
  // ============================================================

  void completeSocialFollow() {
    _socialFollowCompleted = true;

    _persistState();
    notifyListeners();
  }

  void completeSocialLike() {
    _socialLikeCompleted = true;

    _persistState();
    notifyListeners();
  }

  void completeSocialComment() {
    _socialCommentCompleted = true;

    _persistState();
    notifyListeners();
  }

  bool claimSocialReward() {
    _checkDailyReset();

    /*
      Tsaro:
      mutum ba zai iya claim ba sai ya
      kammala FOLLOW + LIKE + COMMENT.
    */

    if (!canClaimSocialReward) {
      return false;
    }

    _fanBalance += 10.0;

    _socialTaskClaimed = true;

    _persistState();
    notifyListeners();

    return true;
  }

  // ============================================================
  // DAILY CHECK-IN
  // ============================================================

  int _checkInStreak = 0;

  String? _lastCheckInDate;

  int get checkInStreak =>
      _checkInStreak;

  String get todayDateString {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String get yesterdayDateString {
    final yesterday =
        DateTime.now()
            .subtract(const Duration(days: 1));

    return '${yesterday.year}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
  }

  bool get isTodayCheckedIn =>
      _lastCheckInDate == todayDateString;

  bool dailyCheckIn() {
    _checkDailyReset();

    if (isTodayCheckedIn) {
      return false;
    }

    if (_lastCheckInDate ==
        yesterdayDateString) {
      _checkInStreak++;
    } else {
      _checkInStreak = 1;
    }

    _lastCheckInDate =
        todayDateString;

    _fanBalance +=
        AppConstants.dailyCheckInBonus;

    if (_checkInStreak >=
            AppConstants.kycPhase1Days &&
        _kycPhase1Status == 'LOCKED') {
      _kycPhase1Status = 'AVAILABLE';

      _addNotification(
        title: 'KYC 1 Available',
        message:
            'You completed the required daily check-in streak. KYC 1 is now available.',
      );
    }

    _persistState();
    notifyListeners();

    return true;
  }

  // ============================================================
  // REFERRAL SYSTEM
  // ============================================================

  void setReferralCount(int count) {
    if (count < 0) return;

    _referralCount = count;

    _persistState();
    notifyListeners();
  }

  void setActiveReferralCount(int count) {
    if (count < 0) return;

    _activeReferralCount = count;

    _persistState();
    notifyListeners();
  }

  void successfulReferral() {
    _referralCount++;

    /*
      Referrer reward:
      +5 FAN
    */
    _fanBalance +=
        AppConstants.referrerBonus;

    _persistState();
    notifyListeners();
  }

  void newUserReferralWelcome() {
    /*
      New user:
      +20 FAN
    */
    _fanBalance +=
        AppConstants.welcomeReferralBonus;

    _persistState();
    notifyListeners();
  }

  // ============================================================
  // ACTIVE REFERRAL NOTIFICATION
  // ============================================================

  void notifyInactiveReferrals() {
    if (_activeReferralCount >=
        _referralCount) {
      return;
    }

    _addNotification(
      title: 'Referral Mining Reminder',
      message:
          'Some of your referrals are not actively mining. Remind them to start mining.',
    );

    notifyListeners();
  }

  // ============================================================
  // KYC
  // ============================================================

  String _kycPhase1Status = 'LOCKED';
  String _kycPhase2Status = 'LOCKED';
  String _kycPhase3Status = 'LOCKED';

  String get kycPhase1Status =>
      _kycPhase1Status;

  String get kycPhase2Status =>
      _kycPhase2Status;

  String get kycPhase3Status =>
      _kycPhase3Status;

  bool get kyc1Available =>
      _kycPhase1Status == 'AVAILABLE';

  bool get kyc2Available =>
      _kycPhase2Status == 'AVAILABLE';

  bool get kyc3Available =>
      _kycPhase3Status == 'AVAILABLE';

  void markKyc1Completed() {
    _kycPhase1Status = 'COMPLETED';

    if (_checkInStreak >=
        AppConstants.kycPhase2Days) {
      _kycPhase2Status = 'AVAILABLE';
    }

    _persistState();
    notifyListeners();
  }

  void markKyc2Completed() {
    if (_referralCount < 3) {
      return;
    }

    _kycPhase2Status = 'COMPLETED';

    _persistState();
    notifyListeners();
  }

  // ============================================================
  // KYC 3 / MIGRATION
  // ============================================================

  bool _migrationEnabled = false;

  bool get migrationEnabled =>
      _migrationEnabled;

  void enableMigration() {
    _migrationEnabled = true;

    _persistState();
    notifyListeners();
  }

  void enableKyc3() {
    _kycPhase3Status = 'AVAILABLE';

    _persistState();
    notifyListeners();
  }

  // ============================================================
  // DEVICE SECURITY
  // ============================================================

  String? _deviceId;

  bool _deviceBlocked = false;

  String? get deviceId => _deviceId;

  bool get deviceBlocked =>
      _deviceBlocked;

  void setDeviceId(String id) {
    if (id.trim().isEmpty) return;

    _deviceId = id;

    _prefs?.setString(
      'device_id',
      id,
    );

    notifyListeners();
  }

  /*
    Wannan state ne kawai.

    A real production security:
    One Account = One Device
    dole a tabbatar da shi server-side
    ta Firebase / Cloud Functions / backend.

    Kada client kadai ya yanke hukuncin
    cewa account ya halatta.
  */

  void blockDevice() {
    _deviceBlocked = true;

    _prefs?.setBool(
      'device_blocked',
      true,
    );

    _addNotification(
      title: 'Security Warning',
      message:
          'Suspicious multiple-device activity was detected on your account.',
    );

    notifyListeners();
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  final List<AppNotificationItem>
      _notifications = [];

  List<AppNotificationItem>
      get notifications =>
          List.unmodifiable(_notifications);

  void _addNotification({
    required String title,
    required String message,
  }) {
    final item =
        AppNotificationItem(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .toString(),
      title: title,
      message: message,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, item);

    /*
      Ana iya haɗa FCM daga baya domin
      notification ta zo ko app ɗin yana
      a rufe.
    */
  }

  void addNotification({
    required String title,
    required String message,
  }) {
    _addNotification(
      title: title,
      message: message,
    );

    notifyListeners();
  }

  void markNotificationRead(
      String notificationId) {
    for (final item in _notifications) {
      if (item.id == notificationId) {
        item.isRead = true;
        break;
      }
    }

    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final item in _notifications) {
      item.isRead = true;
    }

    notifyListeners();
  }

  // ============================================================
  // DAILY RESET
  // ============================================================

  void _checkDailyReset() {
    final today = todayDateString;

    if (_adsDate != today) {
      _adsDate = today;

      _adsWatchedToday = 0;
    }

    if (_socialTaskDate != today) {
      _socialTaskDate = today;

      _socialTaskClaimed = false;

      _socialFollowCompleted = false;

      _socialLikeCompleted = false;

      _socialCommentCompleted = false;
    }

    _persistState();
  }

  // ============================================================
  // LIVE TICKER
  // ============================================================

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!_initialized) return;

        _checkDailyReset();

        final previousStatus =
            _miningStatus;

        _checkMiningCompletion();

        if (previousStatus !=
            _miningStatus) {
          notifyListeners();
        } else if (_miningStatus ==
            'MINING') {
          notifyListeners();
        }
      },
    );
  }

  // ============================================================
  // PERSISTENCE
  // ============================================================

  Future<void> _persistState() async {
    final prefs = _prefs;

    if (prefs == null) return;

    await prefs.setDouble(
      'fan_balance',
      _fanBalance,
    );

    await prefs.setString(
      'mining_status',
      _miningStatus,
    );

    if (_miningStartTime != null) {
      await prefs.setInt(
        'mining_start_time',
        _miningStartTime!,
      );
    } else {
      await prefs.remove(
        'mining_start_time',
      );
    }

    if (_miningEndTime != null) {
      await prefs.setInt(
        'mining_end_time',
        _miningEndTime!,
      );
    } else {
      await prefs.remove(
        'mining_end_time',
      );
    }

    await prefs.setDouble(
      'mining_rate_at_start',
      _miningRateAtStart,
    );

    await prefs.setInt(
      'ads_watched_today',
      _adsWatchedToday,
    );

    if (_adsDate != null) {
      await prefs.setString(
        'ads_date',
        _adsDate!,
      );
    }

    await prefs.setInt(
      'check_in_streak',
      _checkInStreak,
    );

    if (_lastCheckInDate != null) {
      await prefs.setString(
        'last_check_in_date',
        _lastCheckInDate!,
      );
    }

    await prefs.setBool(
      'social_task_claimed',
      _socialTaskClaimed,
    );

    if (_socialTaskDate != null) {
      await prefs.setString(
        'social_task_date',
        _socialTaskDate!,
      );
    }

    await prefs.setBool(
      'social_follow_completed',
      _socialFollowCompleted,
    );

    await prefs.setBool(
      'social_like_completed',
      _socialLikeCompleted,
    );

    await prefs.setBool(
      'social_comment_completed',
      _socialCommentCompleted,
    );

    await prefs.setInt(
      'referral_count',
      _referralCount,
    );

    await prefs.setInt(
      'active_referral_count',
      _activeReferralCount,
    );

    await prefs.setString(
      'kyc_phase1_status',
      _kycPhase1Status,
    );

    await prefs.setString(
      'kyc_phase2_status',
      _kycPhase2Status,
    );

    await prefs.setString(
      'kyc_phase3_status',
      _kycPhase3Status,
    );

    await prefs.setBool(
      'migration_enabled',
      _migrationEnabled,
    );
  }

  // ============================================================
  // PROVIDER ACCESS
  // ============================================================

  static AppState of(
    BuildContext context, {
    bool listen = true,
  }) {
    /*
      Ba mu son import na provider ya zama
      wajibi a wannan file saboda muna amfani
      da inherited lookup ta hanyar context.
    */

    throw UnimplementedError(
      'AppState.of requires Provider. '
      'Add provider package and implement the '
      'Provider lookup in your project.',
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
