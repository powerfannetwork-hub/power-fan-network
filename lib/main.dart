import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'globals/app_state.dart';
import 'pages/login_page.dart';
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co', // SAKE SAKE NAKA
    anonKey: 'your-anon-key', // SAKE SAKE NAKA
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..initialize()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'POWER FAN NETWORK',
        theme: ThemeData(primarySwatch: Colors.deepPurple, scaffoldBackgroundColor: const Color(0xFFF8F8FC)),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    if (authService.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (authService.user!= null) return const MainNavigationScreen();
    return const LoginPage();
  }
}
