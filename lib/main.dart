import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fihtqejqpycuvebufjhc.supabase.co',
    anonKey: 'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr', // WANNAN SHI ZAMU YI AMFANI DA SHI
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Wannan yana hana Supabase bacci kowace minti 10
  keepSupabaseAlive();

  runApp(const MyApp());
}

void keepSupabaseAlive() {
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    try {
      await Supabase.instance.client.from('profiles').select('id').limit(1);
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POWER FAN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3B159B),
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B159B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          )
        )
      ),
      home: Supabase.instance.client.auth.currentUser == null
         ? const AuthScreen()
         : const MainNavigationScreen(),
    );
  }
}
