// lib/pages/login_page.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_localizations.dart';
import '../localization/language_controller.dart';
import '../screens/main_navigation_screen.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _isNavigating = false;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (authState) {
        if (authState.event == AuthChangeEvent.signedIn &&
            mounted &&
            !_isNavigating) {
          _isNavigating = true;
          setState(() => _loading = false);

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MainNavigationScreen(),
            ),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      await AuthService.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final session =
          Supabase.instance.client.auth.currentSession;

      if (session == null) {
        throw Exception(
          AppLocalizations.of(context)
              .translate('authenticationError'),
        );
      }

      _isNavigating = true;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
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
      if (mounted && !_isNavigating) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'powerfan://login-callback',
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLanguageSelector() {
    final controller = context.read<LanguageController>();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final localization =
                  AppLocalizations.of(context);

              final currentCode =
                  controller.languageCode;

              return ListView(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      24,
                      8,
                      24,
                      12,
                    ),
                    child: Text(
                      localization.translate(
                        'selectLanguage',
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF241064),
                      ),
                    ),
                  ),
                  ...AppLocalizations.languages.map(
                    (language) {
                      final selected =
                          currentCode == language.code;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: selected
                              ? const Color(0xFF3B159B)
                              : const Color(0xFFF0EEF8),
                          child: Text(
                            language.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.bold,
                              color: selected
                                  ? Colors.white
                                  : const Color(
                                      0xFF3B159B,
                                    ),
                            ),
                          ),
                        ),
                        title: Text(
                          language.nativeName,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          language.name,
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color:
                                    Color(0xFF3B159B),
                              )
                            : null,
                        onTap: () async {
                          await controller.setLanguage(
                            language.code,
                          );

                          if (!mounted) return;

                          setSheetState(() {});

                          if (Navigator.of(
                            sheetContext,
                          ).canPop()) {
                            Navigator.of(
                              sheetContext,
                            ).pop();
                          }
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openRegisterPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _RegisterPage(),
      ),
    );
  }

  InputDecoration _glassInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.78),
        size: 21,
      ),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.36),
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.075),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 17,
        horizontal: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.58),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.redAccent.withValues(alpha: 0.85),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
    );
  }

  Widget _glowCircle({
    required double size,
    required double opacity,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF7B35FF).withValues(
            alpha: opacity,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B35FF).withValues(
                alpha: opacity * 0.65,
              ),
              blurRadius: size * 0.55,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsets padding =
        const EdgeInsets.all(20),
    double radius = 24,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.075),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.13),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _loading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor:
              Colors.white.withValues(alpha: 0.45),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.17),
          ),
          backgroundColor:
              Colors.white.withValues(alpha: 0.055),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF100625),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D041D),
                    Color(0xFF170832),
                    Color(0xFF25104B),
                    Color(0xFF0A0417),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            left: -70,
            child: _glowCircle(
              size: 230,
              opacity: 0.26,
            ),
          ),
          Positioned(
            top: 250,
            right: -110,
            child: _glowCircle(
              size: 260,
              opacity: 0.18,
            ),
          ),
          Positioned(
            bottom: -130,
            left: 40,
            child: _glowCircle(
              size: 290,
              opacity: 0.15,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                28,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 14,
                            sigmaY: 14,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : _showLanguageSelector,
                            icon: const Icon(
                              Icons.language_rounded,
                              size: 18,
                            ),
                            label: Text(
                              t.translate('language'),
                            ),
                            style:
                                OutlinedButton.styleFrom(
                              foregroundColor:
                                  Colors.white,
                              disabledForegroundColor:
                                  Colors.white38,
                              side: BorderSide(
                                color: Colors.white
                                    .withValues(
                                  alpha: 0.18,
                                ),
                              ),
                              backgroundColor:
                                  Colors.white
                                      .withValues(
                                alpha: 0.07,
                              ),
                              minimumSize:
                                  const Size(0, 44),
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 14,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                              textStyle:
                                  const TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _glassPanel(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 20,
                      ),
                      radius: 25,
                      child: Column(
                        children: [
                          const Text(
                            'POWER FAN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: 1.2,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'NETWORK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: 1.2,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            t.translate('mineFan'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.76,
                              ),
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w500,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      t.translate('welcomeBack'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.translate('loginToContinue'),
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: 0.58),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 21),
                    _glassPanel(
                      padding: const EdgeInsets.all(17),
                      radius: 21,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType:
                                TextInputType.emailAddress,
                            textInputAction:
                                TextInputAction.next,
                            enabled: !_loading,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                            ),
                            decoration:
                                _glassInputDecoration(
                              label:
                                  t.translate('email'),
                              hint:
                                  t.translate('enterEmail'),
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              final email =
                                  value?.trim() ?? '';

                              if (email.isEmpty ||
                                  !email.contains('@') ||
                                  !email.contains('.')) {
                                return t.translate(
                                  'invalidEmail',
                                );
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 13),
                          TextFormField(
                            controller:
                                _passwordController,
                            obscureText:
                                _obscurePassword,
                            textInputAction:
                                TextInputAction.done,
                            enabled: !_loading,
                            onFieldSubmitted: (_) => _login(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                            ),
                            decoration:
                                _glassInputDecoration(
                              label:
                                  t.translate('password'),
                              hint:
                                  t.translate(
                                'enterPassword',
                              ),
                              icon: Icons.lock_outline,
                              suffixIcon:
                                  IconButton(
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
                                      ? Icons
                                          .visibility_outlined
                                      : Icons
                                          .visibility_off_outlined,
                                  color: Colors.white
                                      .withValues(
                                    alpha: 0.72,
                                  ),
                                  size: 21,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return t.translate(
                                  'invalidPassword',
                                );
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 5),
                          Align(
                            alignment:
                                Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : _resetPassword,
                              style:
                                  TextButton.styleFrom(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 2,
                                  vertical: 5,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize
                                        .shrinkWrap,
                              ),
                              child: Text(
                                t.translate(
                                  'forgotPassword',
                                ),
                                style:
                                    const TextStyle(
                                  color:
                                      Color(0xFFB99AFF),
                                  fontSize: 13.5,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient:
                              const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFF6B24D6),
                              Color(0xFF9B55FF),
                              Color(0xFF6B24D6),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF8D42FF,
                              ).withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 22,
                              offset:
                                  const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed:
                              _loading ? null : _login,
                          style:
                              FilledButton.styleFrom(
                            backgroundColor:
                                Colors.transparent,
                            disabledBackgroundColor:
                                Colors.transparent,
                            foregroundColor:
                                Colors.white,
                            disabledForegroundColor:
                                Colors.white54,
                            shadowColor:
                                Colors.transparent,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  t.translate('signIn'),
                                  style:
                                      const TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white
                                .withValues(
                              alpha: 0.13,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 13,
                          ),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(
                                alpha: 0.48,
                              ),
                              fontSize: 12.5,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white
                                .withValues(
                              alpha: 0.13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    _googleButton(),
                    const SizedBox(height: 19),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          t.translate(
                            'dontHaveAccount',
                          ),
                          style: TextStyle(
                            color: Colors.white
                                .withValues(
                              alpha: 0.55,
                            ),
                            fontSize: 13.5,
                          ),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : _openRegisterPage,
                          style:
                              TextButton.styleFrom(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize
                                    .shrinkWrap,
                          ),
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              color: Color(0xFFB99AFF),
                              fontSize: 13.5,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      'POWER FAN NETWORK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: 0.30),
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    final email =
        _emailController.text.trim();

    if (email.isEmpty ||
        !email.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate(
              'invalidEmail',
            ),
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await AuthService.instance
          .resetPassword(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate(
              'operationSuccessful',
            ),
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// REGISTER PAGE
// -----------------------------------------------------------------------------

class _RegisterPage extends StatefulWidget {
  const _RegisterPage();

  @override
  State<_RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<_RegisterPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _usernameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  final _referralController =
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

  void _showRegisterLanguageSelector() {
    final controller =
        context.read<LanguageController>();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final localization =
                  AppLocalizations.of(context);

              final currentCode =
                  controller.languageCode;

              return ListView(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.only(
                  bottom: 16,
                ),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      24,
                      8,
                      24,
                      12,
                    ),
                    child: Text(
                      localization.translate(
                        'selectLanguage',
                      ),
                      style:
                          const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF241064),
                      ),
                    ),
                  ),
                  ...AppLocalizations.languages
                      .map(
                    (language) {
                      final selected =
                          currentCode ==
                              language.code;

                      return ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              selected
                                  ? const Color(
                                      0xFF3B159B,
                                    )
                                  : const Color(
                                      0xFFF0EEF8,
                                    ),
                          child: Text(
                            language.code
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color: selected
                                  ? Colors.white
                                  : const Color(
                                      0xFF3B159B,
                                    ),
                            ),
                          ),
                        ),
                        title: Text(
                          language.nativeName,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        subtitle: Text(
                          language.name,
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons
                                    .check_circle,
                                color: Color(
                                  0xFF3B159B,
                                ),
                              )
                            : null,
                        onTap: () async {
                          await controller
                              .setLanguage(
                            language.code,
                          );

                          if (!mounted) return;

                          setSheetState(() {});

                          if (Navigator.of(
                            sheetContext,
                          ).canPop()) {
                            Navigator.of(
                              sheetContext,
                            ).pop();
                          }
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _showRegistrationWarning() async {
    bool accepted = false;

    final result =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final t =
                AppLocalizations.of(context);

            return AlertDialog(
              backgroundColor:
                  Colors.white,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              titlePadding:
                  const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                8,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                24,
                8,
                24,
                8,
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                18,
              ),
              title: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFFFF1F1,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color:
                          Colors.redAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Text(
                    t.translate(
                      'oneDeviceRuleMessage',
                    ),
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF241064),
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
              content:
                  SizedBox(
                width:
                    double.maxFinite,
                child:
                    SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        t.translate(
                          'kycRequirements',
                        ),
                        style:
                            const TextStyle(
                          color:
                              Color(0xFF333333),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      _warningItem(
                        icon: Icons
                            .person_outline_rounded,
                        title: t.translate(
                          'account',
                        ),
                        text: t.translate(
                          'oneDeviceRuleMessage',
                        ),
                      ),
                      _warningItem(
                        icon: Icons
                            .smart_toy_outlined,
                        title: t.translate(
                          'robotWarning',
                        ),
                        text: t.translate(
                          'robotWarning',
                        ),
                      ),
                      _warningItem(
                        icon: Icons
                            .group_off_outlined,
                        title: t.translate(
                          'security',
                        ),
                        text: t.translate(
                          'oneDeviceRuleMessage',
                        ),
                      ),
                      _warningItem(
                        icon: Icons
                            .warning_amber_rounded,
                        title: t.translate(
                          'warning',
                        ),
                        text: t.translate(
                          'somethingWentWrong',
                        ),
                      ),
                      _warningItem(
                        icon: Icons
                            .verified_user_outlined,
                        title: t.translate(
                          'privacy',
                        ),
                        text: t.translate(
                          'privacyPolicy',
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Container(
                        padding:
                            const EdgeInsets
                                .all(14),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF5F2FF,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFE3DDF7,
                            ),
                          ),
                        ),
                        child: Text(
                          t.translate(
                            'oneDeviceRuleMessage',
                          ),
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF3B159B,
                            ),
                            fontSize: 13.5,
                            fontWeight:
                                FontWeight
                                    .w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      InkWell(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        onTap: () {
                          setDialogState(
                            () {
                              accepted =
                                  !accepted;
                            },
                          );
                        },
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 6,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Checkbox(
                                value:
                                    accepted,
                                activeColor:
                                    const Color(
                                  0xFF3B159B,
                                ),
                                onChanged:
                                    (value) {
                                  setDialogState(
                                    () {
                                      accepted =
                                          value ??
                                              false;
                                    },
                                  );
                                },
                              ),
                              Expanded(
                                child:
                                    Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    top: 12,
                                    right: 4,
                                  ),
                                  child: Text(
                                    t.translate(
                                      'oneDeviceRuleMessage',
                                    ),
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(
                                        0xFF333333,
                                      ),
                                      fontSize:
                                          13.5,
                                      height:
                                          1.4,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      dialogContext,
                    ).pop(false);
                  },
                  child: Text(
                    t.translate(
                      'cancel',
                    ),
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: accepted
                      ? () {
                          Navigator.of(
                            dialogContext,
                          ).pop(true);
                        }
                      : null,
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF3B159B,
                    ),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        const Color(
                      0xFFE0DCEB,
                    ),
                    disabledForegroundColor:
                        Colors.grey,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: Text(
                    t.translate(
                      'continue',
                    ),
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  Widget _warningItem({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 15,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF1EEFA),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF3B159B),
              size: 21,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Color(0xFF241064),
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  text,
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final accepted =
        await _showRegistrationWarning();

    if (!accepted || !mounted) {
      return;
    }

    setState(
      () => _loading = true,
    );

    try {
      await AuthService.instance.register(
        username:
            _usernameController.text
                .trim(),
        email:
            _emailController.text
                .trim(),
        password:
            _passwordController.text,
        referralCode:
            _referralController.text
                    .trim()
                    .isEmpty
                ? null
                : _referralController
                    .text
                    .trim(),
      );

      if (!mounted) return;

      final session =
          Supabase.instance.client
              .auth
              .currentSession;

      if (session == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                  .translate(
                'operationSuccessful',
              ),
            ),
            behavior:
                SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pop();
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      String message =
          e.toString();

      if (message.startsWith(
        'Exception: ',
      )) {
        message =
            message.substring(11);
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(
          () => _loading = false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t =
        AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF8F8FC),
        elevation: 0,
        foregroundColor:
            const Color(0xFF241064),
        title: Text(
          t.translate('register'),
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t.translate(
              'language',
            ),
            onPressed: _loading
                ? null
                : _showRegisterLanguageSelector,
            icon: const Icon(
              Icons.language,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            10,
            24,
            30,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment:
                      Alignment.center,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF3B159B,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      22,
                    ),
                  ),
                  child:
                      const Text(
                    'PF',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Text(
                  t.translate(
                    'createAccount',
                  ),
                  style:
                      const TextStyle(
                    color:
                        Color(0xFF241064),
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 7,
                ),
                Text(
                  t.translate(
                    'joinPowerFanNetwork',
                  ),
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(
                  height: 28,
                ),
                TextFormField(
                  controller:
                      _usernameController,
                  enabled: !_loading,
                  textInputAction:
                      TextInputAction
                          .next,
                  decoration:
                      InputDecoration(
                    labelText:
                        t.translate(
                      'username',
                    ),
                    hintText:
                        t.translate(
                      'enterUsername',
                    ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .person_outline,
                    ),
                  ),
                  validator:
                      (value) {
                    final username =
                        value?.trim() ??
                            '';

                    if (username
                            .length <
                        3) {
                      return t
                          .translate(
                        'invalidUsername',
                      );
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
                  enabled: !_loading,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  textInputAction:
                      TextInputAction
                          .next,
                  decoration:
                      InputDecoration(
                    labelText:
                        t.translate(
                      'email',
                    ),
                    hintText:
                        t.translate(
                      'enterEmail',
                    ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .email_outlined,
                    ),
                  ),
                  validator:
                      (value) {
                    final email =
                        value?.trim() ??
                            '';

                    if (email
                            .isEmpty ||
                        !email
                            .contains(
                          '@',
                        ) ||
                        !email
                            .contains(
                          '.',
                        )) {
                      return t
                          .translate(
                        'invalidEmail',
                      );
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
                  enabled: !_loading,
                  obscureText:
                      _obscurePassword,
                  textInputAction:
                      TextInputAction
                          .next,
                  decoration:
                      InputDecoration(
                    labelText:
                        t.translate(
                      'password',
                    ),
                    hintText:
                        t.translate(
                      'enterPassword',
                    ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .lock_outline,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(
                          () {
                            _obscurePassword =
                                !_obscurePassword;
                          },
                        );
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator:
                      (value) {
                    if ((value ??
                                '')
                            .length <
                        6) {
                      return t
                          .translate(
                        'invalidPassword',
                      );
                    }

                    return null;
                  },
                ),
                const SizedBox(
                  height: 16,
                ),
                TextFormField(
                  controller:
                      _confirmPasswordController,
                  enabled: !_loading,
                  obscureText:
                      _obscureConfirmPassword,
                  textInputAction:
                      TextInputAction
                          .next,
                  decoration:
                      InputDecoration(
                    labelText:
                        t.translate(
                      'confirmPassword',
                    ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .lock_reset_outlined,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(
                          () {
                            _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                          },
                        );
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator:
                      (value) {
                    if (value !=
                        _passwordController
                            .text) {
                      return t
                          .translate(
                        'passwordsDoNotMatch',
                      );
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
                  enabled: !_loading,
                  textInputAction:
                      TextInputAction
                          .done,
                  decoration:
                      InputDecoration(
                    labelText:
                        t.translate(
                      'referralCodeOptional',
                    ),
                    hintText:
                        t.translate(
                      'enterReferralCode',
                    ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .people_outline,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 26,
                ),
                SizedBox(
                  height: 54,
                  child:
                      FilledButton(
                    onPressed:
                        _loading
                            ? null
                            : _register,
                    style:
                        FilledButton
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
                          15,
                        ),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            t.translate(
                              'signUp',
                            ),
                            style:
                                const TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(
                  height: 18,
                ),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Text(
                      t.translate(
                        'alreadyHaveAccount',
                      ),
                      style:
                          TextStyle(
                        color: Colors
                            .grey
                            .shade700,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _loading
                              ? null
                              : () {
                                  Navigator
                                      .of(
                                    context,
                                  ).pop();
                                },
                      child:
                          Text(
                        t.translate(
                          'signIn',
                        ),
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF3B159B,
                          ),
                          fontWeight:
                              FontWeight
                                  .bold,
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
