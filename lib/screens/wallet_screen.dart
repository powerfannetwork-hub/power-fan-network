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

        // Use the exact fields returned by get_migration_status().
        _migrationOpen = migrationStatus['migration_open'] == true;

        _kycVerified = migrationStatus['kyc_verified'] == true;

        _checkinStreak =
            _toInt(migrationStatus['kyc_checkin_streak']);
        _boostStreak =
            _toInt(migrationStatus['kyc_boost_streak']);

        _streaksComplete =
            _checkinStreak >= 30 && _boostStreak >= 30;

        // The RPC exposes this count as conversions_today.
        _migrationsToday =
            _toInt(migrationStatus['conversions_today']);

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

      // The client callback only tells us the ad finished. The server-side
      // reward verification and the migration RPC decide whether conversion
      // is allowed; the client never adds AFAM directly.
      final shown = await _levelPlay.showMigrationRewardedAd();

      if (!shown) {
        _message(
          'The rewarded ad could not be shown. Please try again.',
          error: true,
        );
        return;
      }

      var migrationSucceeded = false;
      var verificationPending = false;
      String? terminalMessage;

      // S2S verification may arrive a little after the ad callback. Retry the
      // server RPC for a short period; only a successful RPC counts as success.
      for (var attempt = 0; attempt < 12; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 5));
        }

        final result = await _supabase.rpc('migrate_fan_to_afam');
        if (result is Map) {
          final success = result['success'] == true;
          final message = (result['message']?.toString() ?? '').trim();

          if (success) {
            migrationSucceeded = true;
            terminalMessage = message.isNotEmpty
                ? message
                : 'FAN to AFAM migration completed successfully.';
            break;
          }

          final normalized = message.toLowerCase();
          verificationPending = normalized.contains('pending') ||
              normalized.contains('not verified') ||
              normalized.contains('not yet') ||
              normalized.contains('reward not found') ||
              normalized.contains('reward has not') ||
              normalized.contains('waiting for') ||
              normalized.contains('ad reward');

          if (!verificationPending) {
            terminalMessage = message.isNotEmpty
                ? message
                : 'Migration could not be completed. Please refresh and try again.';
            break;
          }
        } else {
          terminalMessage =
              'Unexpected migration response from the server. Please refresh your wallet.';
          break;
        }
      }

      if (migrationSucceeded) {
        _message(terminalMessage!);
      } else if (verificationPending) {
        _message(
          'Ad finished, but secure reward verification is still pending. '
          'Please refresh your wallet and try again shortly.',
        );
      } else {
        _message(
          terminalMessage ?? 'Migration could not be completed. Please try again.',
          error: true,
        );
      }
    } catch (e) {
      _message(_cleanError(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _working = false);
        await _loadWallet();
      }
    }
  }

  Future<void> _sendAfam() async {
    if (_working) return;

    final username = _usernameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (username.length < 3) {
      _message('Enter a valid recipient username.', error: true);
      return;
    }

    if (amount == null || !amount.isFinite || amount <= 0) {
      _message('Enter a valid AFAM amount.', error: true);
      return;
    }

    if (amount > _afamBalance) {
      _message('Insufficient AFAM balance.', error: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm AFAM Transfer'),
        content: Text(
          'Send ${amount.toStringAsFixed(4)} AFAM to @$username?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = true);

    try {
      final response = await _supabase.rpc(
        'send_afam_by_username',
        params: {
          'p_username': username,
          'p_amount': amount,
        },
      );

      if (response is Map && response['success'] == true) {
        _usernameController.clear();
        _amountController.clear();

        _message(
          response['message']?.toString() ??
              'AFAM transfer completed successfully.',
        );
      } else {
        final message = response is Map
            ? response['message']?.toString() ??
                'AFAM transfer failed.'
            : 'AFAM transfer failed.';

        _message(message, error: true);
      }
    } catch (e) {
      _message(_cleanError(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _working = false);
        await _loadWallet();
      }
    }
  }

  Future<void> _openTransferDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Send AFAM',
                    style: TextStyle(
                      color: deepPurple,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Available balance: ${_formatBalance(_afamBalance)} AFAM',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Recipient username',
                      hintText: 'Enter username',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'AFAM amount',
                      hintText: '0.0000',
                      prefixIcon: Icon(Icons.diamond_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _working
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _sendAfam();
                          },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Confirm Transfer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryPurple,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatBalance(double value) => value.toStringAsFixed(4);

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';

    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: background,
        foregroundColor: deepPurple,
        centerTitle: true,
        title: const Text(
          'Wallet',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _working ? null : _loadWallet,
            tooltip: 'Refresh wallet',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _loadWallet,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryPurple),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  _buildWalletHeader(),
                  const SizedBox(height: 18),
                  _buildFanCard(),
                  const SizedBox(height: 14),
                  _buildAfamCard(),
                  const SizedBox(height: 18),
                  _buildMigrationCard(),
                  const SizedBox(height: 14),
                  _buildTransferCard(),
                  const SizedBox(height: 18),
                  _buildTransactionHistory(),
                ],
              ),
      ),
    );
  }

  Widget _buildWalletHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Wallet',
          style: TextStyle(
            color: deepPurple,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Manage your FAN and AFAM balances.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryPurple, deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FAN BALANCE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatBalance(_fanBalance)} FAN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfamCard() {
    return _balanceCard(
      icon: Icons.diamond_rounded,
      title: 'AFAM BALANCE',
      value: '${_formatBalance(_afamBalance)} AFAM',
    );
  }

  Widget _balanceCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDFF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: primaryPurple, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationCard() {
    final eligible = _migrationOpen &&
        _kycVerified &&
        _streaksComplete &&
        _fanBalance >= fanPerAfam &&
        _migrationsToday < maxDailyMigrations;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryPurple.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.currency_exchange_rounded,
                  color: primaryPurple, size: 25),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'FAN to AFAM Migration',
                  style: TextStyle(
                    color: deepPurple,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Convert 100 FAN into 1 AFAM. Each conversion requires '
            'a completed rewarded ad verified by the server.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _statusRow(
            'Manual KYC',
            _kycVerified ? 'Verified' : 'Not verified',
            _kycVerified,
          ),
          const SizedBox(height: 8),
          _statusRow(
            'Daily Check-ins',
            '$_checkinStreak/30',
            _checkinStreak >= 30,
          ),
          const SizedBox(height: 8),
          _statusRow(
            'Daily Boosts',
            '$_boostStreak/30',
            _boostStreak >= 30,
          ),
          const SizedBox(height: 8),
          _statusRow(
            'Migrations today',
            '$_migrationsToday/$maxDailyMigrations',
            _migrationsToday < maxDailyMigrations,
          ),
          const SizedBox(height: 8),
          _statusRow(
            'Migration status',
            _migrationOpen ? 'Open' : 'Closed',
            _migrationOpen,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working || !eligible ? null : _migrateFan,
              icon: _working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline_rounded),
              label: Text(
                _working ? 'Please wait...' : 'Watch Ad & Convert 100 FAN',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: primaryPurple,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (!_migrationOpen) ...[
            const SizedBox(height: 8),
            const Text(
              'Migration is currently closed by the administrator.',
              style: TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusRow(String title, String value, bool complete) {
    return Row(
      children: [
        Icon(
          complete ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 17,
          color: complete ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: complete ? Colors.green.shade700 : Colors.orange.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildTransferCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.send_rounded, color: primaryPurple, size: 24),
              SizedBox(width: 9),
              Text(
                'AFAM Transfer',
                style: TextStyle(
                  color: deepPurple,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Send AFAM to another user using their username.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _openTransferDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Send AFAM'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryPurple,
                side: const BorderSide(color: primaryPurple),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transaction History',
                  style: TextStyle(
                    color: deepPurple,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _working ? null : _loadWallet,
                tooltip: 'Refresh history',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 38,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No AFAM transactions yet.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._transactions.map(_transactionTile),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> transaction) {
    final type =
        transaction['transaction_type']?.toString() ?? 'transaction';
    final coin = transaction['coin']?.toString() ?? 'AFAM';
    final description =
        transaction['description']?.toString() ?? type;
    final amount = _toDouble(transaction['amount']);
    final date = _formatDate(transaction['created_at']);

    final normalizedType = type.toLowerCase();
    final outgoing = normalizedType.contains('sent') ||
        normalizedType.contains('withdrawal');

    final title = normalizedType == 'migration'
        ? 'FAN to AFAM Migration'
        : normalizedType == 'transfer_sent'
            ? 'AFAM Sent'
            : normalizedType == 'transfer_received'
                ? 'AFAM Received'
                : _titleCase(type.replaceAll('_', ' '));

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: outgoing
            ? Colors.orange.withValues(alpha: 0.12)
            : const Color(0xFFF1EDFF),
        child: Icon(
          outgoing
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          color: outgoing ? Colors.orange.shade800 : primaryPurple,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: deepPurple,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        '$description\n$date',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
          height: 1.4,
        ),
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${outgoing ? '-' : '+'}${amount.toStringAsFixed(4)}',
            style: TextStyle(
              color: outgoing ? Colors.orange.shade800 : Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            coin,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) =>
            '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
