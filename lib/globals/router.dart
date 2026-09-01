// lib/globals/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/auth_page.dart';
import '../pages/home_page.dart';
import '../pages/referral_page.dart';
import '../pages/wallet_page.dart';
import '../pages/settings_page.dart';
import '../pages/notifications_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/home',

    routes: [
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (
          BuildContext context,
          GoRouterState state,
        ) {
          return const AuthPage();
        },
      ),

      GoRoute(
        path: '/home',
        name: 'home',
        builder: (
          BuildContext context,
          GoRouterState state,
        ) {
          return const HomePage();
        },
      ),

      GoRoute(
        path: '/referral',
        name: 'referral',
        builder: (
          BuildContext context,
          GoRouterState state,
        ) {
          return const ReferralPage();
        },
      ),

      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (
          BuildContext context,
          GoRouterState state,
        ) {
          return const WalletPage();
        },
      ),

      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (
          BuildContext context,
          GoRouterState state,
        ) {
          return const SettingsPage();
        },
      ),

      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (
          BuildContext context,
          GoRouterState state,
        ) {
          return const NotificationsPage();
        },
      ),
    ],
  );
}
