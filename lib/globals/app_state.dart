import 'package:flutter/foundation.dart';
import '../services/mining_service.dart';
import '../services/supabase_service.dart';

class AppState extends ChangeNotifier {
  bool _loading = false;
  bool _actionLoading = false;

  double _fanBalance = 0.0;
  double _afamBalance = 0.0;
  double _miningRate = 0.20;

  bool _miningActive = false;
  DateTime? _miningEndsAt;

  Map<String, dynamic>? _user;

  bool get loading => _loading;
  bool get actionLoading => _actionLoading;

  double get fanBalance => _fanBalance;
  double get afamBalance => _afamBalance;
  double get miningRate => _miningRate;

  bool get miningActive => _miningActive;
  DateTime? get miningEndsAt => _miningEndsAt;

  Map<String, dynamic>? get user => _user;

  Future<void> refresh() async {
    final currentUser = SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      _clearState();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final profile = await MiningService.instance.getProfile();

      _user = profile;

      _fanBalance = _toDouble(
        profile['fan_balance'],
      );

      _afamBalance = _toDouble(
        profile['afam_balance'],
      );

      final mining = await MiningService.instance.getActiveMining();

      _miningActive =
          mining['is_mining'] == true ||
          mining['is_active'] == true;

      _miningEndsAt = _parseDateTime(
        mining['ends_at'] ??
            mining['end_time'] ??
            mining['expires_at'],
      );

      if (_miningActive &&
          _miningEndsAt != null &&
          DateTime.now().isAfter(_miningEndsAt!)) {
        _miningActive = false;
      }

      _miningRate =
          await MiningService.instance.getUserMiningRate();
    } catch (_) {
      // Kada connection ya samu matsala,
      // a bar state na baya ba tare da crash ba.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> startMining() async {
    if (_actionLoading) return;

    _actionLoading = true;
    notifyListeners();

    try {
      await MiningService.instance.startMining();

      await refresh();
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> claimMining() async {
    if (_actionLoading) return;

    _actionLoading = true;
    notifyListeners();

    try {
      final result =
          await MiningService.instance.claimMining();

      final earned = _extractEarned(result);

      if (earned > 0) {
        _fanBalance += earned;
      }

      _miningActive = false;
      _miningEndsAt = null;

      await refresh();
    } finally {
      _actionLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMining() async {
    try {
      final mining =
          await MiningService.instance.getActiveMining();

      _miningActive =
          mining['is_mining'] == true ||
          mining['is_active'] == true;

      _miningEndsAt = _parseDateTime(
        mining['ends_at'] ??
            mining['end_time'] ??
            mining['expires_at'],
      );

      _miningRate =
          await MiningService.instance.getUserMiningRate();

      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshBalance() async {
    try {
      final profile =
          await MiningService.instance.getProfile();

      _user = profile;

      _fanBalance = _toDouble(
        profile['fan_balance'],
      );

      _afamBalance = _toDouble(
        profile['afam_balance'],
      );

      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await SupabaseService.client.auth.signOut();
    } finally {
      _clearState();
    }
  }

  void _clearState() {
    _loading = false;
    _actionLoading = false;
    _fanBalance = 0.0;
    _afamBalance = 0.0;
    _miningRate = 0.20;
    _miningActive = false;
    _miningEndsAt = null;
    _user = null;
    notifyListeners();
  }

  double _extractEarned(Map<String, dynamic> result) {
    final value =
        result['earned'] ??
        result['reward'] ??
        result['reward_fan'] ??
        result['amount'] ??
        result['fan_earned'] ??
        0;

    return _toDouble(value);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }
}
