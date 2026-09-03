import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'globals/app_constants.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/force_update_screen.dart';
import 'services/auth_service.dart';
import 'services/app_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  runApp(
    const PowerFanNetworkApp(),
  );
}

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppConfig.lightBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConfig.primaryColor,
        ),
        fontFamily: 'Roboto',
      ),
      home: const StartupGate(),
    );
  }
}

// ============================================================
// STARTUP GATE
// ============================================================

class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
  });

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<AppUpdateInfo> _updateCheck;

  @override
  void initState() {
    super.initState();

    _updateCheck = AppUpdateService.instance.checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUpdateInfo>(
      future: _updateCheck,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StartupLoading();
        }

        // If update checking fails, do not lock the user out.
        if (snapshot.hasError || !snapshot.hasData) {
          return const AuthGate();
        }

        final updateInfo = snapshot.data!;

        if (updateInfo.updateRequired) {
          return ForceUpdateScreen(
            currentVersion: updateInfo.currentVersion,
            minimumSupportedVersion:
                updateInfo.minimumSupportedVersion,
          );
        }

        return const AuthGate();
      },
    );
  }
}

// ============================================================
// STARTUP LOADING
// ============================================================

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.lightBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6B2BDE),
                    Color(0xFF35108C),
                  ],
                ),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 55,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppConfig.brandName,
              style: const TextStyle(
                color: AppConfig.deepPurple,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppConfig.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    final session = client.auth.currentSession;

    if (session != null && !session.isExpired) {
      return const MainNavigationScreen();
    }

    return StreamBuilder<AuthState>(
      stream: AuthService.instance.authStateChanges,
      builder: (
        context,
        snapshot,
      ) {
        final currentSession = client.auth.currentSession;

        if (currentSession != null && !currentSession.isExpired) {
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
  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
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
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Please enter your email and password.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await AuthService.instance.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 25),

                const _PowerFanLogo(),

                const SizedBox(height: 45),

                const Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppConfig.deepPurple,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Sign in to continue to POWER FAN NETWORK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 35),

                _InputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                ),

                const SizedBox(height: 18),

                _InputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  enabled: !_loading,
                  suffixIcon: IconButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                _PrimaryButton(
                  text: 'LOGIN',
                  loading: _loading,
                  onPressed: _loading ? null : _login,
                ),

                const SizedBox(height: 22),

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
                      color: AppConfig.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
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
  const RegisterPage({
    super.key,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _referralController =
      TextEditingController();

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
    final referral = _referralController.text.trim();

    if (username.isEmpty) {
      _showMessage('Please enter a username.');
      return;
    }

    if (username.length < 3) {
      _showMessage(
        'Username must be at least 3 characters.',
      );
      return;
    }

    if (email.isEmpty) {
      _showMessage('Please enter your email.');
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must be at least 6 characters.',
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await AuthService.instance.register(
        username: username,
        email: email,
        password: password,
        referralCode: referral.isEmpty ? null : referral,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppConfig.deepPurple,
          ),
          onPressed: _loading
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            28,
            5,
            28,
            35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Join POWER FAN NETWORK today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF696773),
                ),
              ),

              const SizedBox(height: 32),

              _InputField(
                controller: _usernameController,
                label: 'Username',
                hint: 'Choose a username',
                icon: Icons.person_outline,
                enabled: !_loading,
              ),

              const SizedBox(height: 18),

              _InputField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !_loading,
              ),

              const SizedBox(height: 18),

              _InputField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                enabled: !_loading,
                suffixIcon: IconButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _InputField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm your password',
                icon: Icons.lock_reset_outlined,
                obscureText: _obscureConfirmPassword,
                enabled: !_loading,
                suffixIcon: IconButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                          });
                        },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              _InputField(
                controller: _referralController,
                label: 'Referral Code',
                hint: 'Optional',
                icon: Icons.group_add_outlined,
                enabled: !_loading,
              ),

              const SizedBox(height: 30),

              _PrimaryButton(
                text: 'CREATE ACCOUNT',
                loading: _loading,
                onPressed: _loading ? null : _register,
              ),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppConfig.primaryColor,
                        fontSize: 16,
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
  const _PowerFanLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6B2BDE),
                Color(0xFF35108C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppConfig.primaryColor.withOpacity(0.25),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.bolt_rounded,
              size: 58,
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 15),

        const Text(
          'POWER FAN',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppConfig.deepPurple,
          ),
        ),

        const Text(
          'NETWORK',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
            color: Color(0xFF7B35D1),
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
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF45434C),
          ),
        ),

        const SizedBox(height: 9),

        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF9A98A2),
            ),
            prefixIcon: Icon(
              icon,
              color: AppConfig.primaryColor,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 19,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFE0DEE5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFE0DEE5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: AppConfig.primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PRIMARY BUTTON
// ============================================================

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppConfig.primaryColor.withOpacity(0.65),
          disabledForegroundColor: Colors.white70,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
