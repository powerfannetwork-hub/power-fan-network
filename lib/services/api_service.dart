import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://YOUR-BACKEND-URL';

  static const String _tokenKey =
      'power_fan_backend_token';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, String>> _headers({
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await _getToken();

      if (token == null || token.trim().isEmpty) {
        throw Exception('User is not logged in.');
      }

      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  static Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final cleanBaseUrl =
        baseUrl.replaceFirst(RegExp(r'/$'), '');

    final uri = Uri.parse(
      '$cleanBaseUrl$endpoint',
    );

    final headers = await _headers(
      authenticated: authenticated,
    );

    late http.Response response;

    if (method == 'GET') {
      response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(
            const Duration(seconds: 30),
          );
    } else if (method == 'POST') {
      response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(
            const Duration(seconds: 30),
          );
    } else {
      throw Exception(
        'Unsupported HTTP method.',
      );
    }

    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {
        'success': false,
        'message': response.body,
      };
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final message =
          data is Map &&
                  data['message'] != null
              ? data['message'].toString()
              : 'Server request failed (${response.statusCode}).';

      throw Exception(message);
    }

    return data;
  }

  static Future<Map<String, dynamic>> status() async {
    final result = await _request(
      'GET',
      '/api/status',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> health() async {
    final result = await _request(
      'GET',
      '/health',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> bootstrapUser() async {
    final result = await _request(
      'POST',
      '/api/user/bootstrap',
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final result = await _request(
      'GET',
      '/api/user/profile',
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getMiningConfig() async {
    final result = await _request(
      'GET',
      '/api/mining/config',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> startMining() async {
    final result = await _request(
      'POST',
      '/api/mining/start',
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> claimMining() async {
    final result = await _request(
      'POST',
      '/api/mining/claim',
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> watchAd() async {
    final result = await _request(
      'POST',
      '/api/mining/ad',
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getReferralConfig() async {
    final result = await _request(
      'GET',
      '/api/referral/config',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> applyReferral(
    String referralCode,
  ) async {
    final result = await _request(
      'POST',
      '/api/referral/apply',
      body: {
        'referralCode': referralCode,
      },
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getReferrals() async {
    final result = await _request(
      'GET',
      '/api/referrals',
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getSocialConfig() async {
    final result = await _request(
      'GET',
      '/api/social/config',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> claimSocialReward() async {
    final result = await _request(
      'POST',
      '/api/social/claim',
    );

    return Map<String, dynamic>.from(result);
  }
}
