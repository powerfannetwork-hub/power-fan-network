import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  String _name = ''; String? _error; bool _loading = false;

  String get name => _name; String? get error => _error; bool get loading => _loading;
  User? get user => _supabase.auth.currentUser;

  Future<void> initialize() async {
    _loading = true; notifyListeners();
    final profile = await ApiService.getProfile();
    _name = profile?['name'] ?? _supabase.auth.currentUser?.email ?? 'Miner';
    _loading = false; notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {_loading = true; _error = null; notifyListeners();
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await initialize(); return true;
    } catch(e) {_error = e.toString(); return false;} 
    finally {_loading = false; notifyListeners();}
  }

  Future<bool> register(String email, String password, String name) async {
    try {_loading = true; _error = null; notifyListeners();
      await _supabase.auth.signUp(email: email, password: password, data: {'name': name});
      await initialize(); return true;
    } catch(e) {_error = e.toString(); return false;} 
    finally {_loading = false; notifyListeners();}
  }

  Future<void> logout() async {await _supabase.auth.signOut(); _name = ''; notifyListeners();}
  Future<bool> updateProfile(String name) async {try {await ApiService.updateProfile(name: name); _name = name; notifyListeners(); return true;} catch(e) {_error = e.toString(); return false;}}
  Future<bool> changePassword(String newPassword) async {try {await _supabase.auth.updateUser(UserAttributes(password: newPassword)); return true;} catch(e) {_error = e.toString(); return false;}}
  Future<Map> getReferrals() => ApiService.getReferrals();
  Future<Map> applyReferral(String code) => ApiService.applyReferral(code);
  Future<Map> getMe() async => await ApiService.getProfile() ?? {};
}
