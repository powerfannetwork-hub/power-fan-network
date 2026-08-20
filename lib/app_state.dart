import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_constants.dart';

class AppState extends ChangeNotifier {
  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String _keyFanBalance = 'fan_balance';
  static const String _keyMiningStatus = 'mining_status';
  static const String _keyMiningStart = 'mining_start';
  static const String _keyMiningEnd = 'mining_end';
  static const String _keyMiningRate = 'mining_rate';

  static const String _keyAdsToday = 'ads_today';
  static const String _keyAdsDate = 'ads_date';

  static const String _keyCheckInStreak = 'checkin_streak';
  static const String _keyLastCheckIn = 'last_checkin';

  static const String _keyReferralCount = 'referral_count';
  static const String _keyActiveReferralCount =
      'active_referrals';

  static const String _keySocialTaskDate =
      'social_task_date';
  static const String _keySocialTaskVerified =
      'social_task_verified';
  static const String _keySocialTaskClaimed =
      'social_task_claimed';

  static const String _keyKyc1Status = 'kyc1_status';
  static const String _keyKyc2Status = 'kyc2_status';
  static const String _keyKyc3Status = 'kyc3_status';

  static const String _keyAuthenticated = 'authenticated';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyWarningShown =
      'device_warning_shown';

  // ============================================================
  // PRIVATE STATE
  // ============================================================

  SharedPreferences? _prefs;

  Timer? _ticker;

  bool _initialized = false;

  double _fanBalance = 0.0;

  String _miningStatus =
      AppConstants.miningStatusReady;

  int? _miningStartTime;
  int? _miningEndTime;

  double _miningRateAtStart =
      AppConstants.baseMiningRate;

  int _adsWatchedToday = 0;

  String? _adsDate;

  int _checkInStreak = 0;

  String? _lastCheckInDate;

  int _referralCount = 0;

  int _activeReferralCount = 0;

  String? _socialTaskDate;

  bool _socialTaskVerified = false;

  bool _socialTaskClaimed = false;

  String _kyc1Status =
      AppConstants.kycStatusLocked;

  String _kyc2Status =
      AppConstants.kycStatusLocked;

  String _kyc3Status =
      AppConstants.kycStatusLocked;

  bool _isAuthenticated = false;

  bool _isFirstLaunch = true;

  bool _deviceWarningShown = false;

  final List<AppNotification> _notifications = [];

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  AppState() {
    _initialize();
  }

  // ============================================================
  // PROVIDER ACCESS
  // ============================================================

  static AppState of(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      final inherited =
          context.dependOnInheritedWidgetOfExactType<
              _AppStateInherited>();

      if (inherited == null) {
        throw FlutterError(
          'AppStateScope was not found above this widget.',
        );
      }

      return inherited.state;
    }

    final element = context
        .getElementForInheritedWidgetOfExactType<
            _AppStateInherited>();

    if (element == null) {
      throw FlutterError(
        'AppStateScope was not found above this widget.',
      );
    }

    return (element.widget as _AppStateInherited).state;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _loadState();

    _checkDailyReset();

    _checkMiningCompletion();

    _startTicker();

    _initialized = true;

    notifyListeners();
  }

  // ============================================================
  // LOAD STATE
  // ============================================================

  void _loadState() {
    final prefs = _prefs;

    if (prefs == null) {
      return;
    }

    _fanBalance =
        prefs.getDouble(_keyFanBalance) ?? 0.0;

    _miningStatus =
        prefs.getString(_keyMiningStatus) ??
            AppConstants.miningStatusReady;

    _miningStartTime =
        prefs.getInt(_keyMiningStart);

    _miningEndTime =
        prefs.getInt(_keyMiningEnd);

    _miningRateAtStart =
        prefs.getDouble(_keyMiningRate) ??
            AppConstants.baseMiningRate;

    _adsWatchedToday =
        prefs.getInt(_keyAdsToday) ?? 0;

    _adsDate =
        prefs.getString(_keyAdsDate);

    _checkInStreak =
        prefs.getInt(_keyCheckInStreak) ?? 0;

    _lastCheckInDate =
        prefs.getString(_keyLastCheckIn);

    _referralCount =
        prefs.getInt(_keyReferralCount) ?? 0;

    _activeReferralCount =
        prefs.getInt(
      _keyActiveReferralCount,
    ) ??
        0;

    _socialTaskDate =
        prefs.getString(_keySocialTaskDate);

    _socialTaskVerified =
        prefs.getBool(
          _keySocialTaskVerified,
        ) ??
            false;

    _socialTaskClaimed =
        prefs.getBool(
          _keySocialTaskClaimed,
        ) ??
            false;

    _kyc1Status =
        prefs.getString(_keyKyc1Status) ??
            AppConstants.kycStatusLocked;

    _kyc2Status =
        prefs.getString(_keyKyc2Status) ??
            AppConstants.kycStatusLocked;

    _kyc3Status =
        prefs.getString(_keyKyc3Status) ??
            AppConstants.kycStatusLocked;

    _isAuthenticated =
        prefs.getBool(
          _keyAuthenticated,
        ) ??
            false;

    _isFirstLaunch =
        prefs.getBool(
          _keyFirstLaunch,
        ) ??
            true;

    _deviceWarningShown =
        prefs.getBool(
          _keyWarningShown,
        ) ??
            false;
  }

  // ============================================================
  // PERSISTENCE
  // ============================================================

  Future<void> _persistState() async {
    final prefs = _prefs;

    if (prefs == null) {
      return;
    }

    await prefs.setDouble(
      _keyFanBalance,
      _fanBalance,
    );

    await prefs.setString(
      _keyMiningStatus,
      _miningStatus,
    );

    if (_miningStartTime != null) {
      await prefs.setInt(
        _keyMiningStart,
        _miningStartTime!,
      );
    } else {
      await prefs.remove(
        _keyMiningStart,
      );
    }

    if (_miningEndTime != null) {
      await prefs.setInt(
        _keyMiningEnd,
        _miningEndTime!,
      );
    } else {
      await prefs.remove(
        _keyMiningEnd,
      );
    }

    await prefs.setDouble(
      _keyMiningRate,
      _miningRateAtStart,
    );

    await prefs.setInt(
      _keyAdsToday,
      _adsWatchedToday,
    );

    await prefs.setString(
      _keyAdsDate,
      _adsDate ?? _todayDateString(),
    );

    await prefs.setInt(
      _keyCheckInStreak,
      _checkInStreak,
    );

    if (_lastCheckInDate != null) {
      await prefs.setString(
        _keyLastCheckIn,
        _lastCheckInDate!,
      );
    } else {
      await prefs.remove(
        _keyLastCheckIn,
      );
    }

    await prefs.setInt(
      _keyReferralCount,
      _referralCount,
    );

    await prefs.setInt(
      _keyActiveReferralCount,
      _activeReferralCount,
    );

    await prefs.setString(
      _keySocialTaskDate,
      _socialTaskDate ?? _todayDateString(),
    );

    await prefs.setBool(
      _keySocialTaskVerified,
      _socialTaskVerified,
    );

    await prefs.setBool(
      _keySocialTaskClaimed,
      _socialTaskClaimed,
    );

    await prefs.setString(
      _keyKyc1Status,
      _kyc1Status,
    );

    await prefs.setString(
      _keyKyc2Status,
      _kyc2Status,
    );

    await prefs.setString(
      _keyKyc3Status,
      _kyc3Status,
    );

    await prefs.setBool(
      _keyAuthenticated,
      _isAuthenticated,
    );

    await prefs.setBool(
      _keyFirstLaunch,
      _isFirstLaunch,
    );

    await prefs.setBool(
      _keyWarningShown,
      _deviceWarningShown,
    );
  }

  // ============================================================
  // PUBLIC GETTERS
  // ============================================================

  bool get initialized => _initialized;

  double get fanBalance => _fanBalance;

  String get miningStatus => _miningStatus;

  bool get isMining =>
      _miningStatus ==
      AppConstants.miningStatusMining;

  bool get miningCompleted =>
      _miningStatus ==
      AppConstants.miningStatusCompleted;

  bool get miningReady =>
      _miningStatus ==
      AppConstants.miningStatusReady;

  int get adsWatchedToday {
    _checkDailyReset();

    return _adsWatchedToday;
  }

  int get maxDailyAds =>
      AppConstants.maxDailyAds;

  int get checkInStreak =>
      _checkInStreak;

  int get referralCount =>
      _referralCount;

  int get activeReferralCount =>
      _activeReferralCount;

  bool get socialTaskVerified {
    _checkDailyReset();

    return _socialTaskVerified;
  }

  bool get socialTaskClaimed {
    _checkDailyReset();

    return _socialTaskClaimed;
  }

  String get kyc1Status =>
      _kyc1Status;

  String get kyc2Status =>
      _kyc2Status;

  String get kyc3Status =>
      _kyc3Status;

  bool get isAuthenticated =>
      _isAuthenticated;

  bool get isFirstLaunch =>
      _isFirstLaunch;

  bool get deviceWarningShown =>
      _deviceWarningShown;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadNotificationCount {
    return _notifications
        .where(
          (item) => !item.read,
        )
        .length;
  }

  // ============================================================
  // MINING RATE
  // ============================================================

  double get referralMiningBoost {
    return _activeReferralCount *
        AppConstants.activeReferralMiningBoost;
  }

  double get adMiningBoost {
    return _adsWatchedToday *
        AppConstants.adMiningBoost;
  }

  double get currentMiningRate {
    return AppConstants.baseMiningRate +
        adMiningBoost +
        referralMiningBoost;
  }

  double get miningRateAtStart =>
      _miningRateAtStart;

  // ============================================================
  // SESSION EARNINGS
  // ============================================================

  double get sessionEarnedFan {
    if (_miningStartTime == null) {
      return 0.0;
    }

    if (_miningStatus ==
        AppConstants.miningStatusReady) {
      return 0.0;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    final start = _miningStartTime!;

    final end = _miningEndTime ??
        (start +
            AppConstants
                .miningSessionMilliseconds);

    final effectiveNow =
        now > end ? end : now;

    if (effectiveNow <= start) {
      return 0.0;
    }

    final elapsed =
        effectiveNow - start;

    final elapsedHours =
        elapsed /
            AppConstants
                .millisecondsPerHour;

    return elapsedHours *
        _miningRateAtStart;
  }

  // ============================================================
  // MINING REMAINING TIME
  // ============================================================

  Duration get miningRemainingTime {
    if (_miningStatus !=
        AppConstants.miningStatusMining) {
      return Duration.zero;
    }

    if (_miningEndTime == null) {
      return Duration.zero;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    final difference =
        _miningEndTime! - now;

    if (difference <= 0) {
      return Duration.zero;
    }

    return Duration(
      milliseconds: difference,
    );
  }

  // ============================================================
  // MINING PROGRESS
  // ============================================================

  double get miningProgress {
    if (_miningStartTime == null ||
        _miningEndTime == null) {
      return 0.0;
    }

    final total =
        _miningEndTime! -
            _miningStartTime!;

    if (total <= 0) {
      return 1.0;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    final elapsed =
        now - _miningStartTime!;

    final progress =
        elapsed / total;

    if (progress < 0) {
      return 0.0;
    }

    if (progress > 1) {
      return 1.0;
    }

    return progress;
  }

  // ============================================================
  // START MINING
  // ============================================================

  bool startMining() {
    _checkMiningCompletion();

    if (_miningStatus !=
        AppConstants.miningStatusReady) {
      return false;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    _miningStartTime = now;

    _miningEndTime =
        now +
            AppConstants
                .miningSessionMilliseconds;

    _miningRateAtStart =
        currentMiningRate;

    _miningStatus =
        AppConstants.miningStatusMining;

    _persistState();

    notifyListeners();

    return true;
  }

  // ============================================================
  // CHECK MINING COMPLETION
  // ============================================================

  void _checkMiningCompletion() {
    if (_miningStatus !=
        AppConstants.miningStatusMining) {
      return;
    }

    if (_miningEndTime == null) {
      return;
    }

    final now =
        DateTime.now().millisecondsSinceEpoch;

    if (now >= _miningEndTime!) {
      _miningStatus =
          AppConstants.miningStatusCompleted;

      _addMiningCompletedNotification();

      _persistState();

      notifyListeners();
    }
  }

  // ============================================================
  // CLAIM MINING REWARD
  // ============================================================

  double claimMiningReward() {
    _checkMiningCompletion();

    if (_miningStatus !=
        AppConstants.miningStatusCompleted) {
      return 0.0;
    }

    final reward =
        AppConstants.miningSessionHours *
            _miningRateAtStart;

    if (reward <= 0) {
      return 0.0;
    }

    _fanBalance += reward;

    _miningStatus =
        AppConstants.miningStatusReady;

    _miningStartTime = null;

    _miningEndTime = null;

    _miningRateAtStart =
        currentMiningRate;

    _persistState();

    notifyListeners();

    return reward;
  }

  // ============================================================
  // REWARDED ADS
  // ============================================================

  bool canWatchRewardedAd() {
    _checkDailyReset();

    return _adsWatchedToday <
        AppConstants.maxDailyAds;
  }

  /// This MUST only be called after the ad network
  /// confirms that the user earned the reward.
  bool registerCompletedRewardedAd() {
    _checkDailyReset();

    if (_adsWatchedToday >=
        AppConstants.maxDailyAds) {
      return false;
    }

    _adsWatchedToday++;

    _adsDate =
        _todayDateString();

    _persistState();

    notifyListeners();

    return true;
  }

  int get adsRemainingToday {
    _checkDailyReset();

    final remaining =
        AppConstants.maxDailyAds -
            _adsWatchedToday;

    return remaining < 0
        ? 0
        : remaining;
  }

  // ============================================================
  // DAILY CHECK-IN
  // ============================================================

  bool get isTodayCheckedIn {
    return _lastCheckInDate ==
        _todayDateString();
  }

  bool dailyCheckIn() {
    if (isTodayCheckedIn) {
      return false;
    }

    final today =
        DateTime.now();

    final yesterday =
        today.subtract(
      const Duration(days: 1),
    );

    final yesterdayString =
        _dateToString(yesterday);

    if (_lastCheckInDate ==
        yesterdayString) {
      _checkInStreak++;
    } else {
      _checkInStreak = 1;
    }

    _lastCheckInDate =
        _todayDateString();

    _fanBalance +=
        AppConstants.dailyCheckInReward;

    _updateKycEligibility();

    _persistState();

    notifyListeners();

    return true;
  }

  // ============================================================
  // KYC ELIGIBILITY
  // ============================================================

  void _updateKycEligibility() {
    if (_checkInStreak >=
            AppConstants.kyc1CheckInDays &&
        _kyc1Status ==
            AppConstants.kycStatusLocked) {
      _kyc1Status =
          AppConstants.kycStatusAvailable;
    }

    if (_checkInStreak >=
            AppConstants.kyc2CheckInDays &&
        _referralCount >=
            AppConstants.kyc2RequiredReferrals &&
        _kyc1Status ==
            AppConstants.kycStatusVerified &&
        _kyc2Status ==
            AppConstants.kycStatusLocked) {
      _kyc2Status =
          AppConstants.kycStatusAvailable;
    }
  }

  // ============================================================
  // REFERRALS
  // ============================================================

  void setReferralCount(
    int count,
  ) {
    _referralCount =
        count < 0 ? 0 : count;

    _updateKycEligibility();

    _persistState();

    notifyListeners();
  }

  void setActiveReferralCount(
    int count,
  ) {
    _activeReferralCount =
        count < 0 ? 0 : count;

    _persistState();

    notifyListeners();
  }

  // ============================================================
  // REFERRAL REMINDER
  // ============================================================

  bool remindReferralToMine() {
    if (!AppConstants
        .allowReferralReminderNotification) {
      return false;
    }

    if (_activeReferralCount >=
        _referralCount) {
      return false;
    }

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        title: 'Mining Reminder',
        message:
            'Some of your referrals are inactive. '
            'Remind them to start mining.',
        createdAt: DateTime.now(),
        read: false,
        type: 'referral_reminder',
      ),
    );

    notifyListeners();

    return true;
  }

  // ============================================================
  // SOCIAL TASK
  // ============================================================

  bool canClaimSocialTask() {
    _checkDailyReset();

    return _socialTaskVerified &&
        !_socialTaskClaimed;
  }

  void setSocialTaskVerified(
    bool verified,
  ) {
    _socialTaskVerified =
        verified;

    _socialTaskDate =
        _todayDateString();

    _persistState();

    notifyListeners();
  }

  double claimSocialTask() {
    _checkDailyReset();

    if (!_socialTaskVerified) {
      return 0.0;
    }

    if (_socialTaskClaimed) {
      return 0.0;
    }

    final reward =
        AppConstants.dailySocialTaskReward;

    _fanBalance += reward;

    _socialTaskClaimed = true;

    _socialTaskDate =
        _todayDateString();

    _persistState();

    notifyListeners();

    return reward;
  }

  // ============================================================
  // KYC STATUS
  // ============================================================

  void setKyc1Status(
    String status,
  ) {
    _kyc1Status = status;

    _persistState();

    notifyListeners();
  }

  void setKyc2Status(
    String status,
  ) {
    _kyc2Status = status;

    _persistState();

    notifyListeners();
  }

  void setKyc3Status(
    String status,
  ) {
    if (AppConstants.kyc3Locked) {
      return;
    }

    _kyc3Status = status;

    _persistState();

    notifyListeners();
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  void setAuthenticated(
    bool value,
  ) {
    _isAuthenticated = value;

    if (value) {
      _isFirstLaunch = false;
    }

    _persistState();

    notifyListeners();
  }

  void signOutLocal() {
    _isAuthenticated = false;

    _persistState();

    notifyListeners();
  }

  // ============================================================
  // FIRST LAUNCH
  // ============================================================

  void completeFirstLaunch() {
    _isFirstLaunch = false;

    _persistState();

    notifyListeners();
  }

  // ============================================================
  // DEVICE WARNING
  // ============================================================

  void markDeviceWarningShown() {
    _deviceWarningShown = true;

    _persistState();

    notifyListeners();
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  void addNotification({
    required String title,
    required String message,
    String type = 'general',
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        title: title,
        message: message,
        createdAt: DateTime.now(),
        read: false,
        type: type,
      ),
    );

    notifyListeners();
  }

  void markNotificationRead(
    String id,
  ) {
    final index =
        _notifications.indexWhere(
      (item) => item.id == id,
    );

    if (index == -1) {
      return;
    }

    _notifications[index] =
        _notifications[index].copyWith(
      read: true,
    );

    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (var i = 0;
        i < _notifications.length;
        i++) {
      _notifications[i] =
          _notifications[i].copyWith(
        read: true,
      );
    }

    notifyListeners();
  }

  void _addMiningCompletedNotification() {
    if (!AppConstants
        .miningCompletionNotification) {
      return;
    }

    final alreadyExists =
        _notifications.any(
      (item) =>
          item.type ==
              'mining_completed' &&
          item.createdAt
                  .difference(
                    DateTime.now(),
                  )
                  .inHours
                  .abs() <
              24,
    );

    if (alreadyExists) {
      return;
    }

    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        title: 'Mining Completed',
        message:
            'Your 24-hour mining session is complete. '
            'Open the app to claim your FAN reward.',
        createdAt: DateTime.now(),
        read: false,
        type: 'mining_completed',
      ),
    );
  }

  // ============================================================
  // DAILY RESET
  // ============================================================

  void _checkDailyReset() {
    final today =
        _todayDateString();

    bool changed = false;

    if (_adsDate != today) {
      _adsWatchedToday = 0;
      _adsDate = today;
      changed = true;
    }

    if (_socialTaskDate != today) {
      _socialTaskVerified = false;
      _socialTaskClaimed = false;
      _socialTaskDate = today;
      changed = true;
    }

    if (changed) {
      _persistState();
    }
  }

  // ============================================================
  // TICKER
  // ============================================================

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _checkMiningCompletion();
        _checkDailyReset();
        notifyListeners();
      },
    );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _todayDateString() {
    return _dateToString(
      DateTime.now(),
    );
  }

  String _dateToString(
    DateTime date,
  ) {
    final year =
        date.year
            .toString()
            .padLeft(4, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // RESET LOCAL DATA
  // ============================================================

  Future<void> resetLocalData() async {
    final prefs = _prefs;

    if (prefs == null) {
      return;
    }

    await prefs.clear();

    _fanBalance = 0.0;

    _miningStatus =
        AppConstants.miningStatusReady;

    _miningStartTime = null;

    _miningEndTime = null;

    _miningRateAtStart =
        AppConstants.baseMiningRate;

    _adsWatchedToday = 0;

    _adsDate = null;

    _checkInStreak = 0;

    _lastCheckInDate = null;

    _referralCount = 0;

    _activeReferralCount = 0;

    _socialTaskDate = null;

    _socialTaskVerified = false;

    _socialTaskClaimed = false;

    _kyc1Status =
        AppConstants.kycStatusLocked;

    _kyc2Status =
        AppConstants.kycStatusLocked;

    _kyc3Status =
        AppConstants.kycStatusLocked;

    _isAuthenticated = false;

    _isFirstLaunch = true;

    _deviceWarningShown = false;

    _notifications.clear();

    notifyListeners();
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

// =================================================================
// NOTIFICATION MODEL
// =================================================================

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool read;
  final String type;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
    this.type = 'general',
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? read,
    String? type,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      type: type ?? this.type,
    );
  }
}

// =================================================================
// PROVIDER INHERITED WIDGET
// =================================================================

class _AppStateInherited
    extends InheritedNotifier<AppState> {
  const _AppStateInherited({
    required AppState state,
    required Widget child,
  }) : super(
          notifier: state,
          child: child,
        );

  AppState get state => notifier!;
}

// =================================================================
// APP STATE PROVIDER SCOPE
// =================================================================

class AppStateScope extends StatelessWidget {
  final AppState state;
  final Widget child;

  const AppStateScope({
    super.key,
    required this.state,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return _AppStateInherited(
      state: state,
      child: child,
    );
  }
}
