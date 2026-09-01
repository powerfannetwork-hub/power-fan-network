import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  double _fanBalance = 0; double _afamBalance = 0; double _miningRate = 0.2;
  bool _miningActive = false; DateTime? _miningEndsAt;
  int _dailyAdsWatched = 0; int _activeReferrals = 0;
  String? _error; bool _loading = true;

  double get fanBalance => _fanBalance; double get afamBalance => _afamBalance;
  double get miningRate => _miningRate; bool get miningActive => _miningActive;
  int get dailyAdsWatched => _dailyAdsWatched; int get activeReferrals => _activeReferrals;
  String? get error => _error; bool get loading => _loading;
  double get adBoost => _dailyAdsWatched * 0.1; double get referralBoost => _activeReferrals * 0.02;
  bool get canWatchAd => _miningActive && _dailyAdsWatched < 7;
  Duration get remaining => _miningEndsAt == null ? Duration.zero : _miningEndsAt!.difference(DateTime.now());
  String get remainingText => remaining.isNegative ? "00:00:00" : "${remaining.inHours.toString().padLeft(2,'0')}:${(remaining.inMinutes%60).toString().padLeft(2,'0')}:${(remaining.inSeconds%60).toString().padLeft(2,'0')}";

  AppState() { refresh(); }

  Future<void> refresh() async {
    _loading = true; _error = null; notifyListeners();
    try {
      final profile = await ApiService.getProfile();
      if(profile != null) {
        _fanBalance = ApiService._toDouble(profile['fan_balance']);
        _afamBalance = ApiService._toDouble(profile['afam_balance']);
        _miningRate = ApiService._toDouble(profile['mining_rate'], fallback: 0.2);
        _miningActive = profile['mining_active'] == true;
        _miningEndsAt = profile['mining_ends_at'] != null ? DateTime.parse(profile['mining_ends_at']) : null;
        _dailyAdsWatched = ApiService._toInt(profile['daily_ads_watched']);
        _activeReferrals = ApiService._toInt(profile['active_referrals']);
      }
    } catch(e) { _error = e.toString(); }
    _loading = false; notifyListeners();
  }

  Future<bool> startMining() async { try { await ApiService.startMining(); await refresh(); return true; } catch(e){_error=e.toString(); notifyListeners(); return false;}}
  Future<bool> claimMining() async { try { await ApiService.claimMining(); await refresh(); return true; } catch(e){_error=e.toString(); notifyListeners(); return false;}}
  Future<bool> watchRewardedAd() async { try { await ApiService.watchAd(); await refresh(); return true; } catch(e){_error=e.toString(); notifyListeners(); return false;}}
}
