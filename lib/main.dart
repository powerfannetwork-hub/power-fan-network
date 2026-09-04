import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fihtqejqpycuvebufjhc.supabase.co',
    publishableKey: 'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr',
  );

  runApp(const PowerFanNetworkApp());
}

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POWER FAN NETWORK',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B159B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
      ),
      home: const MainNavigationScreen(),
    );
  }
}
