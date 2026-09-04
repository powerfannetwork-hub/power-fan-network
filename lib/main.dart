import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'globals/app_state.dart';
import 'pages/auth_page.dart';
import 'screens/main_navigation_screen.dart';

const String supabaseUrl =
    'https://fihtqejqpycuvebufjhc.supabase.co';

const String supabasePublishableKey =
    'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      persistSession: true,
    ),
  );

  runApp(const PowerFanApp());
}

class PowerFanApp extends StatelessWidget {
  const PowerFanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'POWER FAN',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F8FC),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B159B),
          ),
        ),
        home: const AppRoot(),
        routes: {
          '/home': (_) => const MainNavigationScreen(),
          '/auth': (_) => const AuthPage(),
        },
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState state) {
        if (!mounted) return;

        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed) {
          _loadUserData();
        }

        if (state.event == AuthChangeEvent.signedOut) {
          setState(() {});
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    final session =
        Supabase.instance.client.auth.currentSession;

    if (session == null) {
      setState(() {});
      return;
    }

    try {
      await context.read<AppState>().refresh();
    } catch (_) {
      // Session may still be valid even if network is temporarily unavailable.
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session =
        Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const AuthPage();
    }

    return const MainNavigationScreen();
  }
}
