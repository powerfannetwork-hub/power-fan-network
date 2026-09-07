import 'dart:async';

import 'package:flutter/material.dart';

import '../components/boost_ads_card.dart';
import '../localization/app_localizations.dart';
import '../pages/kyc_page.dart';
import '../services/kyc_service.dart';
import '../services/mining_service.dart';
import '../services/social_task_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);

  static const Duration miningDuration = Duration(hours: 24);

  final MiningService _mining = MiningService.instance;
  final SocialTaskService _social = SocialTaskService();
  final KycService _kyc = KycService();

  Timer? _timer;

  bool _loading = true;
  bool _busy = false;
  bool _isMining = false;
  bool _canClaim = false;

  double _fan = 0;
  double _afam = 0;
  double _rate = 0.20;

  DateTime? _startedAt;
  DateTime? _endsAt;

  Duration _remaining = Duration.zero;
  Duration _elapsed = Duration.zero;

  List<DailySocialTask> _tasks = [];

  KycStatus _kycStatus = KycStatus.initial();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _t(
    String key, [
    String fallback = '',
  ]) {
    final value = AppLocalizations.of(context).translate(key);

    if (value.isEmpty || value == key) {
      return fallback.isEmpty ? key : fallback;
    }

    return value;
  }

  // ============================================================
  // LOAD EVERYTHING
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      await Future.wait([
        _loadProfile(),
        _loadMining(),
        _loadTasks(),
        _loadKyc(),
      ]);
    } catch (e) {
      _message(_error(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final data = await _mining.getProfile();

    if (!mounted) return;

    setState(() {
      _fan = _num(data['fan_balance']);
      _afam = _num(data['afam_balance']);
    });
  }

  // ============================================================
  // KYC
  // ============================================================

  Future<void> _loadKyc() async {
    try {
      final status = await _kyc.getStatus();

      if (!mounted) return;

      setState(() {
        _kycStatus = status;
      });
    } catch (_) {
      /*
       * KYC should not stop the HomeScreen from loading.
       *
       * If the KYC RPC has a temporary network/session problem,
       * keep the last known status instead of breaking the whole
       * HomeScreen.
       */
    }
  }

  Future<void> _openKyc() async {
    if (_busy) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KycPage(),
      ),
    );

    if (!mounted) return;

    await _loadKyc();
  }

  // ============================================================
  // MINING
  // ============================================================

  Future<void> _loadMining() async {
    final data = await _mining.getActiveMining();
    final serverRate = await _mining.getUserMiningRate();

    final started = _date(
      data['started_at'] ??
          data['start_time'] ??
          data['started'],
    );

    final ends = _date(
      data['ends_at'] ??
          data['end_time'] ??
          data['expires_at'] ??
          data['ended_at'],
    );

    final active =
        data['active'] ??
        data['is_mining'] ??
        data['is_active'] ??
        false;

    final claimable = data['claimable'] ?? false;

    final rate = _num(
      data['rate'] ??
          data['mining_rate'] ??
          serverRate,
    );

    final serverRemaining = _int(
      data['remaining_seconds'],
    );

    final serverElapsed = _int(
      data['elapsed_seconds'],
    );

    if (!mounted) return;

    _timer?.cancel();

    DateTime? finalStarted = started;
    DateTime? finalEnds = ends;

    if (finalStarted == null && finalEnds != null) {
      finalStarted = finalEnds.subtract(miningDuration);
    }

    if (finalEnds == null && finalStarted != null) {
      finalEnds = finalStarted.add(miningDuration);
    }

    setState(() {
      _isMining = active == true
