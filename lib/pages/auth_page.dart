import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'main_navigation_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthService>();

    bool success;

    if (_isLogin) {
      success = await auth.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      success = await auth.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        referralCode:
            _referralController.text.trim().isEmpty
                ? null
                : _referralController.text,
      );
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } else {
      final message =
          auth.error ??
          (_isLogin
              ? 'Login failed.'
              : 'Registration failed.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 480,
              ),
              child: Card(
                elevation: 2,
                child: Padding(
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
                          size: 64,
                          color:
                              Color(0xFF3B159B),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        const Text(
                          'POWER FAN NETWORK',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Color(0xFF3B159B),
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          _isLogin
                              ? 'Welcome back'
                              : 'Create your account',
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(
                          height: 28,
                        ),

                        if (!_isLogin) ...[
                          TextFormField(
                            controller:
                                _nameController,
                            textInputAction:
                                TextInputAction.next,
                            decoration:
                                const InputDecoration(
                              labelText: 'Name',
                              prefixIcon:
                                  Icon(
                                Icons.person_outline,
                              ),
                              border:
                                  OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (_isLogin) {
                                return null;
                              }

                              if (value == null ||
                                  value.trim().length <
                                      2) {
                                return 'Enter your name.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(
                            height: 16,
                          ),
                        ],

                        TextFormField(
                          controller:
                              _emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
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
                          validator: (value) {
                            final email =
                                value?.trim() ??
                                    '';

                            if (email.isEmpty) {
                              return 'Enter your email.';
                            }

                            if (!RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(email)) {
                              return 'Enter a valid email.';
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
                          textInputAction:
                              TextInputAction.done,
                          onFieldSubmitted:
                              (_) => _submit(),
                          decoration:
                              InputDecoration(
                            labelText:
                                'Password',
                            prefixIcon:
                                const Icon(
                              Icons.lock_outline,
                            ),
                            suffixIcon:
                                IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_off_outlined
                                    : Icons
                                        .visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                            ),
                            border:
                                const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }

                            return null;
                          },
                        ),

                        if (!_isLogin) ...[
                          const SizedBox(
                            height: 16,
                          ),
                          TextFormField(
                            controller:
                                _referralController,
                            textCapitalization:
                                TextCapitalization.characters,
                            textInputAction:
                                TextInputAction.done,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Referral Code (optional)',
                              prefixIcon:
                                  Icon(
                                Icons.group_add_outlined,
                              ),
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                        ],

                        const SizedBox(
                          height: 24,
                        ),

                        Consumer<AuthService>(
                          builder: (
                            context,
                            auth,
                            _,
                          ) {
                            if (auth.loading) {
                              return const SizedBox(
                                height: 52,
                                child: Center(
                                  child:
                                      CircularProgressIndicator(),
                                ),
                              );
                            }

                            return SizedBox(
                              height: 52,
                              child:
                                  ElevatedButton(
                                onPressed:
                                    _submit,
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
                                      12,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _isLogin
                                      ? 'LOGIN'
                                      : 'CREATE ACCOUNT',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextButton(
                          onPressed:
                              _toggleMode,
                          child: Text(
                            _isLogin
                                ? 'Create a new account'
                                : 'Already have an account? Login',
                          ),
                        ),
                      ],
                    ),
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
