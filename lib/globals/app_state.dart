// ============================================================
// POWER FAN NETWORK
// APP STATE
// ============================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class AppState extends ChangeNotifier {
  final AuthService authService;

  AppState({
    required this.authService,
  });

  // ==========================================================
  // STATE
  // ==========================================================

  bool _initialized = false;
  bool _loading = false;

  String? _error;

  double _fanBalance = 0.0;
  double _afamBalance = 0.0;

  double _miningRate = 0.2;
  double _adBoost = 0.0;

  int _activeReferrals = 0;
  int _dailyAdsWatched = 0;

  bool _miningActive = false;

  DateTime? _miningStartedAt;
  DateTime? _miningEndsAt;

  Timer? _timer;

  Duration _remaining = Duration.zero;

  // ==========================================================
  // GETTERS
  // ==========================================================

  bool get initialized => _initialized;

  bool get loading => _loading;

  String? get error => _error;

  double get fanBalance => _fanBalance;

  double get afamBalance => _afamBalance;

  double get miningRate => _miningRate;

  double get adBoost => _adBoost;

  int get activeReferrals => _activeReferrals;

  int get dailyAdsWatched => _dailyAdsWatched;

  bool get miningActive => _miningActive;

  DateTime? get miningStartedAt => _miningStartedAt;

  DateTime? get miningEndsAt => _miningEndsAt;

  Duration get remaining => _remaining;

  bool get canWatchAd => _dailyAdsWatched < 7;

  double get referralBoost =>
      _activeReferrals * 0.02;

  double get baseMiningRate => 0.2;

  double get maxAdBoost => 0.7;

  double get maxMiningRate =>
      baseMiningRate +
      referralBoost +
      maxAdBoost;

  String get remainingText {
    final totalSeconds =
        _remaining.inSeconds.clamp(0, 86400);

    final hours =
        totalSeconds ~/ 3600;

    final minutes =
        (totalSeconds % 3600) ~/ 60;

    final seconds =
        totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    if (_initialized) return;

    _setLoading(true);
    _setError(null);

    try {
      await authService.initialize();

      await _loadFromStorage();

      if (authService.isAuthenticated) {
        await syncFromAuth();

        await refreshDashboard();
      }

      _startTimer();

      _initialized = true;
    } catch (error) {
      _setError(
        'Unable to initialize application.',
      );

      debugPrint(
        'APP STATE INITIALIZE ERROR: $error',
      );
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ==========================================================
  // SYNC AUTH USER
  // ==========================================================

  Future<void> syncFromAuth() async {
    final user = authService.user;

    if (user == null) {
      return;
    }

    _fanBalance =
        _toDouble(
          user['fanBalance'],
        );

    _afamBalance =
        _toDouble(
          user['afamBalance'],
        );

    _miningRate =
        _toDouble(
          user['miningRate'],
          fallback: 0.2,
        );

    _adBoost =
        _toDouble(
          user['adBoost'],
        );

    _activeReferrals =
        _toInt(
          user['activeReferrals'],
        );

    _dailyAdsWatched =
        _toInt(
          user['dailyAdsWatched'],
        );

    _miningActive =
        user['miningActive'] == true;

    _miningStartedAt =
        _parseDate(
          user['miningStartedAt'],
        );

    _miningEndsAt =
        _parseDate(
          user['miningEndsAt'],
        );

    _updateRemaining();

    await _saveToStorage();

    notifyListeners();
  }

  // ==========================================================
  // REFRESH DASHBOARD
  // ==========================================================

  Future<bool> refreshDashboard() async {
    if (!authService.isAuthenticated) {
      return false;
    }

    try {
      final data =
          await authService.getDashboard();

      if (data == null) {
        return false;
      }

      if (data['user'] is Map) {
        await syncFromAuth();
      }

      _setError(null);

      return true;
    } catch (error) {
      debugPrint(
        'REFRESH DASHBOARD ERROR: $error',
      );

      return false;
    }
  }

  // ==========================================================
  // START MINING
  // ==========================================================

  Future<bool> startMining() async {
    if (!authService.isAuthenticated) {
      _setError(
        'Please log in first.',
      );

      return false;
    }

    if (_miningActive) {
      _setError(
        'Mining is already active.',
      );

      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final result =
          await authService.startMining();

      if (result == null) {
        return false;
      }

      _miningActive = true;

      final mining =
          result['mining'];

      if (mining is Map) {
        _miningStartedAt =
            _parseDate(
              mining['startedAt'],
            );

        _miningEndsAt =
            _parseDate(
              mining['endsAt'],
            );

        _miningRate =
            _toDouble(
              mining['miningRate'],
              fallback: _miningRate,
            );
      }

      _updateRemaining();

      await _saveToStorage();

      notifyListeners();

      return true;
    } catch (error) {
      _setError(
        'Could not start mining.',
      );

      debugPrint(
        'START MINING STATE ERROR: $error',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // CLAIM MINING
  // ==========================================================

  Future<bool> claimMining() async {
    if (!authService.isAuthenticated) {
      _setError(
        'Please log in first.',
      );

      return false;
    }

    if (!_miningActive) {
      _setError(
        'Mining is not active.',
      );

      return false;
    }

    if (_miningEndsAt != null &&
        DateTime.now().isBefore(
          _miningEndsAt!,
        )) {
      _setError(
        'Mining session has not ended yet.',
      );

      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final result =
          await authService.claimMining();

      if (result == null) {
        return false;
      }

      _fanBalance =
          _toDouble(
            result['fanBalance'],
            fallback: _fanBalance,
          );

      _miningActive = false;

      _miningStartedAt = null;

      _miningEndsAt = null;

      _dailyAdsWatched = 0;

      _adBoost = 0.0;

      _miningRate =
          baseMiningRate +
          referralBoost;

      await _saveToStorage();

      notifyListeners();

      return true;
    } catch (error) {
      _setError(
        'Could not claim mining reward.',
      );

      debugPrint(
        'CLAIM MINING STATE ERROR: $error',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // REWARDED AD
  // ==========================================================

  Future<bool> watchRewardedAd() async {
    if (!authService.isAuthenticated) {
      _setError(
        'Please log in first.',
      );

      return false;
    }

    if (!_miningActive) {
      _setError(
        'Start mining before applying an ad boost.',
      );

      return false;
    }

    if (_dailyAdsWatched >= 7) {
      _setError(
        'You have reached the maximum of 7 ads today.',
      );

      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final result =
          await authService.watchRewardedAd();

      if (result == null) {
        return false;
      }

      _dailyAdsWatched =
          _toInt(
            result['adsWatched'],
          );

      _adBoost =
          _toDouble(
            result['adBoost'],
          );

      _miningRate =
          _toDouble(
            result['miningRate'],
            fallback:
                baseMiningRate +
                referralBoost +
                _adBoost,
          );

      await _saveToStorage();

      notifyListeners();

      return true;
    } catch (error) {
      _setError(
        'Could not apply ad reward.',
      );

      debugPrint(
        'WATCH AD STATE ERROR: $error',
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // REFERRALS
  // ==========================================================

  Future<Map<String, dynamic>?> loadReferrals() async {
    if (!authService.isAuthenticated) {
      _setError(
        'Please log in first.',
      );

      return null;
    }

    try {
      final result =
          await authService.getReferrals();

      if (result == null) {
        return null;
      }

      _activeReferrals =
          _toInt(
            result['activeReferrals'],
          );

      _miningRate =
          _toDouble(
            result['miningRate'],
            fallback:
                baseMiningRate +
                referralBoost +
                _adBoost,
          );

      await _saveToStorage();

      notifyListeners();

      return result;
    } catch (error) {
      _setError(
        'Could not load referrals.',
      );

      return null;
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    _timer?.cancel();

    await authService.logout();

    _reset();

    await _clearStorage();

    notifyListeners();
  }

  // ==========================================================
  // REFRESH EVERYTHING
  // ==========================================================

  Future<void> refresh() async {
    if (!authService.isAuthenticated) {
      return;
    }

    _setLoading(true);

    try {
      await authService.refreshUser();

      await syncFromAuth();

      await refreshDashboard();
    } catch (error) {
      debugPrint(
        'APP STATE REFRESH ERROR: $error',
      );
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ==========================================================
  // TIMER
  // ==========================================================

  void _startTimer() {
    _timer?.cancel();

    _updateRemaining();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _updateRemaining();
      },
    );
  }

  void _updateRemaining() {
    if (!_miningActive ||
        _miningEndsAt == null) {
      _remaining = Duration.zero;
      notifyListeners();
      return;
    }

    final now = DateTime.now();

    if (now.isBefore(
      _miningEndsAt!,
    )) {
      _remaining =
          _miningEndsAt!.difference(now);
    } else {
      _remaining = Duration.zero;

      if (_miningActive) {
        _miningActive = false;
        notifyListeners();
      }
    }
  }

  // ==========================================================
  // LOCAL STORAGE
  // ==========================================================

  static const String _fanBalanceKey =
      'pfn_fan_balance';

  static const String _afamBalanceKey =
      'pfn_afam_balance';

  static const String _miningRateKey =
      'pfn_mining_rate';

  static const String _adBoostKey =
      'pfn_ad_boost';

  static const String _activeReferralsKey =
      'pfn_active_referrals';

  static const String _dailyAdsKey =
      'pfn_daily_ads';

  static const String _miningActiveKey =
      'pfn_mining_active';

  static const String _miningStartedKey =
      'pfn_mining_started';

  static const String _miningEndsKey =
      'pfn_mining_ends';

  Future<void> _saveToStorage() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setDouble(
      _fanBalanceKey,
      _fanBalance,
    );

    await prefs.setDouble(
      _afamBalanceKey,
      _afamBalance,
    );

    await prefs.setDouble(
      _miningRateKey,
      _miningRate,
    );

    await prefs.setDouble(
      _adBoostKey,
      _adBoost,
    );

    await prefs.setInt(
      _activeReferralsKey,
      _activeReferrals,
    );

    await prefs.setInt(
      _dailyAdsKey,
      _dailyAdsWatched,
    );

    await prefs.setBool(
      _miningActiveKey,
      _miningActive,
    );

    if (_miningStartedAt != null) {
      await prefs.setString(
        _miningStartedKey,
        _miningStartedAt!
            .toIso8601String(),
      );
    } else {
      await prefs.remove(
        _miningStartedKey,
      );
    }

    if (_miningEndsAt != null) {
      await prefs.setString(
        _miningEndsKey,
        _miningEndsAt!
            .toIso8601String(),
      );
    } else {
      await prefs.remove(
        _miningEndsKey,
      );
    }
  }

  Future<void> _loadFromStorage() async {
    final prefs =
        await SharedPreferences.getInstance();

    _fanBalance =
        prefs.getDouble(
          _fanBalanceKey,
        ) ??
        0.0;

    _afamBalance =
        prefs.getDouble(
          _afamBalanceKey,
        ) ??
        0.0;

    _miningRate =
        prefs.getDouble(
          _miningRateKey,
        ) ??
        0.2;

    _adBoost =
        prefs.getDouble(
          _adBoostKey,
        ) ??
        0.0;

    _activeReferrals =
        prefs.getInt(
          _activeReferralsKey,
        ) ??
        0;

    _dailyAdsWatched =
        prefs.getInt(
          _dailyAdsKey,
        ) ??
        0;

    _miningActive =
        prefs.getBool(
          _miningActiveKey,
        ) ??
        false;

    _miningStartedAt =
        _parseDate(
          prefs.getString(
            _miningStartedKey,
          ),
        );

    _miningEndsAt =
        _parseDate(
          prefs.getString(
            _miningEndsKey,
          ),
        );

    _updateRemaining();
  }

  Future<void> _clearStorage() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _fanBalanceKey,
    );

    await prefs.remove(
      _afamBalanceKey,
    );

    await prefs.remove(
      _miningRateKey,
    );

    await prefs.remove(
      _adBoostKey,
    );

    await prefs.remove(
      _activeReferralsKey,
    );

    await prefs.remove(
      _dailyAdsKey,
    );

    await prefs.remove(
      _miningActiveKey,
    );

    await prefs.remove(
      _miningStartedKey,
    );

    await prefs.remove(
      _miningEndsKey,
    );
  }

  // ==========================================================
  // RESET
  // ==========================================================

  void _reset() {
    _fanBalance = 0.0;

    _afamBalance = 0.0;

    _miningRate = 0.2;

    _adBoost = 0.0;

    _activeReferrals = 0;

    _dailyAdsWatched = 0;

    _miningActive = false;

    _miningStartedAt = null;

    _miningEndsAt = null;

    _remaining = Duration.zero;

    _error = null;
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  double _toDouble(
    dynamic value, {
    double fallback = 0.0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        fallback;
  }

  int _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  void _setLoading(
    bool value,
  ) {
    _loading = value;
    notifyListeners();
  }

  void _setError(
    String? value,
  ) {
    _error = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
