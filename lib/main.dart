import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_navigation_screen.dart'; // idan wannan baya aiki sai ka canza shi zuwa sunan login screen naka

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://fihtqejqpycuvebufjhc.supabase.co',
    publishableKey: 'SAKA_ANON_KEY_NAKA_ANAN', // <-- SAKA KEY NAKA ANAN
  );
  Timer.periodic(const Duration(minutes: 10), (timer) async {
    try { await Supabase.instance.client.from('profiles').select('id').limit(1); } catch (_) {}
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Supabase.instance.client.auth.currentUser == null
          ? const MainNavigationScreen() // idan baka da login, sai ka fara da wannan kai tsaye
          : const MainNavigationScreen(),
    );
  }
}
