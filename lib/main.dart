import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';
import 'screens/main_navigation_screen.dart';

const String supabaseUrl =
    'https://fihtqejqpycuvebufjhc.supabase.co';

const String supabasePublishableKey =
    'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabasePublishableKey,
  );

  runApp(const PowerFanNetworkApp());
}

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POWER FAN NETWORK',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4B16B8),
        ),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return const MainNavigationScreen();
        }

        return const LoginPage();
      },
    );
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      if (!mounted) return;

      String message = 'Login failed. Please check your details.';

      if (e is AuthException) {
        message = e.message;
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            child: Column(
              children: [
                const _PowerFanLogo(),

                const SizedBox(height: 38),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF241064),
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sign in to continue to your account',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF77727F),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                _InputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 17),

                _InputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 27),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B16B8),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF8D70C9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 23,
                            width: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: Color(0xFF77727F),
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RegisterPage(),
                                ),
                              );
                            },
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          color: Color(0xFF4B16B8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
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
// REGISTER PAGE
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();

  final _authService = AuthService();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty) {
      _showMessage('Please enter a username.');
      return;
    }

    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters.');
      return;
    }

    if (email.isEmpty) {
      _showMessage('Please enter your email.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _authService.register(
        email: email,
        password: password,
        username: username,
        referralCode: _referralController.text.trim(),
      );

      if (!mounted) return;

      // If signup immediately returns a session,
      // AuthGate will automatically open the app.
      if (Supabase.instance.client.auth.currentSession != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showMessage(
          'Account created. Please sign in to continue.',
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      String message =
          'Registration failed. Please try again.';

      if (e is AuthException) {
        message = e.message;
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _loading
              ? null
              : () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF241064),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            28,
            8,
            28,
            35,
          ),
          child: Column(
            children: [
              const _PowerFanLogo(size: 74),

              const SizedBox(height: 24),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF241064),
                  ),
                ),
              ),

              const SizedBox(height: 7),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Join POWER FAN NETWORK today',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF77727F),
                  ),
                ),
              ),

              const SizedBox(height: 27),

              _InputField(
                controller: _usernameController,
                label: 'Username',
                hint: 'Choose a username',
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 16),

              _InputField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              _InputField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _InputField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Repeat your password',
                icon: Icons.lock_reset_outlined,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword =
                          !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _InputField(
                controller: _referralController,
                label: 'Referral Code',
                hint: 'Optional',
                icon: Icons.group_add_outlined,
                textCapitalization: TextCapitalization.characters,
              ),

              const SizedBox(height: 27),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B16B8),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF8D70C9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 2,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 23,
                          width: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 19),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(
                      color: Color(0xFF77727F),
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Color(0xFF4B16B8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOGO
// ============================================================

class _PowerFanLogo extends StatelessWidget {
  final double size;

  const _PowerFanLogo({
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B22D9),
                Color(0xFF321080),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4B16B8)
                    .withOpacity(0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 52,
            ),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'POWER FAN',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4214A5),
            letterSpacing: 0.4,
          ),
        ),

        const Text(
          'NETWORK',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF8B35D6),
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// INPUT FIELD
// ============================================================

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3E3946),
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          enabled: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFA19CA8),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF5A25B7),
              size: 21,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE4E0EA),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF5A25B7),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
