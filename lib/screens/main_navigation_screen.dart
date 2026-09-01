import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pages/home_page.dart'; // GYARA: KARA ../
import '../pages/referral_page.dart';
import '../pages/wallet_page.dart';
import '../pages/settings_page.dart';
import '../services/auth_service.dart';
import '../globals/app_state.dart';

class MainNavigationScreen extends StatefulWidget { const MainNavigationScreen({super.key}); @override State<MainNavigationScreen> createState() => _MainNavigationScreenState(); }
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0; late final List<Widget> _screens;
  @override void initState() { super.initState(); final auth = context.read<AuthService>(); final app = context.read<AppState>(); app.refresh();
    _screens = [const HomePage(), const ReferralPage(), WalletPage(appState: app), SettingsPage(authService: auth, appState: app)];
  }
  @override Widget build(BuildContext context) {
    return Scaffold(body: _screens[_currentIndex], bottomNavigationBar: BottomNavigationBar(currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i), selectedItemColor: Color(0xFF3B159B), items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"), BottomNavigationBarItem(icon: Icon(Icons.people), label: "Referral"),
      BottomNavigationBarItem(icon: Icon(Icons.wallet), label: "Wallet"), BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
    ]));
  }
}
