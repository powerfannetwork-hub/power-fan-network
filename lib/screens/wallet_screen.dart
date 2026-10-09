import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import '../services/levelplay_ads_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color background = Color(0xFFF8F8FC);
  static const double fanPerAfam = 100.0;
  static const int maxDailyMigrations = 2;

  final ProfileService _profileService = ProfileService.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final LevelPlayAdsService _levelPlay = LevelPlayAdsService.instance;

  final TextEditingController _usernameController =
      TextEditingController();
  final TextEditingController _amountController =
      TextEditingController();

  double _fanBalance = 0;
  double _afamBalance = 0;

  bool _loading = true;
  bool _working = false;
  bool _migrationOpen = false;
  bool _kycVerified = false;
  bool _streaksComplete = false;

  int _checkinStreak = 0;
  int _boostStreak = 0;
  int _migrationsToday = 0;

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring(11)
        : message;
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? Colors.red.shade700 : deepPurple,
        ),
      );
  }

  Future<void> _loadWallet() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final balances = await _profileService.getBalances();

      Map<String, dynamic> migrationStatus = {};
      List<Map<String, dynamic>> history = [];

      try {
        final response =
            await _supabase.rpc('get_migration_status');

        if (response is Map) {
          migrationStatus = Map<String, dynamic>.from(response);
        }
      } catch (e) {
        debugPrint('Migration status could not be loaded: $e');
      }

      try {
        final response = await _supabase.rpc(
          'get_afam_wallet_transactions',
          params: {'p_limit': 50},
        );

        if (response is Map && response['transactions'] is List) {
          history = (response['transactions'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (e) {
        debugPrint('Wallet history could not be loaded: $e');
      }

      if (!mounted) return;

      setState(() {
        _fanBalance = balances['fan'] ?? 0;
        _afamBalance = balances['afam'] ?? 0;

        _migrationOpen =
            migrationStatus['migration_open'] == true ||
            migrationStatus['available'] == true;

        _kycVerified =
            migrationStatus['kyc_verified'] == true ||
            migrationStatus['kyc_status'] == 'verified';

        _checkinStreak =
            _toInt(migrationStatus['kyc_checkin_streak']);
        _boostStreak =
            _toInt(migrationStatus['kyc_boost_streak']);

        _streaksComplete =
            _checkinStreak >= 30 && _boostStreak >= 30;

        _migrationsToday =
            _toInt(migrationStatus['migrations_today']);

        _transactions = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _message(_cleanError(e), error: true);
    }
  }

  Future<void> _migrateFan() async {
    if (_working) return;

    if (!_migrationOpen) {
      _message('FAN to AFAM migration is not open yet.', error: true);
      return;
    }

    if (!_kycVerified || !_streaksComplete) {
      _message(
        'You need verified KYC, 30 Daily Check-ins and 30 Daily Boosts.',
        error: true,
      );
      return;
    }

    if (_migrationsToday >= maxDailyMigrations) {
      _message('You have reached the limit of 2 migrations today.',
          error: true);
      return;
    }

    if (_fanBalance < fanPerAfam) {
      _message('You need at least 100 FAN to convert to AFAM.',
          error: true);
      return;
    }

    setState(() => _working = true);

    try {
      // Create a pending ad-reward request on the server first.
      final request = await _supabase.rpc(
        'request_afam_migration_ad',
      );

      if (request is! Map || request['success'] != true) {
        final message = request is Map
            ? (request['message']?.toString() ??
                'Could not request migration ad.')
            : 'Could not request migration ad.';

        _message(message, error: true);
        return;
      }

      /*
       * This method will be added when we update
       * levelplay_ads_service.dart in the next step.
       *
       * It must show the AFAM_MIGRATION placement.
       * The app must NOT grant AFAM from the client-side
       * rewarded callback alone. LevelPlay S2S must verify it.
       */
      final shown = await _levelPlay.showMigrationRewardedAd();

      if (!shown) {
        _message(
          'The rewarded ad could not be shown. Please try again.',
          error: true,
        );
        return;
     
