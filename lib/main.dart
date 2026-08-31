import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';

// ============================================================
// POWER FAN NETWORK - SUPABASE CONFIG
// ============================================================

const String supabaseUrl =
    'https://fihtqejqpycuvebufjhc.supabase.co';

const String supabasePublishableKey =
    'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  final authService = AuthService();

  await authService.initialize();

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
