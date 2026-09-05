import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'globals/app_state.dart';
import 'localization/app_localizations.dart';
import 'localization/language_controller.dart';
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
    ),
  );

  // Load the language saved on the device.
  await LanguageController.instance.loadSavedLanguage();

  runApp(const PowerFanApp());
}

class PowerFanApp extends StatelessWidget {
  const PowerFanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
        ChangeNotifierProvider<LanguageController>.value(
          value: LanguageController.instance,
        ),
      ],
      child: const _PowerFanMaterialApp(),
    );
  }
}

class _PowerFanMaterialApp extends StatelessWidget {
  const _PowerFanMaterialApp();

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageController>(
      builder: (context, languageController, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'POWER FAN NETWORK',

          locale: languageController.locale,

          supportedLocales:
              AppLocalizations.supportedLocales,

          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: ThemeData(
            useMaterial3: true,

            scaffoldBackgroundColor:
                const Color(0xFFF8F8FC),

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B159B),
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF241064),
              elevation: 0,
              centerTitle: false,
            ),

            inputDecorationTheme:
                InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,

              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF3B159B),
                  width: 1.5,
                ),
              ),
            ),

            cardTheme: CardThemeData(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
            ),
          ),

          home: const AppRoot(),

          routes: {
            '/home': (_) =>
                const MainNavigationScreen(),
            '/auth': (_) => const AuthPage(),
          },
        );
      },
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  StreamSubscription<AuthState>?
      _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = Supabase
        .instance.client.auth.onAuthStateChange
        .listen(
      (AuthState state) {
        if (!mounted) return;

        if (state.event ==
                AuthChangeEvent.signedIn ||
            state.event ==
                AuthChangeEvent.tokenRefreshed) {
          _loadUserData();
        }

        if (state.event ==
            AuthChangeEvent.signedOut) {
          setState(() {});
        }
      },
    );

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    final session = Supabase
        .instance.client.auth.currentSession;

    if (session == null) {
      setState(() {});
      return;
    }

    try {
      await context.read<AppState>().refresh();
    } catch (_) {
      // Keep the current session if the network
      // is temporarily unavailable.
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
    final session = Supabase
        .instance.client.auth.currentSession;

    if (session == null) {
      return const AuthPage();
    }

    return const MainNavigationScreen();
  }
}
