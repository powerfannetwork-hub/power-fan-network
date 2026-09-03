import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals/app_constants.dart';
import '../globals/app_state.dart';
import '../services/auth_service.dart';
import '../screens/main_navigation_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
  });

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

      final email =
          _emailController.text.trim().toLowerCase();

      final password =
          _passwordController.text;

      if (email.isEmpty) {
        throw Exception(
          'Email is required.',
        );
      }

      if (password.isEmpty) {
        throw Exception(
          'Password is required.',
        );
      }

      if (_isLogin) {
        await auth.login(
          email: email,
          password: password,
        );
      } else {
        final username =
            _usernameController.text.trim();

        if (username.isEmpty) {
          throw Exception(
            'Username is required.',
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
              _referralController.text.trim().isEmpty
                  ? null
                  : _referralController.text.trim(),
        );
      }

      if (!mounted) return;

      final appState =
          context.read<AppState>();

      await appState.refresh();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      String message = error.toString();

      if (message.startsWith('Exception: ')) {
        message =
            message.substring('Exception: '.length);
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
    final primaryColor =
        AppConfig.primaryColor;

    return Scaffold(
      backgroundColor:
          AppConfig.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 460,
              ),
              child: Card(
                elevation: 3,
                margin: EdgeInsets.zero,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(24),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        height: 8,
                      ),

                      Icon(
                        Icons.bolt_rounded,
                        size: 64,
                        color: primaryColor,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Text(
                        AppConfig.brandName,
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              primaryColor,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        _isLogin
                            ? 'Welcome back'
                            : 'Create your account',
                        textAlign:
                            TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color:
                              Colors.black54,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      if (!_isLogin) ...[
                        TextField(
                          controller:
                              _usernameController,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              InputDecoration(
                            labelText:
                                'Username',
                            prefixIcon:
                                const Icon(
                              Icons.person_outline,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(14),
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),
                      ],

                      TextField(
                        controller:
                            _emailController,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Email',
                          prefixIcon:
                              const Icon(
                            Icons.email_outlined,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      TextField(
                        controller:
                            _passwordController,
                        obscureText: true,
                        textInputAction:
                            _isLogin
                                ? TextInputAction
                                    .done
                                : TextInputAction
                                    .next,
                        onSubmitted:
                            _isLogin
                                ? (_) => _submit()
                                : null,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Password',
                          prefixIcon:
                              const Icon(
                            Icons.lock_outline,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(14),
                          ),
                        ),
                      ),

                      if (!_isLogin) ...[
                        const SizedBox(
                          height: 16,
                        ),

                        TextField(
                          controller:
                              _referralController,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted:
                              (_) => _submit(),
                          decoration:
                              InputDecoration(
                            labelText:
                                'Referral Code (Optional)',
                            prefixIcon:
                                const Icon(
                              Icons.group_outlined,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(14),
                            ),
                          ),
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(
                          height: 16,
                        ),

                        Container(
                          padding:
                              const EdgeInsets.all(
                            12,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.red
                                    .withOpacity(
                              0.08,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(12),
                          ),
                          child: Text(
                            _error!,
                            style:
                                const TextStyle(
                              color:
                                  Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 22,
                      ),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _loading
                                  ? null
                                  : _submit,
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                primaryColor,
                            foregroundColor:
                                Colors.white,
                            disabledBackgroundColor:
                                primaryColor
                                    .withOpacity(
                              0.5,
                            ),
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
                                  style:
                                      const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      TextButton(
                        onPressed:
                            _loading
                                ? null
                                : _toggleMode,
                        child: Text(
                          _isLogin
                              ? 'Create Account'
                              : 'Have an Account? Login',
                          style: TextStyle(
                            color:
                                primaryColor,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),
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
