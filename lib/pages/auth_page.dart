// lib/pages/auth_page.dart

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/language_controller.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLogin = true;

  void _switchPage() {
    setState(() {
      _showLogin = !_showLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showLogin
                ? const LoginPage(key: ValueKey('login'))
                : const RegisterPage(key: ValueKey('register')),
          ),

          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Center(
                child: TextButton(
                  onPressed: _switchPage,
                  child: Text(
                    _showLogin
                        ? t.translate('createAccount')
                        : t.translate('alreadyHaveAccount'),
                    style: const TextStyle(
                      color: Color(0xFF3B159B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
