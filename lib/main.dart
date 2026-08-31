import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main_navigation_screen.dart';

/// ============================================================
/// POWER FAN NETWORK
/// FILE: lib/main.dart
/// ============================================================
///
/// USER-FACING AUTHENTICATION
/// --------------------------
/// Email + Password
///
///
/// IMPORTANT
/// ---------
/// Technical service names are intentionally NOT shown
/// anywhere in the user interface.
///
/// Registration should work without email confirmation.
/// Make sure email confirmation is disabled in the
/// authentication settings before testing.
///
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
/// AUTH CONFIGURATION
/// ============================================================

class SupabaseConfig {
  static const String url =
      'https://fihtqejqpycuvebufjhc.supabase.co';

  static const String publishableKey =
      'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

  static const Duration timeout =
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

  const BackendUser({
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
    );
  }

  static double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        fallback;
  }

  static int _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }
}

/// ============================================================
/// SESSION
/// ============================================================

class BackendSession extends ChangeNotifier {
  static const String _tokenKey =
      'power_fan_auth_token';

  static const String _userKey =
      'power_fan_user';

  String? _token;
  BackendUser? _user;

  bool _loading = true;

  String? _error;

  String? get token => _token;

  BackendUser? get user => _user;

  bool get loading => _loading;

  String? get error => _error;

  bool get isAuthenticated =>
      _token != null &&
      _token!.isNotEmpty &&
      _user != null;

  /// ==========================================================
  /// INITIALIZE SESSION
  /// ==========================================================

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final savedToken =
          prefs.getString(_tokenKey);

      final savedUser =
          prefs.getString(_userKey);

      if (savedToken == null ||
          savedToken.trim().isEmpty) {
        _token = null;
        _user = null;
        return;
      }

      _token = savedToken;

      if (savedUser != null &&
          savedUser.trim().isNotEmpty) {
        try {
          final decoded =
              jsonDecode(savedUser);

          if (decoded is Map) {
            _user =
                BackendUser.fromJson(
              Map<String, dynamic>.from(
                decoded,
              ),
            );
          }
        } catch (error) {
          debugPrint(
            'Saved user decode error: $error',
          );
        }
      }

      try {
        final currentUser =
            await SupabaseAuth.getCurrentUser(
          savedToken,
        );

        if (currentUser == null) {
          await clearSession();
        } else {
          _user =
              _createUserFromAuth(
            currentUser,
            oldUser: _user,
          );

          await _saveUser();
        }
      } catch (error) {
        /// Do not destroy a valid local session
        /// just because the network is temporarily
        /// unavailable.
        debugPrint(
          'Session validation failed: $error',
        );
      }
    } catch (error) {
      debugPrint(
        'SESSION INITIALIZE ERROR: $error',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// ==========================================================
  /// LOGIN
  /// ==========================================================

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final result =
          await SupabaseAuth.login(
        email: email,
        password: password,
      );

      if (result == null) {
        return _setError(
          'Login failed. Please check your email and password.',
        );
      }

      final accessToken =
          result['access_token']?.toString();

      final userJson =
          result['user'];

      if (accessToken == null ||
          accessToken.trim().isEmpty) {
        return _setError(
          'Login failed. Please try again.',
        );
      }

      if (userJson is! Map) {
        return _setError(
          'Login failed. Please try again.',
        );
      }

      final user =
          _createUserFromAuth(
        Map<String, dynamic>.from(
          userJson,
        ),
      );

      await saveSession(
        accessToken,
        user,
      );

      _error = null;

      notifyListeners();

      return null;
    } catch (error) {
      return _setError(
        _friendlyError(error),
      );
    }
  }

  /// ==========================================================
  /// REGISTER
  /// ==========================================================

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final result =
          await SupabaseAuth.register(
        name: name,
        email: email,
        password: password,
        referralCode: referralCode,
      );

      if (result == null) {
        return _setError(
          'Registration failed. Please try again.',
        );
      }

      final accessToken =
          result['access_token']?.toString();

      final userJson =
          result['user'];

      /// ========================================================
      /// DIRECT REGISTRATION
      /// ========================================================
      ///
      /// Email confirmation should be disabled.
      ///
      /// Therefore a successful registration should return
      /// an access token and allow the user into the app.
      /// ========================================================

      if (accessToken == null ||
          accessToken.trim().isEmpty) {
        return _setError(
          'Account could not be activated. Please try again.',
        );
      }

      if (userJson is! Map) {
        return _setError(
          'Account created but could not be loaded.',
        );
      }

      final user =
          _createUserFromAuth(
        Map<String, dynamic>.from(
          userJson,
        ),
        nameOverride: name,
        referralOverride: referralCode,
      );

      await saveSession(
        accessToken,
        user,
      );

      _error = null;

      notifyListeners();

      return null;
    } catch (error) {
      return _setError(
        _friendlyError(error),
      );
    }
  }

  /// ==========================================================
  /// SAVE SESSION
  /// ==========================================================

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

    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'referralCode':
            user.referralCode,
        'referredBy':
            user.referredBy,
        'fanBalance':
            user.fanBalance,
        'afamBalance':
            user.afamBalance,
        'miningRate':
            user.miningRate,
        'activeReferrals':
            user.activeReferrals,
        'dailyAdsWatched':
            user.dailyAdsWatched,
        'adBoost':
            user.adBoost,
        'miningActive':
            user.miningActive,
      }),
    );

    notifyListeners();
  }

  /// ==========================================================
  /// REFRESH USER
  /// ==========================================================

  Future<bool> refreshUser() async {
    if (_token == null ||
        _token!.trim().isEmpty) {
      return false;
    }

    try {
      final currentUser =
          await SupabaseAuth.getCurrentUser(
        _token!,
      );

      if (currentUser == null) {
        await clearSession();
        return false;
      }

      _user =
          _createUserFromAuth(
        currentUser,
        oldUser: _user,
      );

      await _saveUser();

      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'REFRESH USER ERROR: $error',
      );

      return false;
    }
  }

  /// ==========================================================
  /// LOGOUT
  /// ==========================================================

  Future<void> logout() async {
    final token = _token;

    try {
      if (token != null &&
          token.trim().isNotEmpty) {
        await SupabaseAuth.logout(
          token,
        );
      }
    } catch (error) {
      debugPrint(
        'LOGOUT ERROR: $error',
      );
    }

    await clearSession();
  }

  /// ==========================================================
  /// CLEAR SESSION
  /// ==========================================================

  Future<void> clearSession() async {
    _token = null;
    _user = null;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _tokenKey,
    );

    await prefs.remove(
      _userKey,
    );

    await prefs.remove(
      'power_fan_backend_token',
    );

    _error = null;

    notifyListeners();
  }

  /// ==========================================================
  /// SAVE USER
  /// ==========================================================

  Future<void> _saveUser() async {
    if (_user == null) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': _user!.id,
        'name': _user!.name,
        'email': _user!.email,
        'referralCode':
            _user!.referralCode,
        'referredBy':
            _user!.referredBy,
        'fanBalance':
            _user!.fanBalance,
        'afamBalance':
            _user!.afamBalance,
        'miningRate':
            _user!.miningRate,
        'activeReferrals':
            _user!.activeReferrals,
        'dailyAdsWatched':
            _user!.dailyAdsWatched,
        'adBoost':
            _user!.adBoost,
        'miningActive':
            _user!.miningActive,
      }),
    );
  }

  /// ==========================================================
  /// CREATE USER
  /// ==========================================================

  BackendUser _createUserFromAuth(
    Map<String, dynamic> json, {
    BackendUser? oldUser,
    String? nameOverride,
    String? referralOverride,
  }) {
    final metadata =
        json['user_metadata'];

    final metadataMap =
        metadata is Map
            ? Map<String, dynamic>.from(
                metadata,
              )
            : <String, dynamic>{};

    final name =
        nameOverride ??
        metadataMap['name']?.toString() ??
        oldUser?.name ??
        '';

    final referralCode =
        metadataMap['referralCode']
            ?.toString() ??
        referralOverride ??
        oldUser?.referralCode ??
        '';

    return BackendUser(
      id:
          json['id']?.toString() ??
          oldUser?.id ??
          '',

      name:
          name,

      email:
          json['email']?.toString() ??
          oldUser?.email ??
          '',

      referralCode:
          referralCode,

      referredBy:
          oldUser?.referredBy,

      fanBalance:
          oldUser?.fanBalance ??
          0,

      afamBalance:
          oldUser?.afamBalance ??
          0,

      miningRate:
          oldUser?.miningRate ??
          0.2,

      activeReferrals:
          oldUser?.activeReferrals ??
          0,

      dailyAdsWatched:
          oldUser?.dailyAdsWatched ??
          0,

      adBoost:
          oldUser?.adBoost ??
          0,

      miningActive:
          oldUser?.miningActive ??
          false,
    );
  }

  /// ==========================================================
  /// ERROR
  /// ==========================================================

  String _setError(
    String message,
  ) {
    _error = message;

    notifyListeners();

    return message;
  }

  String _friendlyError(
    dynamic error,
  ) {
    final message =
        error.toString();

    if (message.contains(
      'SocketException',
    )) {
      return 'Could not connect. Check your internet connection.';
    }

    if (message.contains(
      'TimeoutException',
    )) {
      return 'The connection took too long. Please try again.';
    }

    if (message.contains(
      'Invalid login credentials',
    )) {
      return 'Invalid email or password.';
    }

    if (message.contains(
      'Email not confirmed',
    )) {
      return 'Unable to sign in. Please try again.';
    }

    if (message.contains(
      'User already registered',
    )) {
      return 'An account with this email already exists.';
    }

    if (message.contains(
      'Password should be at least',
    )) {
      return 'Password must be at least 6 characters.';
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
/// AUTH API
/// ============================================================

class SupabaseAuth {
  static const String _authPath =
      '/auth/v1';

  /// ==========================================================
  /// HEADERS
  /// ==========================================================

  static Map<String, String> _headers({
    String? token,
  }) {
    final headers =
        <String, String>{
      'Content-Type':
          'application/json',

      'Accept':
          'application/json',

      'apikey':
          SupabaseConfig.publishableKey,
    };

    if (token != null &&
        token.trim().isNotEmpty) {
      headers['Authorization'] =
          'Bearer $token';
    }

    return headers;
  }

  /// ==========================================================
  /// REGISTER
  /// ==========================================================

  static Future<
      Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    final response =
        await http
            .post(
              Uri.parse(
                '${SupabaseConfig.url}$_authPath/signup',
              ),
              headers:
                  _headers(),
              body:
                  jsonEncode({
                'email':
                    email.trim().toLowerCase(),

                'password':
                    password,

                'data': {
                  'name':
                      name.trim(),

                  if (referralCode != null &&
                      referralCode
                          .trim()
                          .isNotEmpty)
                    'referralCode':
                        referralCode
                            .trim()
                            .toUpperCase(),
                },
              }),
            )
            .timeout(
              SupabaseConfig.timeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ==========================================================
  /// LOGIN
  /// ==========================================================

  static Future<
      Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final response =
        await http
            .post(
              Uri.parse(
                '${SupabaseConfig.url}$_authPath/token?grant_type=password',
              ),
              headers:
                  _headers(),
              body:
                  jsonEncode({
                'email':
                    email.trim().toLowerCase(),

                'password':
                    password,
              }),
            )
            .timeout(
              SupabaseConfig.timeout,
            );

    return _handleResponse(
      response,
    );
  }

  /// ==========================================================
  /// CURRENT USER
  /// ==========================================================

  static Future<
      Map<String, dynamic>?> getCurrentUser(
    String token,
  ) async {
    final response =
        await http
            .get(
              Uri.parse(
                '${SupabaseConfig.url}$_authPath/user',
              ),
              headers:
                  _headers(
                token: token,
              ),
            )
            .timeout(
              SupabaseConfig.timeout,
            );

    if (response.statusCode ==
        401) {
      return null;
    }

    return _handleResponse(
      response,
    );
  }

  /// ==========================================================
  /// LOGOUT
  /// ==========================================================

  static Future<bool> logout(
    String token,
  ) async {
    try {
      final response =
          await http
              .post(
                Uri.parse(
                  '${SupabaseConfig.url}$_authPath/logout',
                ),
                headers:
                    _headers(
                  token: token,
                ),
              )
              .timeout(
                SupabaseConfig.timeout,
              );

      return response.statusCode >=
              200 &&
          response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// ==========================================================
  /// RESPONSE HANDLER
  /// ==========================================================

  static Map<String, dynamic>?
      _handleResponse(
    http.Response response,
  ) {
    Map<String, dynamic> data =
        {};

    try {
      if (response.body
          .trim()
          .isNotEmpty) {
        final decoded =
            jsonDecode(
          response.body,
        );

        if (decoded is Map) {
          data =
              Map<String, dynamic>.from(
            decoded,
          );
        }
      }
    } catch (_) {}

    if (response.statusCode >=
            200 &&
        response.statusCode < 300) {
      return data;
    }

    final message =
        data['msg']?.toString() ??
        data['message']?.toString() ??
        data['error_description']
            ?.toString() ??
        data['error']?.toString();

    if (message != null &&
        message.isNotEmpty) {
      throw Exception(message);
    }

    throw Exception(
      'Authentication request failed (${response.statusCode}).',
    );
  }
}

/// ============================================================
/// APP
/// ============================================================

class PowerFanNetworkApp
    extends StatelessWidget {
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
          debugShowCheckedModeBanner:
              false,

          title:
              'POWER FAN NETWORK',

          theme:
              ThemeData(
            useMaterial3:
                true,

            colorScheme:
                ColorScheme.fromSeed(
              seedColor:
                  const Color(
                0xFF3B159B,
              ),

              brightness:
                  Brightness.light,
            ),

            scaffoldBackgroundColor:
                const Color(
              0xFFF8F8FC,
            ),

            fontFamily:
                'Roboto',
          ),

          home:
              AuthGate(
            session:
                session,
          ),
        );
      },
    );
  }
}

/// ============================================================
/// AUTH GATE
/// ============================================================

class AuthGate
    extends StatelessWidget {
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
      session:
          session,
    );
  }
}

/// ============================================================
/// SPLASH
/// ============================================================

class SplashScreen
    extends StatelessWidget {
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

      body:
          Center(
        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.bolt_rounded,
              size: 80,
              color: Colors.white,
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              'POWER FAN NETWORK',
              style:
                  TextStyle(
                color:
                    Colors.white,

                fontSize:
                    22,

                fontWeight:
                    FontWeight.bold,

                letterSpacing:
                    1,
              ),
            ),

            SizedBox(
              height: 30,
            ),

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

class LoginPage
    extends StatefulWidget {
  final BackendSession session;

  const LoginPage({
    super.key,
    required this.session,
  });

  @override
  State<LoginPage>
      createState() =>
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

  bool _loading =
      false;

  bool _obscurePassword =
      true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey
        .currentState!
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

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });

    if (error != null) {
      _showError(error);
    }
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),

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
      body:
          SafeArea(
        child:
            Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(
              24,
            ),

            child:
                Form(
              key:
                  _formKey,

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,

                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 72,
                    color:
                        Color(
                      0xFF3B159B,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    'POWER FAN NETWORK',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(
                        0xFF241064,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Welcome back',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
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
                      labelText:
                          'Email',

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
                        onPressed:
                            () {
                          setState(
                            () {
                              _obscurePassword =
                                  !_obscurePassword;
                            },
                          );
                        },

                        icon:
                            Icon(
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
  State<RegisterPage>
      createState() =>
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

  bool _loading =
      false;

  bool _obscurePassword =
      true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey
        .currentState!
        .validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final referral =
        _referralController.text.trim();

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

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(error),

          behavior:
              SnackBarBehavior.floating,
        ),
      );

      return;
    }

    /// Registration is successful.
    ///
    /// Because the account is activated immediately,
    /// the AuthGate will move the user into the app.
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Create Account',
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            24,
          ),

          child:
              Form(
            key:
                _formKey,

            child:
                Column(
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
                      Color(
                    0xFF3B159B,
                  ),
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
                    labelText:
                        'Full Name',

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
                    labelText:
                        'Email',

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
                      onPressed:
                          () {
                        setState(
                          () {
                            _obscurePassword =
                                !_obscurePassword;
                          },
                        );
                      },

                      icon:
                          Icon(
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
