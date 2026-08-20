import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/auth_page.dart';
import '../pages/home_page.dart';
import '../pages/referral_page.dart';
import '../pages/leaderboard_page.dart';
import '../pages/wallet_page.dart';
import '../pages/settings_page.dart';
import '../pages/notifications_page.dart';
import 'app_state.dart';

/// ===============================================================
/// POWER FAN NETWORK - APP ROUTER
/// ===============================================================
/// Wannan file yana kula da duk navigation/routing na application.
/// Kada a canza route names ba tare da an duba sauran files ba.
/// ===============================================================

final GoRouter appRouter = GoRouter(
  initialLocation: '/home-page',

  routes: [
    // =============================================================
    // AUTHENTICATION
    // =============================================================

    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) {
        return const AuthPage();
      },
    ),

    // =============================================================
    // HOME / MINING
    // =============================================================

    GoRoute(
      path: '/home-page',
      name: 'home',
      builder: (context, state) {
        final appState = AppState.of(
          context,
          listen: true,
        );

        // Idan user bai shiga account ba,
        // za a mayar da shi zuwa Auth page.
        if (!appState.isAuthenticated) {
          return const AuthPage();
        }

        return const HomePage();
      },
    ),

    // =============================================================
    // REFERRAL
    // =============================================================

    GoRoute(
      path: '/referral',
      name: 'referral',
      builder: (context, state) {
        return const ReferralPage();
      },
    ),

    // =============================================================
    // LEADERBOARD
    // =============================================================

    GoRoute(
      path: '/leaderboard',
      name: 'leaderboard',
      builder: (context, state) {
        return const LeaderboardPage();
      },
    ),

    // =============================================================
    // WALLET
    // =============================================================

    GoRoute(
      path: '/wallet',
      name: 'wallet',
      builder: (context, state) {
        return const WalletPage();
      },
    ),

    // =============================================================
    // SETTINGS
    // =============================================================

    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) {
        return const SettingsPage();
      },
    ),

    // =============================================================
    // NOTIFICATIONS
    // =============================================================

    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) {
        return const NotificationsPage();
      },
    ),
  ],

  // ===============================================================
  // ERROR PAGE
  // ===============================================================

  errorBuilder: (context, state) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('POWER FAN NETWORK'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFF5E17EB),
              ),

              const SizedBox(height: 16),

              const Text(
                'Page not found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                state.uri.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  context.go('/home-page');
                },
                child: const Text('GO HOME'),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
