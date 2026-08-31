import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';

const String supabaseUrl =
    'YOUR_SUPABASE_PROJECT_URL';

const String supabasePublishableKey =
    'YOUR_SUPABASE_PUBLISHABLE_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  final authService =
      AuthService();

  await authService.initialize();

  runApp(
    PowerFanNetworkApp(
      authService: authService,
    ),
  );
}

class PowerFanNetworkApp
    extends StatelessWidget {
  final AuthService authService;

  const PowerFanNetworkApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: authService,
      builder: (
        context,
        child,
      ) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'POWER FAN NETWORK',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor:
                  const Color(0xFF3B159B),
            ),
            scaffoldBackgroundColor:
                const Color(0xFFF8F8FC),
          ),
          home:
              const MainNavigationScreen(),
        );
      },
    );
  }
}
