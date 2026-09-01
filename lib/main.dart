import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'globals/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  final authService = AuthService();
  await authService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const PowerFanNetworkApp(),
    ),
  );
}

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: SupabaseConfig.appName, home: const MainNavigationScreen());
  }
}
