// lib/pages/auth_page.dart

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'login_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return const LoginPage();
  }
}
