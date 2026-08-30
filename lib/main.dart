import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Core kawai ake amfani da shi domin samun
  // project configuration. BA A AMFANI DA FIREBASE AUTH.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PowerFanNetworkApp());
}

// ============================================================
// APP
// ============================================================

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POWER FAN NETWORK',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B159B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// CUSTOM BACKEND SESSION
// ============================================================

class BackendSession {
  static String? token;
  static Map<String, dynamic>? user;

  static bool get isLoggedIn {
    return token != null && token!.isNotEmpty;
  }

  static void setSession({
    required String newToken,
    Map<String, dynamic>? userData,
  }) {
    token = newToken;
    user = userData;
  }

  static void clear() {
    token = null;
    user = null;
  }
}

// ============================================================
// BACKEND API
// ============================================================
//
// IMPORTANT:
// Backend ɗinmu zai kasance Cloud Functions + Firestore.
// Ba Firebase Authentication ba.
//
// Za mu yi endpoint kamar:
//
// POST /api/register
// POST /api/login
// POST /api/logout
// GET  /api/me
//
// ============================================================

class BackendApi {
  // Za a maye gurbin wannan da URL na Cloud Function
  // bayan mun gama backend.
  //
  // Misali:
  // https://us-central1-YOUR_PROJECT.cloudfunctions.net/api
  //
  // A yanzu kada ka canza komai a nan.
  static const String baseUrl =
      'https://us-central1-YOUR_PROJECT.cloudfunctions.net/api';

  // ==========================================================
  // HTTP REQUEST HELPER
  // ==========================================================

  static Future<ApiResponse> request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    String? authToken,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      // --------------------------------------------------------
      // NOTE:
      // HTTP implementation za mu haɗa da backend package
      // a mataki na gaba.
      //
      // Wannan class an tsara shi ne domin duk API calls
      // su kasance wuri guda.
      // --------------------------------------------------------

      return ApiResponse(
        success: false,
        message:
            'Backend connection is not configured yet.',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  static Future<ApiResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return request(
      method: 'POST',
      endpoint: '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
    );
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  static Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    return request(
      method: 'POST',
      endpoint: '/login',
      body: {
        'email': email,
        'password': password,
      },
    );
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  static Future<ApiResponse> logout() async {
    if (!BackendSession.isLoggedIn) {
      BackendSession.clear();

      return ApiResponse(
        success: true,
        message: 'Logged out.',
      );
    }

    final response = await request(
      method: 'POST',
      endpoint: '/logout',
      authToken: BackendSession.token,
    );

    BackendSession.clear();

    return response;
  }

  // ==========================================================
  // CURRENT USER
  // ==========================================================

  static Future<ApiResponse> me() async {
    return request(
      method: 'GET',
      endpoint: '/me',
      authToken: BackendSession.token,
    );
  }
}

// ============================================================
// API RESPONSE
// ============================================================

class ApiResponse {
  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? user;
  final dynamic data;

  ApiResponse({
    required this.success,
    required this.message,
    this.token,
    this.user,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiResponse(
      success: json['success'] == true,
      message:
          json['message']?.toString() ?? '',
      token:
          json['token']?.toString(),
      user: json['user'] is Map
          ? Map<String, dynamic>.from(
              json['user'] as Map,
            )
          : null,
      data: json['data'],
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (BackendSession.isLoggedIn) {
      return const HomePage();
    }

    return const LoginPage();
  }
}

// ============================================================
// LOGIN PAGE
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<void> loginWithBackend() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage(
        'Please enter your email and password.',
      );
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final response = await BackendApi.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (!response.success) {
        showMessage(response.message);
        return;
      }

      if (response.token == null ||
          response.token!.isEmpty) {
        showMessage(
          'Login succeeded but no session token was returned.',
        );
        return;
      }

      BackendSession.setSession(
        newToken: response.token!,
        userData: response.user,
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        showMessage(
          'Login failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // LOGO
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3B159B),
                          Color(0xFF241064),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'POWER FAN',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF241064),
                    ),
                  ),

                  const Text(
                    'NETWORK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Color(0xFF3B159B),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 25,
                          offset:
                              const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Sign in to your POWER FAN account.',
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 26),

                        const Text(
                          'Email',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller:
                              emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              InputDecoration(
                            hintText:
                                'Enter your email',
                            prefixIcon:
                                const Icon(
                              Icons
                                  .email_outlined,
                              color: Color(
                                0xFF3B159B,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                const Color(
                              0xFFF7F7FA,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                              borderSide:
                                  BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'Password',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller:
                              passwordController,
                          obscureText:
                              obscurePassword,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) {
                            if (!loading) {
                              loginWithBackend();
                            }
                          },
                          decoration:
                              InputDecoration(
                            hintText:
                                'Enter your password',
                            prefixIcon:
                                const Icon(
                              Icons.lock_outline,
                              color: Color(
                                0xFF3B159B,
                              ),
                            ),
                            suffixIcon:
                                IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword =
                                      !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons
                                        .visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                const Color(
                              0xFFF7F7FA,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                              borderSide:
                                  BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : loginWithBackend,
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF3B159B,
                              ),
                              foregroundColor:
                                  Colors.white,
                              elevation: 0,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  15,
                                ),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
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
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Center(
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Flexible(
                                child: Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors
                                        .grey
                                        .shade600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: Color(
                                      0xFF3B159B,
                                    ),
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'POWER FAN NETWORK • AFAM',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
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
// REGISTER PAGE
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController =
      TextEditingController();
  final confirmController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  Future<void> registerWithBackend() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      showMessage(
        'Please fill all fields.',
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (password != confirm) {
      showMessage(
        'Passwords do not match.',
      );
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      final response =
          await BackendApi.register(
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (!response.success) {
        showMessage(response.message);
        return;
      }

      // Idan backend ya dawo da token,
      // user zai shiga kai tsaye.
      if (response.token != null &&
          response.token!.isNotEmpty) {
        BackendSession.setSession(
          newToken: response.token!,
          userData: response.user,
        );

        Navigator.of(context)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
          (route) => false,
        );

        return;
      }

      showMessage(
        'Account created successfully. Please login.',
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showMessage(
          'Registration failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
        ),
        foregroundColor:
            const Color(0xFF241064),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 70,
                color: Color(0xFF3B159B),
              ),

              const SizedBox(height: 20),

              const Text(
                'Create your POWER FAN account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: nameController,
                textInputAction:
                    TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                  ),
                  filled: true,
                  fillColor:
                      const Color(0xFFF7F7FA),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                  filled: true,
                  fillColor:
                      const Color(0xFFF7F7FA),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller:
                    passwordController,
                obscureText: obscurePassword,
                textInputAction:
                    TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword =
                            !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons
                              .visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      const Color(0xFFF7F7FA),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller:
                    confirmController,
                obscureText: obscureConfirm,
                textInputAction:
                    TextInputAction.done,
                onSubmitted: (_) {
                  if (!loading) {
                    registerWithBackend();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirm =
                            !obscureConfirm;
                      });
                    },
                    icon: Icon(
                      obscureConfirm
                          ? Icons
                              .visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      const Color(0xFFF7F7FA),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : registerWithBackend,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF3B159B),
                    foregroundColor:
                        Colors.white,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
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
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = BackendSession.user;

    final name =
        user?['name']?.toString() ?? 'POWER FAN User';

    final email =
        user?['email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'POWER FAN NETWORK',
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await BackendApi.logout();

              if (!context.mounted) return;

              Navigator.of(context)
                  .pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) =>
                      const LoginPage(),
                ),
                (route) => false,
              );
            },
            icon: const Icon(
              Icons.logout,
            ),
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
                Icons.bolt_rounded,
                size: 80,
                color: Color(0xFF3B159B),
              ),

              const SizedBox(height: 20),

              const Text(
                'Welcome to POWER FAN NETWORK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Connected to POWER FAN custom backend.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                'Database: Cloud Firestore',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
