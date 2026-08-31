import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ============================================================
  // BACKEND URL
  // ============================================================
  //
  // IMPORTANT:
  // Replace YOUR-BACKEND-URL with your real backend URL.
  //
  static const String baseUrl =
      'https://YOUR-BACKEND-URL';

  static const String _tokenKey =
      'power_fan_backend_token';

  // ============================================================
  // TOKEN
  // ============================================================

  static Future<String?> _getToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(
    String token,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      token,
    );
  }

  static Future<void> clearToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
  }

  // ============================================================
  // HEADERS
  // ============================================================

  static Future<Map<String, String>> _headers({
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await _getToken();

      if (token == null ||
          token.trim().isEmpty) {
        throw Exception(
          'User is not logged in.',
        );
      }

      headers['Authorization'] =
          'Bearer $token';
    }

    return headers;
  }

  // ============================================================
  // HTTP REQUEST
  // ============================================================

  static Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final cleanBaseUrl =
        baseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );

    final cleanEndpoint =
        endpoint.startsWith('/')
            ? endpoint
            : '/$endpoint';

    final uri = Uri.parse(
      '$cleanBaseUrl$cleanEndpoint',
    );

    final headers = await _headers(
      authenticated: authenticated,
    );

    late http.Response response;

    try {
      if (method == 'GET') {
        response = await http
            .get(
              uri,
              headers: headers,
            )
            .timeout(
              const Duration(
                seconds: 30,
              ),
            );
      } else if (method == 'POST') {
        response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode(
                body ?? {},
              ),
            )
            .timeout(
              const Duration(
                seconds: 30,
              ),
            );
      } else {
        throw Exception(
          'Unsupported HTTP method.',
        );
      }
    } on http.ClientException catch (error) {
      throw Exception(
        'Network error: ${error.message}',
      );
    } catch (error) {
      if (error is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to connect to backend.',
      );
    }

    dynamic data;

    try {
      if (response.body.trim().isEmpty) {
        data = <String, dynamic>{};
      } else {
        data = jsonDecode(
          response.body,
        );
      }
    } catch (_) {
      data = {
        'success': false,
        'message': response.body,
      };
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'Server request failed (${response.statusCode}).';

      if (data is Map &&
          data['message'] != null) {
        message =
            data['message'].toString();
      }

      throw Exception(message);
    }

    return data;
  }

  // ============================================================
  // HELPER
  // ============================================================

  static Map<String, dynamic> _map(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  // ============================================================
  // DASHBOARD
  // ============================================================
  //
  // This is the method missing from your previous ApiService.
  //
  static Future<Map<String, dynamic>> dashboard() async {
    final result = await _request(
      'GET',
      '/api/dashboard',
    );

    return _map(result);
  }

  // ============================================================
  // STATUS
  // ============================================================

  static Future<Map<String, dynamic>> status() async {
    final result = await _request(
      'GET',
      '/api/status',
      authenticated: false,
    );

    return _map(result);
  }

  // ============================================================
  // HEALTH
  // ============================================================

  static Future<Map<String, dynamic>> health() async {
    final result = await _request(
      'GET',
      '/health',
      authenticated: false,
    );

    return _map(result);
  }

  // ============================================================
  // USER BOOTSTRAP
  // ============================================================

  static Future<Map<String, dynamic>> bootstrapUser() async {
    final result = await _request(
      'POST',
      '/api/user/bootstrap',
    );

    return _map(result);
  }

  // ============================================================
  // PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> getProfile() async {
    final result = await _request(
      'GET',
      '/api/user/profile',
    );

    return _map(result);
  }

  // ============================================================
  // MINING CONFIG
  // ============================================================

  static Future<Map<String, dynamic>> getMiningConfig() async {
    final result = await _request(
      'GET',
      '/api/mining/config',
      authenticated: false,
    );

    return _map(result);
  }

  // ============================================================
  // START MINING
  // ============================================================

  static Future<Map<String, dynamic>> startMining() async {
    final result = await _request(
      'POST',
      '/api/mining/start',
    );

    return _map(result);
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  static Future<Map<String, dynamic>> claimMining() async {
    final result = await _request(
      'POST',
      '/api/mining/claim',
    );

    return _map(result);
  }

  // ============================================================
  // WATCH AD
  // ============================================================

  static Future<Map<String, dynamic>> watchAd() async {
    final result = await _request(
      'POST',
      '/api/mining/ad',
    );

    return _map(result);
  }

  // ============================================================
  // REFERRAL CONFIG
  // ============================================================

  static Future<Map<String, dynamic>> getReferralConfig() async {
    final result = await _request(
      'GET',
      '/api/referral/config',
      authenticated: false,
    );

    return _map(result);
  }

  // ============================================================
  // APPLY REFERRAL
  // ============================================================

  static Future<Map<String, dynamic>> applyReferral(
    String referralCode,
  ) async {
    final result = await _request(
      'POST',
      '/api/referral/apply',
      body: {
        'referralCode':
            referralCode.trim(),
      },
    );

    return _map(result);
  }

  // ============================================================
  // REFERRALS
  // ============================================================

  static Future<Map<String, dynamic>> getReferrals() async {
    final result = await _request(
      'GET',
      '/api/referrals',
    );

    return _map(result);
  }

  // ============================================================
  // SOCIAL CONFIG
  // ============================================================

  static Future<Map<String, dynamic>> getSocialConfig() async {
    final result = await _request(
      'GET',
      '/api/social/config',
      authenticated: false,
    );

    return _map(result);
  }

  // ============================================================
  // CLAIM SOCIAL REWARD
  // ============================================================

  static Future<Map<String, dynamic>> claimSocialReward() async {
    final result = await _request(
      'POST',
      '/api/social/claim',
    );

    return _map(result);
  }
}
