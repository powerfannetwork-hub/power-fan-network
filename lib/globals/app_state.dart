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

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refresh() async {
    final currentUser =
        SupabaseService.client.auth.currentUser;

    if (currentUser == null) {
      _clearState();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final profile =
          await MiningService.instance.getProfile();

      if (profile != null) {
        _user = profile;

        _fanBalance = _toDouble(
          profile['fan_balance'],
        );

        _afamBalance = _toDouble(
          profile['afam_balance'],
        );
      }

      final mining =
          await MiningService.instance.getActiveMining();

      /*
       * IMPORTANT:
       *
       * Supabase is authoritative.
       *
       * We do NOT compare miningEndsAt with
       * DateTime.now() here.
       *
       * This prevents an incorrect phone date/time
       * from changing the mining state.
       */
      _miningActive =
          mining['mining_active'] == true ||
          mining['active'] == true;

      _miningEndsAt = _parseDateTime(
        mining['ends_at'] ??
            mining['end_time'] ??
            mining['expires_at'],
      );

      try {
        final rate =
            await MiningService.instance
                .getUserMiningRate();

        if (rate > 0) {
          _miningRate = rate;
        }
      } catch (_) {}
    } catch (_) {
      /*
       * Kada connection ya samu matsala,
       * a bar state na baya ba tare da crash ba.
       */
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // START MINING
  // ============================================================

  Future<void> startMining() async {
    if (_actionLoading) {
      return;
    }

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

  // ============================================================
  // CLAIM MINING
  // ============================================================

  Future<void> claimMining() async {
    if (_actionLoading) {
      return;
    }

    _actionLoading = true;
    notifyListeners();

    try {
      final result =
          await MiningService.instance.claimMining();

      final earned =
          _extractEarned(result);

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

  // ============================================================
  // REFRESH MINING
  // ============================================================

  Future<void> refreshMining() async {
    try {
      final mining =
          await MiningService.instance.getActiveMining();

      /*
       * Server state only.
       *
       * No DateTime.now() comparison here.
       */
      _miningActive =
          mining['mining_active'] == true ||
          mining['active'] == true;

      _miningEndsAt = _parseDateTime(
        mining['ends_at'] ??
            mining['end_time'] ??
            mining['expires_at'],
      );

      final rate =
          await MiningService.instance
              .getUserMiningRate();

      if (rate > 0) {
        _miningRate = rate;
      }

      notifyListeners();
    } catch (_) {}
  }

  // ============================================================
  // REFRESH BALANCE
  // ============================================================

  Future<void> refreshBalance() async {
    try {
      final profile =
          await MiningService.instance.getProfile();

      if (profile == null) {
        return;
      }

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

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await SupabaseService.client.auth.signOut();
    } finally {
      _clearState();
    }
  }

  // ============================================================
  // CLEAR
  // ============================================================

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

  // ============================================================
  // EXTRACT EARNED
  // ============================================================

  double _extractEarned(
    Map<String, dynamic> result,
  ) {
    final value =
        result['earned'] ??
        result['reward'] ??
        result['reward_fan'] ??
        result['amount'] ??
        result['fan_earned'] ??
        0;

    return _toDouble(value);
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }
}
