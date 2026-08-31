import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';

// ============================================================
// SUPABASE CONFIGURATION
// ============================================================
//
// ZA MU SAUYA WADANNAN DA AINIhin SUPABASE DETAILS
// DAGA PROJECT DIN POWER FAN NETWORK.
// ============================================================

const String supabaseUrl =
    'YOUR_SUPABASE_PROJECT_URL';

const String supabasePublishableKey =
    'YOUR_SUPABASE_PUBLISHABLE_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // INITIALIZE SUPABASE
  // ==========================================================

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  // ==========================================================
  // INITIALIZE AUTH SERVICE
  // ==========================================================

  final authService = AuthService();

  await authService.initialize();

  // ==========================================================
  // START APP
  // ==========================================================

  runApp(
    PowerFanNetworkApp(
      authService: authService,
    ),
  );
}

// ============================================================
// POWER FAN NETWORK APP
// ============================================================

class PowerFanNetworkApp extends StatelessWidget {
  final AuthService authService;

  const PowerFanNetworkApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: 'POWER FAN NETWORK',

          theme: ThemeData(
            useMaterial3: true,

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B159B),
            ),

            scaffoldBackgroundColor:
                const Color(0xFFF8F8FC),

            appBarTheme: const AppBarTheme(
              backgroundColor:
                  Color(0xFFF8F8FC),

              foregroundColor:
                  Color(0xFF241064),

              elevation: 0,
            ),
          ),

          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
