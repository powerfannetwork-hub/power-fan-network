import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  String _name = '';
  String get name => _name;

  Future<void> initialize() async {
    final profile = await ApiService.getProfile();
    _name = profile?['name'] ?? _supabase.auth.currentUser?.email ?? '';
    notifyListeners();
  }
}
