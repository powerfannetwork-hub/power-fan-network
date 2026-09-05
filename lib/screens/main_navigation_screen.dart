import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'home_screen.dart';
import 'referral_screen.dart';
import 'wallet_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color background = Color(0xFFF8F8FC);

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const HomeScreen(),
      const ReferralScreen(),
      const WalletScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            7,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                context,
                Icons.home_rounded,
                'home',
                0,
              ),
              _navItem(
                context,
                Icons.people_alt_rounded,
                'referral',
                1,
              ),
              _navItem(
                context,
                Icons.account_balance_wallet_rounded,
                'wallet',
                2,
              ),
              _navItem(
                context,
                Icons.settings_rounded,
                'settings',
                3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String key,
    int index,
  ) {
    final selected = _currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected
                  ? primaryPurple
                  : const Color(0xFF60616C),
            ),
            const SizedBox(height: 3),
            Text(
              AppLocalizations.of(context)
                  .translate(key),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: selected
                    ? primaryPurple
                    : const Color(0xFF60616C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
