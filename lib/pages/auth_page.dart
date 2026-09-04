import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      if (_isLogin) {
        await AuthService.instance.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await AuthService.instance.register(
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          referralCode:
              _referralController.text.trim().isEmpty
                  ? null
                  : _referralController.text,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email address first.');
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      await AuthService.instance.resetPassword(email);

      if (!mounted) return;

      _showMessage(
        'Password reset email sent. Check your inbox.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e));
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

  String _cleanError(Object error) {
    var message = error.toString();

    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    if (message.startsWith('AuthException: ')) {
      message = message.substring(14);
    }

    return message.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : message.trim();
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF3B159B);
    const deepPurple = Color(0xFF241064);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryPurple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'PF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'POWER FAN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: deepPurple,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Mine FAN. Earn More',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _modeButton(
                            title: 'LOGIN',
                            selected: _isLogin,
                            onTap: () {
                              if (_loading) return;

                              setState(() {
                                _isLogin = true;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _modeButton(
                            title: 'REGISTER',
                            selected: !_isLogin,
                            onTap: () {
                              if (_loading) return;

                              setState(() {
                                _isLogin = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  if (!_isLogin) ...[
                    _inputField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'Enter username',
                      icon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Username is required.';
                        }

                        if (value.trim().length < 3) {
                          return 'Username must be at least 3 characters.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  _inputField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email =
                          value?.trim() ?? '';

                      if (email.isEmpty) {
                        return 'Email is required.';
                      }

                      if (!email.contains('@') ||
                          !email.contains('.')) {
                        return 'Enter a valid email.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  _inputField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () {
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
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Password is required.';
                      }

                      if (!_isLogin &&
                          value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }

                      return null;
                    },
                  ),

                  if (!_isLogin) ...[
                    const SizedBox(height: 14),
                    _inputField(
                      controller: _referralController,
                      label: 'Referral Code',
                      hint: 'Optional',
                      icon: Icons.group_add_outlined,
                      textCapitalization:
                          TextCapitalization.characters,
                    ),
                  ],

                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            _loading
                                ? null
                                : _resetPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: primaryPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        disabledBackgroundColor:
                            primaryPurple.withOpacity(0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
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
                                  : 'CREATE ACCOUNT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _isLogin
                        ? 'Login to continue mining FAN.'
                        : 'Create your POWER FAN account and start mining.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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

  Widget _modeButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const primaryPurple = Color(0xFF3B159B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color:
              selected
                  ? primaryPurple
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                selected
                    ? Colors.white
                    : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
  }) {
    const primaryPurple = Color(0xFF3B159B);

    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      enabled: !_loading,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: primaryPurple,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primaryPurple,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}
