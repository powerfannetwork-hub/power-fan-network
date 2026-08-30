import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ============================================================
  // BACKEND URL
  // ============================================================

  static const String baseUrl =
      'https://YOUR-BACKEND-URL';

  // ============================================================
  // HEADERS
  // ============================================================

  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final token = await user.getIdToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // REQUEST HELPER
  // ============================================================

  static Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    final headers = authenticated
        ? await _headers()
        : {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };

    late http.Response response;

    if (method == 'GET') {
      response = await http.get(
        uri,
        headers: headers,
      );
    } else if (method == 'POST') {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? {}),
      );
    } else {
      throw Exception('Unsupported HTTP method.');
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
          data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Server request failed.';

      throw Exception(message);
    }

    return data;
  }

  // ============================================================
  // SERVER STATUS
  // ============================================================

  static Future<Map<String, dynamic>> status() async {
    final result = await _request(
      'GET',
      '/api/status',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
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

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // USER BOOTSTRAP
  // ============================================================

  static Future<Map<String, dynamic>> bootstrapUser() async {
    final result = await _request(
      'POST',
      '/api/user/bootstrap',
    );

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> getProfile() async {
    final result = await _request(
      'GET',
      '/api/user/profile',
    );

    return Map<String, dynamic>.from(result);
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

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // START MINING
  // ============================================================

  static Future<Map<String, dynamic>> startMining() async {
    final result = await _request(
      'POST',
      '/api/mining/start',
    );

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // CLAIM MINING
  // ============================================================

  static Future<Map<String, dynamic>> claimMining() async {
    final result = await _request(
      'POST',
      '/api/mining/claim',
    );

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // REFERRAL CONFIG
  // ============================================================

  static Future<Map<String, dynamic>>
      getReferralConfig() async {
    final result = await _request(
      'GET',
      '/api/referral/config',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
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
        'referralCode': referralCode,
      },
    );

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // SOCIAL CONFIG
  // ============================================================

  static Future<Map<String, dynamic>>
      getSocialConfig() async {
    final result = await _request(
      'GET',
      '/api/social/config',
      authenticated: false,
    );

    return Map<String, dynamic>.from(result);
  }

  // ============================================================
  // CLAIM SOCIAL REWARD
  // ============================================================

  static Future<Map<String, dynamic>>
      claimSocialReward() async {
    final result = await _request(
      'POST',
      '/api/social/claim',
    );

    return Map<String, dynamic>.from(result);
  }
}
