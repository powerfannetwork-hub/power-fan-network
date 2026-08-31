// ============================================================
// POWER FAN NETWORK - MAIN
// ============================================================
// Backend: Supabase
// Authentication: Supabase Auth
// Database: Supabase PostgreSQL
// Firebase: NOT USED
// Custom Backend: NOT USED
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // SUPABASE INITIALIZATION
  // ==========================================================

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey:
        SupabaseConfig.publishableKey,
  );

  // ==========================================================
  // AUTH SERVICE
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
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: SupabaseConfig.appName,

          theme: ThemeData(
            useMaterial3: true,

            colorScheme: ColorScheme.fromSeed(
              seedColor:
                  const Color(0xFF3B159B),
            ),

            scaffoldBackgroundColor:
                const Color(0xFFF8F8FC),

            appBarTheme:
                const AppBarTheme(
              backgroundColor:
                  Color(0xFFF8F8FC),

              foregroundColor:
                  Color(0xFF241064),

              elevation: 0,
            ),

            inputDecorationTheme:
                InputDecorationTheme(
              filled: true,

              fillColor:
                  Colors.white,

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFFE5E5EA),
                ),
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      Color(0xFF3B159B),
                  width: 1.5,
                ),
              ),
            ),

            elevatedButtonTheme:
                ElevatedButtonThemeData(
              style:
                  ElevatedButton.styleFrom(
                minimumSize:
                    const Size(
                  double.infinity,
                  52,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),

          home:
              const MainNavigationScreen(),
        );
      },
    );
  }
}
