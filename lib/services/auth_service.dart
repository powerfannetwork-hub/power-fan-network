// ============================================================
// POWER FAN NETWORK
// CUSTOM BACKEND AUTH SERVICE
// ============================================================
// Firebase Authentication: NOT USED
// Authentication: Custom Backend JWT
// Database: Firestore through backend API
// ============================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  // ==========================================================
  // BACKEND URL
  // ==========================================================

  //
  // Za mu saka actual backend URL ɗinmu an gama hosting.
  //
  // Kada a saka Firebase Auth URL a nan.
  //

  static const String baseUrl =
      'https://YOUR-BACKEND-URL.com';

  // ==========================================================
  // STORAGE KEYS
  // ==========================================================

  static const String _tokenKey = 'power_fan_auth_token';
  static const String _userKey = 'power_fan_user';

  // ==========================================================
  // STATE
  // ==========================================================

  String? _token;
  Map<String, dynamic>? _user;

  bool _loading = false;

  String? _error;

  // ==========================================================
  // GETTERS
  // ==========================================================

  String? get token => _token;

  Map<String, dynamic>? get user => _user;

  bool get loading => _loading;

  String? get error => _error;

  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty;

  String get userId =>
      (_user?['id'] ?? '').toString();

  String get name =>
      (_user?['name'] ?? '').toString();

  String get email =>
      (_user?['email'] ?? '').toString();

  String get referralCode =>
      (_user?['referralCode'] ?? '').toString();

  String? get referredBy =>
      _user?['referredBy']?.toString();

  double get fanBalance =>
      _toDouble(_user?['fanBalance']);

  double get afamBalance =>
      _toDouble(_user?['afamBalance']);

  double get miningRate =>
      _toDouble(_user?['miningRate'], fallback: 0.2);

  int get activeReferrals =>
      _toInt(_user?['activeReferrals']);

  int get dailyAdsWatched =>
      _toInt(_user?['dailyAdsWatched']);

  double get adBoost =>
      _toDouble(_user?['adBoost']);

  bool get miningActive =>
      _user?['miningActive'] == true;

  // ==========================================================
  // HELPERS
  // ==========================================================

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value == null) return fallback;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? fallback;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  // ==========================================================
  // HEADERS
  // ==========================================================

  Map<String, String> _headers({
    bool authenticated = false,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated &&
        _token != null &&
        _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    _setLoading(true);
    _setError(null);

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final savedToken =
          prefs.getString(_tokenKey);

      final savedUserJson =
          prefs.getString(_userKey);

      if (savedToken == null ||
          savedToken.isEmpty) {
        _token = null;
        _user = null;
        return;
      }

      _token = savedToken;

      if (savedUserJson != null &&
          savedUserJson.isNotEmpty) {
        try {
          final decoded =
              jsonDecode(savedUserJson);

          if (decoded is Map) {
            _user =
                Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          _user = null;
        }
      }

      // Verify token with backend.
      final valid = await _loadCurrentUser();

      if (!valid) {
        await _clearLocalSession();
      }
    } catch (error) {
      debugPrint(
        'AuthService initialize error: $error',
      );

      // Kada mu hana app saboda network error.
      // Idan token yana nan, za mu iya barin local state.
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      };

      if (referralCode != null &&
          referralCode.trim().isNotEmpty) {
        body['referralCode'] =
            referralCode.trim().toUpperCase();
      }

      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/auth/register',
        ),
        headers: _headers(),
        body: jsonEncode(body),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        await _saveLoginData(data);

        _setError(null);

        return true;
      }

      _setError(
        _messageFromResponse(
          data,
          'Registration failed.',
        ),
      );

      return false;
    } catch (error) {
      debugPrint(
        'REGISTER ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/auth/login',
        ),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        await _saveLoginData(data);

        _setError(null);

        return true;
      }

      _setError(
        _messageFromResponse(
          data,
          'Login failed.',
        ),
      );

      return false;
    } catch (error) {
      debugPrint(
        'LOGIN ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // CURRENT USER
  // ==========================================================

  Future<bool> _loadCurrentUser() async {
    if (_token == null ||
        _token!.isEmpty) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/auth/me',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['user'] is Map) {
        _user =
            Map<String, dynamic>.from(
          data['user'] as Map,
        );

        await _saveUserOnly();

        notifyListeners();

        return true;
      }

      if (response.statusCode == 401) {
        return false;
      }

      return true;
    } catch (error) {
      debugPrint(
        'LOAD CURRENT USER ERROR: $error',
      );

      // Network error ba yana nufin token ya mutu.
      return true;
    }
  }

  // ==========================================================
  // REFRESH USER
  // ==========================================================

  Future<bool> refreshUser() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/auth/me',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['user'] is Map) {
        _user =
            Map<String, dynamic>.from(
          data['user'] as Map,
        );

        await _saveUserOnly();

        _setError(null);

        notifyListeners();

        return true;
      }

      if (response.statusCode == 401) {
        await logout();

        return false;
      }

      return false;
    } catch (error) {
      debugPrint(
        'REFRESH USER ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return false;
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        await http.post(
          Uri.parse(
            '$baseUrl/api/auth/logout',
          ),
          headers: _headers(
            authenticated: true,
          ),
        );
      }
    } catch (error) {
      debugPrint(
        'LOGOUT SERVER ERROR: $error',
      );
    }

    await _clearLocalSession();

    notifyListeners();
  }

  // ==========================================================
  // CHANGE PASSWORD
  // ==========================================================

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );

      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/auth/change-password',
        ),
        headers: _headers(
          authenticated: true,
        ),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        _setError(null);

        return true;
      }

      _setError(
        _messageFromResponse(
          data,
          'Could not change password.',
        ),
      );

      return false;
    } catch (error) {
      debugPrint(
        'CHANGE PASSWORD ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================

  Future<bool> updateProfile({
    required String name,
  }) async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );

      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await http.put(
        Uri.parse(
          '$baseUrl/api/user/profile',
        ),
        headers: _headers(
          authenticated: true,
        ),
        body: jsonEncode({
          'name': name.trim(),
        }),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (data['user'] is Map) {
          _user =
              Map<String, dynamic>.from(
            data['user'] as Map,
          );

          await _saveUserOnly();
        }

        _setError(null);

        notifyListeners();

        return true;
      }

      _setError(
        _messageFromResponse(
          data,
          'Could not update profile.',
        ),
      );

      return false;
    } catch (error) {
      debugPrint(
        'UPDATE PROFILE ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // DASHBOARD
  // ==========================================================

  Future<Map<String, dynamic>?> getDashboard() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/dashboard',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (data['user'] is Map) {
          _user =
              Map<String, dynamic>.from(
            data['user'] as Map,
          );

          await _saveUserOnly();

          notifyListeners();
        }

        return data;
      }

      return null;
    } catch (error) {
      debugPrint(
        'DASHBOARD ERROR: $error',
      );

      return null;
    }
  }

  // ==========================================================
  // START MINING
  // ==========================================================

  Future<Map<String, dynamic>?> startMining() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );

      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/mining/start',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (_user != null) {
          _user!['miningActive'] = true;
        }

        await _saveUserOnly();

        _setError(null);

        notifyListeners();

        return data;
      }

      _setError(
        _messageFromResponse(
          data,
          'Could not start mining.',
        ),
      );

      return null;
    } catch (error) {
      debugPrint(
        'START MINING ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return null;
    }
  }

  // ==========================================================
  // CLAIM MINING
  // ==========================================================

  Future<Map<String, dynamic>?> claimMining() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );

      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/mining/claim',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (_user != null) {
          _user!['fanBalance'] =
              data['fanBalance'];

          _user!['miningActive'] = false;

          _user!['dailyAdsWatched'] = 0;

          _user!['adBoost'] = 0;

          // Base rate + referral boost
          _user!['miningRate'] =
              0.2 +
              activeReferrals * 0.02;
        }

        await _saveUserOnly();

        _setError(null);

        notifyListeners();

        return data;
      }

      _setError(
        _messageFromResponse(
          data,
          'Could not claim mining reward.',
        ),
      );

      return null;
    } catch (error) {
      debugPrint(
        'CLAIM MINING ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return null;
    }
  }

  // ==========================================================
  // REWARDED AD
  // ==========================================================

  Future<Map<String, dynamic>?> watchRewardedAd() async {
    if (!isAuthenticated) {
      _setError(
        'You are not authenticated.',
      );

      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/mining/ad',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        if (_user != null) {
          _user!['dailyAdsWatched'] =
              data['adsWatched'];

          _user!['adBoost'] =
              data['adBoost'];

          _user!['miningRate'] =
              data['miningRate'];
        }

        await _saveUserOnly();

        _setError(null);

        notifyListeners();

        return data;
      }

      _setError(
        _messageFromResponse(
          data,
          'Could not apply ad reward.',
        ),
      );

      return null;
    } catch (error) {
      debugPrint(
        'REWARDED AD ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return null;
    }
  }

  // ==========================================================
  // REFERRALS
  // ==========================================================

  Future<Map<String, dynamic>?> getReferrals() async {
    if (!isAuthenticated) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/referrals',
        ),
        headers: _headers(
          authenticated: true,
        ),
      );

      final data = _decodeResponse(response);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        return data;
      }

      _setError(
        _messageFromResponse(
          data,
          'Could not load referrals.',
        ),
      );

      return null;
    } catch (error) {
      debugPrint(
        'REFERRALS ERROR: $error',
      );

      _setError(
        _networkErrorMessage(error),
      );

      return null;
    }
  }

  // ==========================================================
  // SAVE LOGIN DATA
  // ==========================================================

  Future<void> _saveLoginData(
    Map<String, dynamic> data,
  ) async {
    final token =
        data['token']?.toString();

    final userData =
        data['user'];

    if (token == null ||
        token.isEmpty) {
      throw Exception(
        'Backend did not return an authentication token.',
      );
    }

    if (userData is! Map) {
      throw Exception(
        'Backend did not return user information.',
      );
    }

    _token = token;

    _user =
        Map<String, dynamic>.from(
      userData,
    );

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      _token!,
    );

    await prefs.setString(
      _userKey,
      jsonEncode(_user),
    );

    notifyListeners();
  }

  // ==========================================================
  // SAVE USER ONLY
  // ==========================================================

  Future<void> _saveUserOnly() async {
    if (_user == null) return;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _userKey,
      jsonEncode(_user),
    );
  }

  // ==========================================================
  // CLEAR SESSION
  // ==========================================================

  Future<void> _clearLocalSession() async {
    _token = null;
    _user = null;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);

    _setError(null);
  }

  // ==========================================================
  // RESPONSE DECODER
  // ==========================================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    try {
      final decoded =
          jsonDecode(response.body);

      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }

      return {
        'success': false,
        'message':
            'Invalid response from server.',
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            response.body.isNotEmpty
                ? response.body
                : 'Empty response from server.',
      };
    }
  }

  // ==========================================================
  // ERROR MESSAGE
  // ==========================================================

  String _messageFromResponse(
    Map<String, dynamic> data,
    String fallback,
  ) {
    final message =
        data['message']?.toString();

    if (message != null &&
        message.trim().isNotEmpty) {
      return message;
    }

    final error =
        data['error']?.toString();

    if (error != null &&
        error.trim().isNotEmpty) {
      return error;
    }

    return fallback;
  }

  // ==========================================================
  // NETWORK ERROR
  // ==========================================================

  String _networkErrorMessage(
    Object error,
  ) {
    final message =
        error.toString();

    if (message.contains(
      'SocketException',
    )) {
      return 'Could not connect to the backend server.';
    }

    if (message.contains(
      'Failed host lookup',
    )) {
      return 'Backend server address could not be found.';
    }

    if (message.contains(
      'TimeoutException',
    )) {
      return 'Backend server took too long to respond.';
    }

    return 'Connection error. Please try again.';
  }
}
