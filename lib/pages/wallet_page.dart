// lib/pages/wallet_page.dart

import 'package:flutter/material.dart';

import '../globals/app_constants.dart';
import '../globals/app_state.dart';

class WalletPage extends StatelessWidget {
  final AppState appState;

  const WalletPage({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final user = appState.user;

    return Scaffold(
      backgroundColor: const Color(
        AppConstants.lightBackgroundColorValue,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          32,
        ),
        children: [
          _balanceCard(
            context,
            title: 'FAN Balance',
            balance: appState.fanBalance,
            coin: 'FAN',
            icon: Icons.monetization_on_rounded,
          ),
          const SizedBox(height: 16),
          _balanceCard(
            context,
            title: 'AFAM Balance',
            balance: appState.afamBalance,
            coin: 'AFAM',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 20),
          _statusCard(),
          const SizedBox(height: 16),
          _walletInfo(),
          if (user != null) ...[
            const SizedBox(height: 16),
            _accountCard(user),
          ],
        ],
      ),
    );
  }

  Widget _balanceCard(
    BuildContext context, {
    required String title,
    required double balance,
    required String coin,
    required IconData icon,
  }) {
    final isFan = coin == 'FAN';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFan
              ? const [
                  Color(
                    AppConstants.primaryColorValue,
                  ),
                  Color(
                    AppConstants.deepPurpleColorValue,
                  ),
                ]
              : const [
                  Color(0xFF159B61),
                  Color(0xFF087A4A),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isFan
                    ? const Color(
                        AppConstants.primaryColorValue,
                      )
                    : const Color(
                        AppConstants.greenColorValue,
                      ))
                .withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            balance.toStringAsFixed(4),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            coin,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(
                AppConstants.greenColorValue,
              ).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Color(
                AppConstants.greenColorValue,
              ),
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Wallet withdrawals and transfers will become available when the wallet system is enabled.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(
                AppConstants.primaryColorValue,
              ).withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: const Text(
              AppConstants.walletStatus,
              style: TextStyle(
                color: Color(
                  AppConstants.primaryColorValue,
                ),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Your balances',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          _infoRow(
            Icons.monetization_on_rounded,
            'Mining coin',
            'FAN',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.swap_horiz_rounded,
            'Original coin',
            'AFAM',
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.security_rounded,
            'Wallet access',
            'Protected',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: const Color(
            AppConstants.primaryColorValue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _accountCard(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(
              AppConstants.primaryColorValue,
            ).withOpacity(0.10),
            child: Text(
              user.name.isEmpty
                  ? 'F'
                  : user.name
                      .trim()
                      .substring(0, 1)
                      .toUpperCase(),
              style: const TextStyle(
                color: Color(
                  AppConstants.primaryColorValue,
                ),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
