import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals/app_constants.dart';
import '../globals/app_state.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _referralController =
      TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;

  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();

      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      if (email.isEmpty) {
        throw Exception('Email is required.');
      }

      if (!email.contains('@') || !email.contains('.')) {
        throw Exception('Please enter a valid email address.');
      }

      if (password.isEmpty) {
        throw Exception('Password is required.');
      }

      if (_isLogin) {
        await auth.login(
          email: email,
          password: password,
        );
      } else {
        final username = _usernameController.text.trim();
        final referralCode = _referralController.text.trim();

        if (username.isEmpty) {
          throw Exception('Username is required.');
        }

        if (username.length < 3) {
          throw Exception(
            'Username must be at least 3 characters.',
          );
        }

        if (password.length < 6) {
          throw Exception(
            'Password must be at least 6 characters.',
          );
        }

        await auth.register(
          username: username,
          email: email,
          password: password,
          referralCode:
              referralCode.isEmpty ? null : referralCode,
        );
      }

      if (!mounted) return;

      final appState = context.read<AppState>();

      await appState.refresh();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      String message = error.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }

      // Make common Supabase/Auth messages easier to understand.
      final lower = message.toLowerCase();

      if (lower.contains('invalid login credentials')) {
        message = 'Incorrect email or password.';
      } else if (lower.contains('user already registered') ||
          lower.contains('already registered')) {
        message = 'This email is already registered.';
      } else if (lower.contains('email not confirmed')) {
        message = 'Please confirm your email before logging in.';
      } else if (lower.contains('password should be at least')) {
        message = 'Password must be at least 6 characters.';
      } else if (lower.contains('network')) {
        message = 'Network error. Please check your internet connection.';
      }

      setState(() {
        _error = message;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  void _toggleMode() {
    if (_loading) return;

    setState(() {
      _isLogin = !_isLogin;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppConfig.primaryColor;

    return Scaffold(
      backgroundColor: AppConfig.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Card(
                elevation: 3,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),

                      // LOGO
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        AppConfig.brandName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _isLogin
                            ? 'Welcome back'
                            : 'Create your account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // USERNAME - REGISTER ONLY
                      if (!_isLogin) ...[
                        TextField(
                          controller: _usernameController,
                          enabled: !_loading,
                          textInputAction:
                              TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: 'Enter username',
                            prefixIcon: const Icon(
                              Icons.person_outline,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],

                      // EMAIL
                      TextField(
                        controller: _emailController,
                        enabled: !_loading,
                        keyboardType:
                            TextInputType.emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // PASSWORD
                      TextField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: _obscurePassword,
                        textInputAction: _isLogin
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onSubmitted:
                            _isLogin ? (_) => _submit() : null,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                          ),
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
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      // REFERRAL - REGISTER ONLY
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),

                        TextField(
                          controller: _referralController,
                          enabled: !_loading,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText:
                                'Referral Code (Optional)',
                            hintText:
                                'Enter referral code',
                            prefixIcon: const Icon(
                              Icons.group_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],

                      // ERROR
                      if (_error != null) ...[
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Colors.red.withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // LOGIN / REGISTER BUTTON
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                primaryColor.withOpacity(0.5),
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isLogin
                                      ? 'LOGIN'
                                      : 'REGISTER',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // SWITCH LOGIN / REGISTER
                      TextButton(
                        onPressed:
                            _loading ? null : _toggleMode,
                        child: Text(
                          _isLogin
                              ? 'Create Account'
                              : 'Have an Account? Login',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
