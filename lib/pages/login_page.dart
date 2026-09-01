import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../globals/app_state.dart';
import '../screens/main_navigation_screen.dart';

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(); final _password = TextEditingController(); bool _isLogin = true;
  void _submit() async {
    final auth = context.read<AuthService>(); final appState = context.read<AppState>(); bool success;
    if (_isLogin) { success = await auth.login(_email.text.trim(), _password.text); }
    else { success = await auth.register(_email.text.trim(), _password.text, _email.text.split('@')[0]); }
    if(success && mounted) {
      await appState.refresh();
      if(mounted){ Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen())); }
    } else {
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error?? "Error"), backgroundColor: Colors.red)); }
    }
  }
  @override Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("POWER FAN", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF3B159B))),
      SizedBox(height: 30), TextField(controller: _email, decoration: InputDecoration(labelText: "Email")),
      TextField(controller: _password, obscureText: true, decoration: InputDecoration(labelText: "Password")),
      SizedBox(height: 20),
      auth.loading? CircularProgressIndicator() : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, child: Text(_isLogin? "LOGIN" : "REGISTER"), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B159B)))),
      TextButton(onPressed: () => setState(() => _isLogin =!_isLogin), child: Text(_isLogin? "Create Account" : "Have Account? Login"))
    ])));
  }
}
