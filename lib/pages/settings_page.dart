import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../globals/app_state.dart';

class SettingsPage extends StatelessWidget {
  final AuthService authService; final AppState appState;
  const SettingsPage({super.key, required this.authService, required this.appState});

  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Settings', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF241064))),
      SizedBox(height: 20),
      ListTile(title: Text(user?['name'] ?? 'Miner'), subtitle: Text(user?['email'] ?? '')),
      Divider(),
      ListTile(title: Text("Logout"), leading: Icon(Icons.logout, color: Colors.red), onTap: () async { 
        await authService.logout(); 
        await appState.logout(); 
      })
    ]));
  }
}
