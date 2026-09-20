// lib/pages/reset_password_page.dart

import 'package:flutter/material.dart';

import 'auth_page.dart';
import '../services/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() =>
      _ResetPasswordPageState();
}

class _ResetPasswordPageState
    extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      await AuthService.instance.updatePassword(
        _passwordController.text,
      );

      await AuthService.instance.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AuthPage(),
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password updated successfully. Please sign in with your new password.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            40,
            24,
            30,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF241064),
                        Color(0xFF3B159B),
                        Color(0xFF5B16C9),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(22),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'POWER FAN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'NETWORK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                const Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFF3B159B),
                  size: 58,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Reset Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF241064),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'Create a new password for your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 28),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !_loading,
                  textInputAction:
                      TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter your new password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 21,
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
                            : Icons.visibility_off_outlined,
                        size: 21,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 14,
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Password must be at least 6 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  controller:
                      _confirmPasswordController,
                  obscureText:
                      _obscureConfirmPassword,
                  enabled: !_loading,
                  textInputAction:
                      TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_loading) {
                      _updatePassword();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText:
                        'Enter your new password again',
                    prefixIcon: const Icon(
                      Icons.lock_reset_outlined,
                      size: 21,
                    ),
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
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 21,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 14,
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Please confirm your password.';
                    }

                    if (value !=
                        _passwordController.text) {
                      return 'Passwords do not match.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : _updatePassword,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF3B159B),
                      foregroundColor: Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'POWER FAN NETWORK',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.7,
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
