import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client; String? _error; bool _loading = false;
  String? get error => _error; bool get loading => _loading; User? get user => _supabase.auth.currentUser;

  Future<void> initialize() async {_loading = true; notifyListeners(); await Future.delayed(Duration.zero); _loading = false; notifyListeners();}

  Future<bool> login(String email, String password) async {
    try {_loading = true; _error = null; notifyListeners();
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return true;
    } catch(e) {_error = e.toString(); return false;} finally {_loading = false; notifyListeners();}
  }

  Future<bool> register(String email, String password, String name) async {
    try {_loading = true; _error = null; notifyListeners();
      await _supabase.auth.signUp(
        email: email, password: password,
        data: {'name': name, 'referral_code': '${email.split('@')[0].toUpperCase()}123', 'fan_balance': 0}
      );
      return true;
    } catch(e) {_error = e.toString(); return false;} finally {_loading = false; notifyListeners();}
  }

  Future<void> logout() async {await _supabase.auth.signOut(); notifyListeners();}
}
