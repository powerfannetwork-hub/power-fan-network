import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart'; // Idan kana da login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INITIALIZE SUPABASE - Saka URL da Key naka
  await Supabase.initialize(
    url: 'https://fihtqejqpycuvebufjhc.supabase.co',
    anonKey: 'SAKA_ANON_KEY_NAKA_ANAN', // Ka saka key naka na gaske
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Wannan shine mafi tsaro
    ),
  );

  // 2. KEEP ALIVE - Don kada Supabase free ya bacci
  keepSupabaseAlive();

  runApp(const MyApp());
}

void keepSupabaseAlive() {
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    try {
      await Supabase.instance.client.from('profiles').select('id').limit(1);
    } catch (_) {
      // Idan ya gaza mu yi shiru
    }
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
      ),
      // 3. WANNAN ZAI KULA DA SESSION HAR ABADA
      home: Supabase.instance.client.auth.currentUser == null
          ? const AuthScreen() // Idan ba a login ba je login
          : const MainNavigationScreen(), // Idan an login shiga kai tsaye
    );
  }
}
