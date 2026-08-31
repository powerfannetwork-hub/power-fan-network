// lib/globals/app_state.dart

import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  // ============================================================
  // USER
  // ============================================================

  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  void setUser(Map<String, dynamic>? value) {
    _user = value;
    notifyListeners();
  }

  // ============================================================
  // AUTH
  // ============================================================

  bool _authenticated = false;

  bool get authenticated => _authenticated;

  void setAuthenticated(bool value) {
    _authenticated = value;
    notifyListeners();
  }

  // ============================================================
  // FAN / AFAM BALANCE
  // ============================================================

  double _fanBalance = 0.0;
  double _afamBalance = 0.0;

  double get fanBalance => _fanBalance;
  double get afamBalance => _afamBalance;

  void setBalances({
    required double fanBalance,
    required double afamBalance,
  }) {
    _fanBalance = fanBalance;
    _afamBalance = afamBalance;
    notifyListeners();
  }

  // ============================================================
  // MINING
  // ============================================================

  bool _miningActive = false;

  double _miningRate = 0.2;

  double _adBoost = 0.0;

  int _dailyAdsWatched = 0;

  DateTime? _miningStartedAt;

  DateTime? _miningEndsAt;

  bool get miningActive => _miningActive;

  double get miningRate => _miningRate;

  double get adBoost => _adBoost;

  int get dailyAdsWatched => _dailyAdsWatched;

  DateTime? get miningStartedAt => _miningStartedAt;

  DateTime? get miningEndsAt => _miningEndsAt;

  void updateMining({
    required bool active,
    required double rate,
    required double adBoost,
    required int adsWatched,
    DateTime? startedAt,
    DateTime? endsAt,
  }) {
    _miningActive = active;
    _miningRate = rate;
    _adBoost = adBoost;
    _dailyAdsWatched = adsWatched;
    _miningStartedAt = startedAt;
    _miningEndsAt = endsAt;

    notifyListeners();
  }

  // ============================================================
  // REFERRALS
  // ============================================================

  int _activeReferrals = 0;

  String _referralCode = '';

  String? _referredBy;

  int get activeReferrals => _activeReferrals;

  String get referralCode => _referralCode;

  String? get referredBy => _referredBy;

  void updateReferralData({
    required int activeReferrals,
    required String referralCode,
    String? referredBy,
  }) {
    _activeReferrals = activeReferrals;
    _referralCode = referralCode;
    _referredBy = referredBy;

    notifyListeners();
  }

  // ============================================================
  // DAILY CHECK-IN / KYC
  // ============================================================

  int _consecutiveCheckIns = 0;

  bool _kyc1Eligible = false;

  bool _kyc1Verified = false;

  bool _kyc2Eligible = false;

  bool _kyc2Verified = false;

  bool _kyc3Verified = false;

  int get consecutiveCheckIns => _consecutiveCheckIns;

  bool get kyc1Eligible => _kyc1Eligible;

  bool get kyc1Verified => _kyc1Verified;

  bool get kyc2Eligible => _kyc2Eligible;

  bool get kyc2Verified => _kyc2Verified;

  bool get kyc3Verified => _kyc3Verified;

  void updateKycData({
    required int consecutiveCheckIns,
    required bool kyc1Eligible,
    required bool kyc1Verified,
    required bool kyc2Eligible,
    required bool kyc2Verified,
    required bool kyc3Verified,
  }) {
    _consecutiveCheckIns = consecutiveCheckIns;

    _kyc1Eligible = kyc1Eligible;

    _kyc1Verified = kyc1Verified;

    _kyc2Eligible = kyc2Eligible;

    _kyc2Verified = kyc2Verified;

    _kyc3Verified = kyc3Verified;

    notifyListeners();
  }

  // ============================================================
  // LOADING
  // ============================================================

  bool _loading = false;

  bool get loading => _loading;

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  // ============================================================
  // ERROR
  // ============================================================

  String? _error;

  String? get error => _error;

  void setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    _user = null;

    _authenticated = false;

    _fanBalance = 0.0;
    _afamBalance = 0.0;

    _miningActive = false;
    _miningRate = 0.2;
    _adBoost = 0.0;
    _dailyAdsWatched = 0;

    _miningStartedAt = null;
    _miningEndsAt = null;

    _activeReferrals = 0;
    _referralCode = '';
    _referredBy = null;

    _consecutiveCheckIns = 0;

    _kyc1Eligible = false;
    _kyc1Verified = false;

    _kyc2Eligible = false;
    _kyc2Verified = false;

    _kyc3Verified = false;

    _loading = false;
    _error = null;

    notifyListeners();
  }
}
