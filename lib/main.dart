import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main_navigation_screen.dart';

/// ============================================================
/// POWER FAN NETWORK
/// MAIN.DART
///
/// AUTHENTICATION:
/// Custom Backend Authentication
///
/// DATABASE:
/// Firestore (handled by backend only)
///
/// FIREBASE AUTHENTICATION:
/// NOT USED
/// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = BackendSession();

  await session.initialize();

  runApp(
    PowerFanNetworkApp(
      session: session,
    ),
  );
}

/// ============================================================
/// BACKEND CONFIG
/// ============================================================
///
/// IMPORTANT:
/// Bayan ka gama hosting backend, ka maye gurbin URL ɗin
/// da actual backend URL ɗinka.
///
/// Misali:
///
/// https://power-fan-network-api.example.com
///
/// Kada ka saka /api a ƙarshen URL.
///
/// API routes za su kasance:
///
/// /api/auth/register
/// /api/auth/login
/// /api/auth/me
/// /api/auth/logout
///
/// ============================================================

class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://YOUR-BACKEND-DOMAIN.com',
  );

  static const Duration requestTimeout =
      Duration(seconds: 30);
}

/// ============================================================
/// USER MODEL
/// ============================================================

class BackendUser {
  final String id;
  final String name;
  final String email;
  final String referralCode;
  final String? referredBy;

  final double fanBalance;
  final double afamBalance;

  final double miningRate;

  final int activeReferrals;

  final int dailyAdsWatched;
  final double adBoost;

  final bool miningActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  BackendUser({
    required this.id,
    required this.name,
    required this.email,
    required this.referralCode,
    required this.referredBy,
    required this.fanBalance,
    required this.afamBalance,
    required this.miningRate,
    required this.activeReferrals,
    required this.dailyAdsWatched,
    required this.adBoost,
    required this.miningActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackendUser.fromJson(
    Map<String, dynamic> json,
  ) {
    return BackendUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      referralCode:
          json['referralCode']?.toString() ?? '',
      referredBy:
          json['referredBy']?.toString(),

      fanBalance:
          _toDouble(json['fanBalance']),

      afamBalance:
          _toDouble(json['afamBalance']),

      miningRate:
          _toDouble(
            json['miningRate'],
            fallback: 0.2,
          ),

      activeReferrals:
          _toInt(json['activeReferrals']),

      dailyAdsWatched:
          _toInt(json['dailyAdsWatched']),

      adBoost:
          _toDouble(json['adBoost']),

      miningActive:
          json['miningActive'] == true,

      createdAt:
          _parseDate(json['createdAt']),

      updatedAt:
          _parseDate(json['updatedAt']),
    );
  }

  static double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value == null) return fallback;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        fallback;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) return null;

    return DateTime.tryParse(
      value.toString(),
    );
  }
}

/// ============================================================
/// BACKEND SESSION
/// ============================================================

class BackendSession extends ChangeNotifier {
  static const String _tokenKey =
      'power_fan_backend_token';

  String? _token;
  BackendUser? _user;

  bool _loading = true;

  String? get token => _token;

  BackendUser? get user => _user;

  bool get isAuthenticated =>
      _token != null &&
      _token!.isNotEmpty &&
      _user != null;

  bool get loading => _loading;

  /// ----------------------------------------------------------
  /// INITIALIZE SESSION
  /// ----------------------------------------------------------

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final savedToken =
          prefs.getString(_tokenKey);

      if (savedToken == null ||
          savedToken.trim().isEmpty) {
        _token = null;
        _user = null;
        return;
      }

      _token = savedToken;

      final user =
          await BackendApi.getCurrentUser(
        savedToken,
      );

      if (user == null) {
        await clearSession();
      } else {
        _user = user;
      }
    } catch (error) {
      debugPrint(
        'Session initialization error: $error',
      );

      _token = null;
      _user = null;

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.remove(_tokenKey);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// ----------------------------------------------------------
  /// LOGIN
  /// ----------------------------------------------------------

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final result =
          await BackendApi.login(
        email: email,
        password: password,
      );

      if (result == null) {
        return 'Login failed.';
      }

      final token =
          result['token']?.toString();

      final userJson =
          result['user'];

      if (token == null ||
          token.isEmpty ||
          userJson is! Map) {
        return 'Backend returned an invalid login response.';
      }

      final user =
          BackendUser.fromJson(
        Map<String, dynamic>.from(
          userJson,
        ),
      );

      await saveSession(
        token,
        user,
      );

      return null;
    } catch (error) {
      return _friendlyError(error);
    }
  }

  /// ----------------------------------------------------------
  /// REGISTER
  /// ----------------------------------------------------------

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    try {
      final result =
          await BackendApi.register(
        name: name,
        email: email,
        password: password,
        referralCode: referralCode,
      );

      if (result == null) {
        return 'Registration failed.';
      }

      final token =
          result['token']?.toString();

      final userJson =
          result['user'];

      if (token == null ||
          token.isEmpty ||
          userJson is! Map) {
        return 'Backend returned an invalid registration response.';
      }

      final user =
          BackendUser.fromJson(
        Map<String, dynamic>.from(
          userJson,
        ),
      );

      await saveSession(
        token,
        user,
      );

      return null;
    } catch (error) {
      return _friendlyError(error);
    }
  }

  /// ----------------------------------------------------------
  /// SAVE SESSION
  /// ----------------------------------------------------------

  Future<void> saveSession(
    String token,
    BackendUser user,
  ) async {
    _token = token;
    _user = user;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _tokenKey,
      token,
    );

    notifyListeners();
  }

  /// ----------------------------------------------------------
  /// REFRESH USER
  /// ----------------------------------------------------------

  Future<bool> refreshUser() async {
    if (_token == null ||
        _token!.isEmpty) {
      return false;
    }

    try {
      final user =
          await BackendApi.getCurrentUser(
        _token!,
      );

      if (user == null) {
        await clearSession();
        return false;
      }

      _user = user;
      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'Refresh user error: $error',
      );

      return false;
    }
  }

  /// ----------------------------------------------------------
  /// LOGOUT
  /// ----------------------------------------------------------

  Future<void> logout() async {
    final currentToken = _token;

    try {
      if (currentToken != null &&
          currentToken.isNotEmpty) {
        await BackendApi.logout(
          currentToken,
        );
      }
    } catch (error) {
      debugPrint(
        'Backend logout error: $error',
      );
    }

    await clearSession();
  }

  /// ----------------------------------------------------------
  /// CLEAR SESSION
  /// ----------------------------------------------------------

  Future<void> clearSession() async {
    _token = null;
    _user = null;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);

    notifyListeners();
  }

  /// ----------------------------------------------------------
  /// FRIENDLY ERROR
  /// ----------------------------------------------------------

  String _friendlyError(
    dynamic error,
  ) {
    final message =
        error.toString();

    if (message.contains(
      'SocketException',
    )) {
      return 'Could not connect to the backend server.';
    }

    if (message.contains(
      'TimeoutException',
    )) {
      return 'The server took too long to respond.';
    }

    return message
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();
  }
}

/// ============================================================
/// BACKEND API
/// ============================================================

class BackendApi {
  static String get _baseUrl {
    return BackendConfig.baseUrl
        .replaceFirst(
          RegExp(r'/$'),
          '',
        );
  }

  /// ----------------------------------------------------------
  /// COMMON HEADERS
  /// ----------------------------------------------------------

  static Map<String, String> _headers({
    String? token,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null &&
        token.isNotEmpty) {
      headers['Authorization'] =
          'Bearer $token';
    }

    return headers;
  }

  /// ----------------------------------------------------------
  /// REGISTER
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
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

    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl/api/auth/register',
              ),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// LOGIN
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl/api/auth/login',
              ),
              headers: _headers(),
              body: jsonEncode({
                'email':
                    email.trim().toLowerCase(),
                'password': password,
              }),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// CURRENT USER
  /// ----------------------------------------------------------

  static Future<BackendUser?> getCurrentUser(
    String token,
  ) async {
    final response =
        await http
            .get(
              Uri.parse(
                '$_baseUrl/api/auth/me',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    if (response.statusCode == 401) {
      return null;
    }

    final data =
        _handleResponse(response);

    if (data == null) {
      return null;
    }

    final userJson =
        data['user'];

    if (userJson is! Map) {
      return null;
    }

    return BackendUser.fromJson(
      Map<String, dynamic>.from(
        userJson,
      ),
    );
  }

  /// ----------------------------------------------------------
  /// LOGOUT
  /// ----------------------------------------------------------

  static Future<bool> logout(
    String token,
  ) async {
    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl/api/auth/logout',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return response.statusCode >= 200 &&
        response.statusCode < 300;
  }

  /// ----------------------------------------------------------
  /// DASHBOARD
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> dashboard(
    String token,
  ) async {
    final response =
        await http
            .get(
              Uri.parse(
                '$_baseUrl/api/dashboard',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// START MINING
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> startMining(
    String token,
  ) async {
    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl/api/mining/start',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// CLAIM MINING
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> claimMining(
    String token,
  ) async {
    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl/api/mining/claim',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// REWARDED AD
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> watchAd(
    String token,
  ) async {
    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl/api/mining/ad',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// REFERRALS
  /// ----------------------------------------------------------

  static Future<Map<String, dynamic>?> referrals(
    String token,
  ) async {
    final response =
        await http
            .get(
              Uri.parse(
                '$_baseUrl/api/referrals',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              BackendConfig.requestTimeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ----------------------------------------------------------
  /// RESPONSE HANDLER
  /// ----------------------------------------------------------

  static Map<String, dynamic>? _handleResponse(
    http.Response response,
  ) {
    Map<String, dynamic> data = {};

    try {
      final decoded =
          jsonDecode(response.body);

      if (decoded is Map) {
        data =
            Map<String, dynamic>.from(
          decoded,
        );
      }
    } catch (_) {
      data = {};
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    final message =
        data['message']?.toString();

    if (message != null &&
        message.isNotEmpty) {
      throw Exception(message);
    }

    throw Exception(
      'Request failed (${response.statusCode}).',
    );
  }
}

/// ============================================================
/// MAIN APP
/// ============================================================

class PowerFanNetworkApp extends StatelessWidget {
  final BackendSession session;

  const PowerFanNetworkApp({
    super.key,
    required this.session,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: session,
      builder: (
        context,
        _,
      ) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: 'POWER FAN NETWORK',

          theme: ThemeData(
            useMaterial3: true,

            colorScheme: ColorScheme.fromSeed(
              seedColor:
                  const Color(0xFF3B159B),
              brightness:
                  Brightness.light,
            ),

            scaffoldBackgroundColor:
                const Color(0xFFF8F8FC),

            fontFamily: 'Roboto',
          ),

          home: AuthGate(
            session: session,
          ),
        );
      },
    );
  }
}

/// ============================================================
/// AUTH GATE
/// ============================================================

class AuthGate extends StatelessWidget {
  final BackendSession session;

  const AuthGate({
    super.key,
    required this.session,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (session.loading) {
      return const SplashScreen();
    }

    if (session.isAuthenticated) {
      return const MainNavigationScreen();
    }

    return LoginPage(
      session: session,
    );
  }
}

/// ============================================================
/// SPLASH SCREEN
/// ============================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Scaffold(
      backgroundColor:
          Color(0xFF241064),

      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.bolt_rounded,
              size: 80,
              color: Colors.white,
            ),

            SizedBox(height: 20),

            Text(
              'POWER FAN NETWORK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 1,
              ),
            ),

            SizedBox(height: 30),

            SizedBox(
              width: 28,
              height: 28,
              child:
                  CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// LOGIN PAGE
/// ============================================================

class LoginPage extends StatefulWidget {
  final BackendSession session;

  const LoginPage({
    super.key,
    required this.session,
  });

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState
    extends State<LoginPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  bool _loading = false;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final error =
        await widget.session.login(
      email:
          _emailController.text,
      password:
          _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (error != null) {
      _showError(error);
      return;
    }
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,

                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 72,
                    color:
                        Color(0xFF3B159B),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    'POWER FAN NETWORK',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF241064),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Welcome back',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 35,
                  ),

                  TextFormField(
                    controller:
                        _emailController,

                    keyboardType:
                        TextInputType
                            .emailAddress,

                    decoration:
                        const InputDecoration(
                      labelText: 'Email',
                      prefixIcon:
                          Icon(
                        Icons.email_outlined,
                      ),
                      border:
                          OutlineInputBorder(),
                    ),

                    validator:
                        (value) {
                      if (value ==
                              null ||
                          value
                              .trim()
                              .isEmpty) {
                        return 'Enter your email';
                      }

                      if (!value
                          .contains('@')) {
                        return 'Enter a valid email';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  TextFormField(
                    controller:
                        _passwordController,

                    obscureText:
                        _obscurePassword,

                    decoration:
                        InputDecoration(
                      labelText:
                          'Password',

                      prefixIcon:
                          const Icon(
                        Icons
                            .lock_outline,
                      ),

                      suffixIcon:
                          IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),

                      border:
                          const OutlineInputBorder(),
                    ),

                    validator:
                        (value) {
                      if (value ==
                              null ||
                          value.isEmpty) {
                        return 'Enter your password';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  SizedBox(
                    height: 52,

                    child:
                        ElevatedButton(
                      onPressed:
                          _loading
                              ? null
                              : _login,

                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF3B159B,
                        ),

                        foregroundColor:
                            Colors.white,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),

                      child:
                          _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.5,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  TextButton(
                    onPressed:
                        _loading
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            RegisterPage(
                                      session:
                                          widget.session,
                                    ),
                                  ),
                                );
                              },
                    child:
                        const Text(
                      "Don't have an account? Register",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// REGISTER PAGE
/// ============================================================

class RegisterPage
    extends StatefulWidget {
  final BackendSession session;

  const RegisterPage({
    super.key,
    required this.session,
  });

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _referralController =
      TextEditingController();

  bool _loading = false;

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final referral =
        _referralController.text
            .trim();

    final error =
        await widget.session.register(
      name:
          _nameController.text,
      email:
          _emailController.text,
      password:
          _passwordController.text,
      referralCode:
          referral.isEmpty
              ? null
              : referral,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      return;
    }

    Navigator.of(context)
        .pop();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Create Account'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,

              children: [
                const SizedBox(
                  height: 10,
                ),

                const Icon(
                  Icons
                      .person_add_alt_1_rounded,
                  size: 64,
                  color:
                      Color(0xFF3B159B),
                ),

                const SizedBox(
                  height: 25,
                ),

                TextFormField(
                  controller:
                      _nameController,

                  textCapitalization:
                      TextCapitalization
                          .words,

                  decoration:
                      const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon:
                        Icon(
                      Icons
                          .person_outline,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),

                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value
                                .trim()
                                .length <
                            2) {
                      return 'Enter your name';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                TextFormField(
                  controller:
                      _emailController,

                  keyboardType:
                      TextInputType
                          .emailAddress,

                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                        Icon(
                      Icons
                          .email_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),

                  validator:
                      (value) {
                    if (value ==
                            null ||
                        !value
                            .contains(
                          '@',
                        )) {
                      return 'Enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                TextFormField(
                  controller:
                      _passwordController,

                  obscureText:
                      _obscurePassword,

                  decoration:
                      InputDecoration(
                    labelText:
                        'Password',

                    prefixIcon:
                        const Icon(
                      Icons
                          .lock_outline,
                    ),

                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),

                    border:
                        const OutlineInputBorder(),
                  ),

                  validator:
                      (value) {
                    if (value ==
                            null ||
                        value.length <
                            6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                TextFormField(
                  controller:
                      _referralController,

                  textCapitalization:
                      TextCapitalization
                          .characters,

                  decoration:
                      const InputDecoration(
                    labelText:
                        'Referral Code (Optional)',

                    prefixIcon:
                        Icon(
                      Icons
                          .group_add_outlined,
                    ),

                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                SizedBox(
                  height: 52,

                  child:
                      ElevatedButton(
                    onPressed:
                        _loading
                            ? null
                            : _register,

                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF3B159B,
                      ),

                      foregroundColor:
                          Colors.white,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                    ),

                    child:
                        _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.5,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Text(
                                'CREATE ACCOUNT',
                                style:
                                    TextStyle(
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
