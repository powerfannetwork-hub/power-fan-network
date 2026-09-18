// lib/pages/login_page.dart

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

  @override
  void dispose() {
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
      if (mounted) {
        setState(() => _loading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : _showLanguageSelector,
                    icon: const Icon(
                      Icons.language,
                      size: 19,
                    ),
                    label: Text(
                      t.translate('language'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          const Color(0xFF3B159B),
                      side: const BorderSide(
                        color: Color(0xFF3B159B),
                      ),
                      minimumSize:
                          const Size(0, 46),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      textStyle:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
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
                  child: Column(
                    children: [
                      const Text(
                        'POWER FAN',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: 1.1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'NETWORK',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: 1.1,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.translate('mineFan'),
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              Colors.white.withValues(
                            alpha: 0.92,
                          ),
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  t.translate('welcomeBack'),
                  style: const TextStyle(
                    color: Color(0xFF241064),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  t.translate('loginToContinue'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.next,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText:
                        t.translate('email'),
                    hintText:
                        t.translate('enterEmail'),
                    prefixIcon:
                        const Icon(
                      Icons.email_outlined,
                      size: 21,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 14,
                    ),
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
                  decoration: InputDecoration(
                    labelText:
                        t.translate('password'),
                    hintText:
                        t.translate(
                      'enterPassword',
                    ),
                    prefixIcon:
                        const Icon(
                      Icons.lock_outline,
                      size: 21,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
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
                      return t.translate(
                        'invalidPassword',
                      );
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        _loading
                            ? null
                            : _resetPassword,
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
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
                            Color(0xFF3B159B),
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed:
                        _loading ? null : _login,
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF3B159B),
                      foregroundColor:
                          Colors.white,
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
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            t.translate(
                              'signIn',
                            ),
                            style:
                                const TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      t.translate(
                        'dontHaveAccount',
                      ),
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 14,
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
                      child: Text(
                        t.translate(
                          'register',
                        ),
                        style:
                            const TextStyle(
                          color:
                              Color(0xFF3B159B),
                          fontSize: 14,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'POWER FAN NETWORK',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
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
          behavior:
              SnackBarBehavior.floating,
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
