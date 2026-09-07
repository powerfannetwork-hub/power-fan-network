import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color background = Color(0xFFF8F8FC);

  final ProfileService _profileService = ProfileService.instance;

  double _fanBalance = 0.0;
  double _afamBalance = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final balances = await _profileService.getBalances();

      if (!mounted) return;

      setState(() {
        _fanBalance = _toDouble(balances['fan']);
        _afamBalance = _toDouble(balances['afam']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatBalance(double value) {
    return value.toStringAsFixed(4);
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Colors.red.shade700 : deepPurple,
        ),
      );
  }

  void _showComingSoon(String feature) {
    _showMessage('$feature is coming soon.');
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _loadBalances,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryPurple,
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWalletHeader(),
                    const SizedBox(height: 18),
                    _buildFanCard(),
                    const SizedBox(height: 14),
                    _buildAfamCard(),
                    const SizedBox(height: 18),
                    _buildSolanaCard(),
                    const SizedBox(height: 18),
                    _buildActionsCard(),
                  ],
                ),
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
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primaryPurple,
            deepPurple,
          ],
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
            child: Icon(
              icon,
              color: primaryPurple,
              size: 27,
            ),
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

  Widget _buildSolanaCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryPurple.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: primaryPurple,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solana Wallet',
                  style: TextStyle(
                    color: deepPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Wallet connection and token transactions '
                  'will be available soon.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.lock_outline_rounded,
            color: Colors.black38,
            size: 21,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
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
          const Text(
            'Wallet Actions',
            style: TextStyle(
              color: deepPurple,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _actionTile(
            icon: Icons.send_rounded,
            title: 'Withdraw FAN',
            subtitle: 'Withdrawals will be available soon.',
            onTap: () => _showComingSoon('FAN withdrawal'),
          ),
          const Divider(height: 1),
          _actionTile(
            icon: Icons.swap_horiz_rounded,
            title: 'Transactions',
            subtitle: 'Transaction history will be available soon.',
            onTap: () => _showComingSoon('Transaction history'),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F2FF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: primaryPurple,
          size: 23,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: deepPurple,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.black38,
        size: 16,
      ),
    );
  }
}
