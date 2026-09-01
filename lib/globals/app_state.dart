import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  bool _loading = false;
  double _fanBalance = 0.0;
  bool _miningActive = false;
  Map<String, dynamic>? _user;

  bool get loading => _loading;
  double get fanBalance => _fanBalance;
  bool get miningActive => _miningActive;
  Map<String, dynamic>? get user => _user;

  Future<void> refresh() async {
    try {
      _loading = true; notifyListeners();
      final profile = await ApiService.getProfile();
      _fanBalance = (profile['fan_balance']?? 0).toDouble();
      _miningActive = profile['mining_active']?? false;
      _user = profile;
    } catch(e) {
      // BA MU DA PRINT ANAN. MUN BARI KOSAI
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<void> startMining() async {
    await ApiService.startMining();
    _miningActive = true;
    notifyListeners();
  }

  Future<void> claimMining() async {
    final res = await ApiService.claimMining();
    _fanBalance += res['earned'];
    _miningActive = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _fanBalance = 0;
    _miningActive = 0;
    notifyListeners();
  }
}
