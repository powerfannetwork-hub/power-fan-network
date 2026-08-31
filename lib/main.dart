import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = AppSession();
  await session.initialize();

  runApp(
    PowerFanNetworkApp(session: session),
  );
}

// ============================================================
// SUPABASE CONFIG
// ============================================================

class SupabaseConfig {
  static const String url =
      'https://fihtqejqpycuvebufjhc.supabase.co';

  static const String publishableKey =
      'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

  static const Duration timeout =
      Duration(seconds: 30);
}

// ============================================================
// APP SESSION
// ============================================================

class AppSession extends ChangeNotifier {
  static const String _accessTokenKey =
      'power_fan_access_token';

  static const String _userKey =
      'power_fan_user';

  String? _accessToken;
  Map<String, dynamic>? _user;

  bool _loading = true;
  String? _error;

  bool get loading => _loading;
  bool get isLoggedIn =>
      _accessToken != null &&
      _accessToken!.isNotEmpty &&
      _user != null;

  String? get error => _error;
  Map<String, dynamic>? get user => _user;

  String get userName {
    return _user?['user_metadata']?['name']?.toString() ??
        _user?['name']?.toString() ??
        '';
  }

  String get userEmail {
    return _user?['email']?.toString() ?? '';
  }

  // ==========================================================
  // INITIALIZE
  // ==========================================================

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final token =
          prefs.getString(_accessTokenKey);

      final savedUser =
          prefs.getString(_userKey);

      if (token == null || token.isEmpty) {
        return;
      }

      _accessToken = token;

      if (savedUser != null &&
          savedUser.isNotEmpty) {
        try {
          final decoded =
              jsonDecode(savedUser);

          if (decoded is Map) {
            _user =
                Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      // Check token with Supabase.
      final currentUser =
          await SupabaseAuth.getCurrentUser(
        token,
      );

      if (currentUser == null) {
        await logout();
      } else {
        _user = currentUser;
        await _saveUser();
      }
    } catch (e) {
      debugPrint(
        'SESSION INITIALIZE ERROR: $e',
      );

      // Keep local session if internet is temporarily unavailable.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

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
          'Registration failed.',
        );
      }

      final accessToken =
          result['access_token']?.toString();

      final user =
          result['user'];

      // Email confirmation may be enabled.
      if (accessToken == null ||
          accessToken.isEmpty) {
        return _setError(
          'Account created successfully. Please check your email and confirm your account, then login.',
        );
      }

      if (user is! Map) {
        return _setError(
          'Account created, but user information was not returned.',
        );
      }

      _accessToken = accessToken;

      _user =
          Map<String, dynamic>.from(user);

      await _saveSession();

      _error = null;
      notifyListeners();

      return null;
    } catch (e) {
      return _setError(
        _friendlyError(e),
      );
    }
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

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
          'Login failed.',
        );
      }

      final accessToken =
          result['access_token']?.toString();

      final user =
          result['user'];

      if (accessToken == null ||
          accessToken.isEmpty) {
        return _setError(
          'Login succeeded but no session token was returned.',
        );
      }

      if (user is! Map) {
        return _setError(
          'Login succeeded but user information was not returned.',
        );
      }

      _accessToken = accessToken;

      _user =
          Map<String, dynamic>.from(user);

      await _saveSession();

      _error = null;
      notifyListeners();

      return null;
    } catch (e) {
      return _setError(
        _friendlyError(e),
      );
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    final token = _accessToken;

    try {
      if (token != null &&
          token.isNotEmpty) {
        await SupabaseAuth.logout(token);
      }
    } catch (_) {}

    _accessToken = null;
    _user = null;
    _error = null;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userKey);

    notifyListeners();
  }

  // ==========================================================
  // SAVE
  // ==========================================================

  Future<void> _saveSession() async {
    final prefs =
        await SharedPreferences.getInstance();

    if (_accessToken != null) {
      await prefs.setString(
        _accessTokenKey,
        _accessToken!,
      );
    }

    await _saveUser();
  }

  Future<void> _saveUser() async {
    if (_user == null) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _userKey,
      jsonEncode(_user),
    );
  }

  // ==========================================================
  // ERROR
  // ==========================================================

  String _setError(String message) {
    _error = message;
    notifyListeners();
    return message;
  }

  String _friendlyError(dynamic error) {
    final message =
        error.toString();

    if (message.contains(
      'Invalid login credentials',
    )) {
      return 'Invalid email or password.';
    }

    if (message.contains(
      'Email not confirmed',
    )) {
      return 'Please confirm your email before logging in.';
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

    if (message.contains(
      'SocketException',
    )) {
      return 'Could not connect to Supabase. Check your internet connection.';
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

// ============================================================
// SUPABASE AUTH
// ============================================================

class SupabaseAuth {
  static Map<String, String> _headers({
    String? token,
  }) {
    final headers =
        <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey':
          SupabaseConfig.publishableKey,
    };

    if (token != null &&
        token.isNotEmpty) {
      headers['Authorization'] =
          'Bearer $token';
    }

    return headers;
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  static Future<Map<String, dynamic>?>
      register({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    final response =
        await http
            .post(
              Uri.parse(
                '${SupabaseConfig.url}/auth/v1/signup',
              ),
              headers: _headers(),
              body: jsonEncode({
                'email':
                    email.trim().toLowerCase(),
                'password':
                    password,
                'data': {
                  'name':
                      name.trim(),
                  if (referralCode != null &&
                      referralCode.trim().isNotEmpty)
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

    return _handleResponse(response);
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  static Future<Map<String, dynamic>?>
      login({
    required String email,
    required String password,
  }) async {
    final response =
        await http
            .post(
              Uri.parse(
                '${SupabaseConfig.url}/auth/v1/token?grant_type=password',
              ),
              headers: _headers(),
              body: jsonEncode({
                'email':
                    email.trim().toLowerCase(),
                'password':
                    password,
              }),
            )
            .timeout(
              SupabaseConfig.timeout,
            );

    return _handleResponse(response);
  }

  // ==========================================================
  // CURRENT USER
  // ==========================================================

  static Future<Map<String, dynamic>?>
      getCurrentUser(
    String token,
  ) async {
    final response =
        await http
            .get(
              Uri.parse(
                '${SupabaseConfig.url}/auth/v1/user',
              ),
              headers: _headers(
                token: token,
              ),
            )
            .timeout(
              SupabaseConfig.timeout,
            );

    if (response.statusCode == 401) {
      return null;
    }

    return _handleResponse(response);
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  static Future<bool> logout(
    String token,
  ) async {
    try {
      final response =
          await http
              .post(
                Uri.parse(
                  '${SupabaseConfig.url}/auth/v1/logout',
                ),
                headers: _headers(
                  token: token,
                ),
              )
              .timeout(
                SupabaseConfig.timeout,
              );

      return response.statusCode >= 200 &&
          response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================
  // RESPONSE
  // ==========================================================

  static Map<String, dynamic>?
      _handleResponse(
    http.Response response,
  ) {
    Map<String, dynamic> data = {};

    try {
      if (response.body.trim().isNotEmpty) {
        final decoded =
            jsonDecode(response.body);

        if (decoded is Map) {
          data =
              Map<String, dynamic>.from(
            decoded,
          );
        }
      }
    } catch (_) {}

    if (response.statusCode >= 200 &&
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

// ============================================================
// APP
// ============================================================

class PowerFanNetworkApp
    extends StatelessWidget {
  final AppSession session;

  const PowerFanNetworkApp({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'POWER FAN NETWORK',

          theme: ThemeData(
            useMaterial3: true,

            colorScheme:
                ColorScheme.fromSeed(
              seedColor:
                  const Color(0xFF3B159B),
              brightness:
                  Brightness.light,
            ),

            scaffoldBackgroundColor:
                const Color(0xFFF8F8FC),

            fontFamily: 'Roboto',
          ),

          home:
              AuthGate(session: session),
        );
      },
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  final AppSession session;

  const AuthGate({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    if (session.loading) {
      return const SplashScreen();
    }

    if (session.isLoggedIn) {
      return HomePage(session: session);
    }

    return LoginPage(session: session);
  }
}

// ============================================================
// SPLASH
// ============================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  final AppSession session;

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
      email: _emailController.text,
      password:
          _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
    });

    if (error != null) {
      _showMessage(error);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    CrossAxisAlignment
                        .stretch,

                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 75,
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
                      color: Colors.grey,
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
                          Icon(Icons
                              .email_outlined),
                      border:
                          OutlineInputBorder(),
                    ),

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
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
                      labelText: 'Password',

                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
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

                    validator: (value) {
                      if (value == null ||
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
                                  .circular(14),
                        ),
                      ),

                      child: _loading
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
                                fontSize: 16,
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

                    child: const Text(
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

// ============================================================
// REGISTER
// ============================================================

class RegisterPage extends StatefulWidget {
  final AppSession session;

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
        _referralController.text.trim();

    final error =
        await widget.session.register(
      name: _nameController.text,
      email: _emailController.text,
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
      _showMessage(error);
      return;
    }

    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Create Account'),
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
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
                    labelText:
                        'Full Name',
                    prefixIcon:
                        Icon(Icons
                            .person_outline),
                    border:
                        OutlineInputBorder(),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().length <
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
                        Icon(Icons
                            .email_outlined),
                    border:
                        OutlineInputBorder(),
                  ),

                  validator: (value) {
                    if (value == null ||
                        !value.contains('@')) {
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
                    labelText: 'Password',

                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
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

                  validator: (value) {
                    if (value == null ||
                        value.length < 6) {
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
                        Icon(Icons
                            .card_giftcard_outlined),
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
                                .circular(14),
                      ),
                    ),

                    child: _loading
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
                              fontSize: 16,
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

// ============================================================
// TEMPORARY HOME
// ============================================================
//
// Wannan temporary ne domin mu tabbatar Login yana aiki.
// Daga baya za mu maye gurbinsa da MainNavigationScreen
// lokacin da muka gama backend/mining.
// ============================================================

class HomePage extends StatelessWidget {
  final AppSession session;

  const HomePage({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        session.userName;

    final email =
        session.userEmail;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('POWER FAN NETWORK'),

        actions: [
          IconButton(
            onPressed: () async {
              await session.logout();
            },
            icon:
                const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),

      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 90,
                color:
                    Color(0xFF159B61),
              ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'LOGIN SUCCESSFUL',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF241064),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                name.isEmpty
                    ? 'Welcome!'
                    : 'Welcome, $name',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                email,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              const Text(
                'Supabase Authentication is working.',
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Mining backend will be added next.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
