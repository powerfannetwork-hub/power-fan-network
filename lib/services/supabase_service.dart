import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<T> safeCall<T>(Future<T> Function() fn, {int retries = 2}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn().timeout(const Duration(seconds: 30));
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        final isConnectionError = errorString.contains('connection reset') ||
                                  errorString.contains('failed to fetch') ||
                                  errorString.contains('socketexception') ||
                                  errorString.contains('timeout');

        if (isConnectionError && attempt < retries) {
          attempt++;
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        rethrow;
      }
    }
  }
}
