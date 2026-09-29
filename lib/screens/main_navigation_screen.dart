import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'daily_spin_screen.dart';
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

  static const Color primaryPurple =
      Color(0xFF3B159B);

  static const Color background =
      Color(0xFFF8F8FC);

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const HomeScreen(),
      const DailySpinScreen(),
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
      bottomNavigationBar:
          _buildBottomNavigationBar(context),
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
            color: Colors.black.withValues(
              alpha: 0.07,
            ),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            4,
            8,
            4,
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
                Icons.casino_rounded,
                'Daily Spin',
                1,
              ),
              _navItem(
                context,
                Icons.people_alt_rounded,
                'referral',
                2,
              ),
              _navItem(
                context,
                Icons.account_balance_wallet_rounded,
                'wallet',
                3,
              ),
              _navItem(
                context,
                Icons.settings_rounded,
                'settings',
                4,
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
    final selected =
        _currentIndex == index;

    final isDailySpin =
        key == 'Daily Spin';

    final label = isDailySpin
        ? 'Daily Spin'
        : AppLocalizations.of(context)
            .translate(key);

    return Expanded(
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 27,
                color: selected
                    ? primaryPurple
                    : const Color(
                        0xFF60616C,
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: selected
                      ? primaryPurple
                      : const Color(
                          0xFF60616C,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
