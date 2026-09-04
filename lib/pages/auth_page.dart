import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../localization/language_controller.dart';
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

  String _t(BuildContext context, String key) {
    return AppLocalizations.of(context).translate(key);
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
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
        );
      } else {
        await AuthService.instance.register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
          referralCode:
              _referralController.text.trim().isEmpty
                  ? null
                  : _referralController.text.trim(),
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
      _showMessage(
        _t(context, 'enter_email_first'),
      );
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      await AuthService.instance.resetPassword(email);

      if (!mounted) return;

      _showMessage(
        _t(context, 'password_reset_sent'),
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

    if (message.trim().isEmpty) {
      return _t(context, 'something_wrong');
    }

    final lower = message.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return _t(context, 'invalid_credentials');
    }

    if (lower.contains('email not confirmed')) {
      return _t(context, 'email_not_confirmed');
    }

    if (lower.contains('user already registered')) {
      return _t(context, 'email_already_registered');
    }

    if (lower.contains('password')) {
      if (lower.contains('at least')) {
        return _t(context, 'password_minimum');
      }
    }

    return message.trim();
  }

  void _changeLanguage(String languageCode) {
    context.read<LanguageController>().setLanguage(
          languageCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF3B159B);
    const deepPurple = Color(0xFF241064);

    final languageController =
        context.watch<LanguageController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                22,
                76,
                22,
                22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // LOGO
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: primaryPurple,
                              borderRadius:
                                  BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryPurple
                                      .withOpacity(0.20),
                                  blurRadius: 18,
                                  offset:
                                      const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'PF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // APP NAME
                        Text(
                          _t(context, 'power_fan'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: deepPurple,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // TAGLINE
                        Text(
                          _t(context, 'mine_fan_earn_more'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // LOGIN / REGISTER SWITCH
                        Container(
                          padding:
                              const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _modeButton(
                                  title:
                                      _t(context, 'login'),
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
                                  title:
                                      _t(context, 'register'),
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

                        // USERNAME
                        if (!_isLogin) ...[
                          _inputField(
                            controller:
                                _usernameController,
                            label:
                                _t(context, 'username'),
                            hint:
                                _t(context, 'enter_username'),
                            icon:
                                Icons.person_outline_rounded,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return _t(
                                  context,
                                  'username_required',
                                );
                              }

                              if (value.trim().length < 3) {
                                return _t(
                                  context,
                                  'username_minimum',
                                );
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // EMAIL
                        _inputField(
                          controller: _emailController,
                          label: _t(context, 'email'),
                          hint:
                              _t(context, 'enter_email'),
                          icon: Icons.email_outlined,
                          keyboardType:
                              TextInputType.emailAddress,
                          validator: (value) {
                            final email =
                                value?.trim() ?? '';

                            if (email.isEmpty) {
                              return _t(
                                context,
                                'email_required',
                              );
                            }

                            if (!email.contains('@') ||
                                !email.contains('.')) {
                              return _t(
                                context,
                                'valid_email',
                              );
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // PASSWORD
                        _inputField(
                          controller:
                              _passwordController,
                          label:
                              _t(context, 'password'),
                          hint:
                              _t(context, 'enter_password'),
                          icon:
                              Icons.lock_outline_rounded,
                          obscureText:
                              _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return _t(
                                context,
                                'password_required',
                              );
                            }

                            if (!_isLogin &&
                                value.length < 6) {
                              return _t(
                                context,
                                'password_minimum',
                              );
                            }

                            return null;
                          },
                        ),

                        // REFERRAL
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          _inputField(
                            controller:
                                _referralController,
                            label: _t(
                              context,
                              'referral_code',
                            ),
                            hint:
                                _t(context, 'optional'),
                            icon:
                                Icons.group_add_outlined,
                            textCapitalization:
                                TextCapitalization
                                    .characters,
                          ),
                        ],

                        // FORGOT PASSWORD
                        if (_isLogin)
                          Align(
                            alignment:
                                Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _loading
                                      ? null
                                      : _resetPassword,
                              child: Text(
                                _t(
                                  context,
                                  'forgot_password',
                                ),
                                style: const TextStyle(
                                  color: primaryPurple,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // MAIN BUTTON
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                _loading
                                    ? null
                                    : _submit,
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  primaryPurple,
                              disabledBackgroundColor:
                                  primaryPurple
                                      .withOpacity(0.6),
                              elevation: 0,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
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
                                        ? _t(
                                            context,
                                            'login',
                                          )
                                        : _t(
                                            context,
                                            'create_account',
                                          ),
                                    style:
                                        const TextStyle(
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

                        // FOOTER
                        Text(
                          _isLogin
                              ? _t(
                                  context,
                                  'login_continue',
                                )
                              : _t(
                                  context,
                                  'create_account_start',
                                ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // LANGUAGE CURRENT
                        Text(
                          languageController
                              .languageCode
                              .toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: primaryPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // LANGUAGE SELECTOR
            Positioned(
              top: 10,
              right: 16,
              child: _languageSelector(
                context,
                languageController.languageCode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageSelector(
    BuildContext context,
    String currentLanguage,
  ) {
    const primaryPurple = Color(0xFF3B159B);

    return PopupMenuButton<String>(
      enabled: !_loading,
      onSelected: _changeLanguage,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 'en',
            child: Text('🇬🇧  English'),
          ),
          PopupMenuItem(
            value: 'zh',
            child: Text('🇨🇳  中文'),
          ),
          PopupMenuItem(
            value: 'es',
            child: Text('🇪🇸  Español'),
          ),
          PopupMenuItem(
            value: 'fr',
            child: Text('🇫🇷  Français'),
          ),
          PopupMenuItem(
            value: 'ar',
            child: Text('🇸🇦  العربية'),
          ),
          PopupMenuItem(
            value: 'hi',
            child: Text('🇮🇳  हिन्दी'),
          ),
          PopupMenuItem(
            value: 'bn',
            child: Text('🇧🇩  বাংলা'),
          ),
          PopupMenuItem(
            value: 'ru',
            child: Text('🇷🇺  Русский'),
          ),
          PopupMenuItem(
            value: 'tr',
            child: Text('🇹🇷  Türkçe'),
          ),
          PopupMenuItem(
            value: 'id',
            child: Text('🇮🇩  Bahasa Indonesia'),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 19,
              color: primaryPurple,
            ),
            SizedBox(width: 5),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: primaryPurple,
            ),
          ],
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
          color: selected
              ? primaryPurple
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primaryPurple,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}
