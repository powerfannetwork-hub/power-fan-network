import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';

const String googleWebClientId =
    '983417377998-oaptk186cjkb7pk8pfhma2nbtsindbkf.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ----------------------------------------------------------
  // FIREBASE INITIALIZATION
  // ----------------------------------------------------------

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ----------------------------------------------------------
  // GOOGLE SIGN-IN INITIALIZATION
  //
  // This Web Client ID is the serverClientId required by
  // Google Sign-In on Android.
  // ----------------------------------------------------------

  await GoogleSignIn.instance.initialize(
    serverClientId: googleWebClientId,
  );

  runApp(const PowerFanNetworkApp());
}

// ============================================================
// APP
// ============================================================

class PowerFanNetworkApp extends StatelessWidget {
  const PowerFanNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POWER FAN NETWORK',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B159B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

// ============================================================
// SPLASH
// ============================================================

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F8FC),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3B159B),
        ),
      ),
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
  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool obscurePassword = true;
  bool loading = false;
  bool googleLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ==========================================================
  // EMAIL LOGIN
  // ==========================================================

  Future<void> loginWithEmail() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage(
        'Please enter your email and password.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(firebaseAuthMessage(e));
    } catch (e) {
      showMessage('Login failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // GOOGLE LOGIN
  // ==========================================================

  Future<void> loginWithGoogle() async {
    if (googleLoading) {
      return;
    }

    setState(() {
      googleLoading = true;
    });

    try {
      // IMPORTANT:
      // GoogleSignIn was already initialized in main().
      //
      // Do NOT call initialize() again here.

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'Google did not return an ID token.',
        );
      }

      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        showMessage(
          'Google Sign-In was cancelled.',
        );
      } else {
        showMessage(
          'Google Sign-In error:\n'
          '${e.code}\n'
          '${e.description ?? ''}',
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(
        'Firebase Google Sign-In error:\n'
        '${e.code}\n'
        '${e.message ?? ''}',
      );
    } catch (e) {
      showMessage(
        'Google Sign-In failed:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          googleLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // FORGOT PASSWORD
  // ==========================================================

  Future<void> forgotPassword() async {
    final String email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
        'Enter your email first.',
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      showMessage(
        'Password reset email sent. Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      showMessage(firebaseAuthMessage(e));
    } catch (e) {
      showMessage(
        'Password reset failed: $e',
      );
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // BUILD LOGIN PAGE
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // LOGO
                  // ------------------------------------------------

                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3B159B),
                          Color(0xFF241064),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'POWER FAN',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF241064),
                    ),
                  ),

                  const Text(
                    'NETWORK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                      color: Color(0xFF3B159B),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ------------------------------------------------
                  // LOGIN CARD
                  // ------------------------------------------------

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Sign in to your POWER FAN account.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 28),

                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Color(0xFF3B159B),
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xFFF7F7FA),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                              borderSide:
                                  BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) =>
                              loginWithEmail(),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF3B159B),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword =
                                      !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons
                                        .visibility_outlined
                                    : Icons
                                        .visibility_off_outlined,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xFFF7F7FA),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                              borderSide:
                                  BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ------------------------------------------------
                        // LOGIN BUTTON
                        // ------------------------------------------------

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                loading
                                    ? null
                                    : loginWithEmail,
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF3B159B),
                              foregroundColor:
                                  Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF3B159B),
                              disabledForegroundColor:
                                  Colors.white,
                              elevation: 0,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ------------------------------------------------
                        // GOOGLE BUTTON
                        // ------------------------------------------------

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed:
                                googleLoading
                                    ? null
                                    : loginWithGoogle,
                            icon: googleLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          Color(0xFF3B159B),
                                    ),
                                  )
                                : const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          Color(0xFF3B159B),
                                    ),
                                  ),
                            label: Text(
                              googleLoading
                                  ? 'Signing in...'
                                  : 'Continue with Google',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Color(0xFF5B5180),
                              ),
                            ),
                            style:
                                OutlinedButton.styleFrom(
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ------------------------------------------------
                        // FORGOT PASSWORD
                        // ------------------------------------------------

                        Center(
                          child: TextButton(
                            onPressed: forgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF3B159B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ------------------------------------------------
                        // REGISTER
                        // ------------------------------------------------

                        Center(
                          child: Wrap(
                            alignment:
                                WrapAlignment.center,
                            crossAxisAlignment:
                                WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    color:
                                        Color(0xFF3B159B),
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'POWER FAN NETWORK • AFAM',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
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
}

// ============================================================
// REGISTER PAGE
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  Future<void> register() async {
    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String confirm = confirmController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      showMessage(
        'Please fill all fields.',
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password must contain at least 6 characters.',
      );
      return;
    }

    if (password != confirm) {
      showMessage(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user != null) {
        await user.updateDisplayName(name);

        await user.reload();
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(
        firebaseAuthMessage(e),
      );
    } catch (e) {
      showMessage(
        'Registration failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: const Color(0xFF241064),
        backgroundColor: const Color(0xFFF8F8FC),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F8FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 70,
                color: Color(0xFF3B159B),
              ),

              const SizedBox(height: 20),

              const Text(
                'Create your POWER FAN account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF241064),
                ),
              ),

              const SizedBox(height: 30),

              // NAME
              TextField(
                controller: nameController,
                textCapitalization:
                    TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // EMAIL
              TextField(
                controller: emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // PASSWORD
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword =
                            !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CONFIRM PASSWORD
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                onSubmitted: (_) => register(),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirm =
                            !obscureConfirm;
                      });
                    },
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // CREATE ACCOUNT
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      loading ? null : register,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF3B159B),
                    foregroundColor:
                        Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Already have an account? Login',
                  style: TextStyle(
                    color: Color(0xFF3B159B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'POWER FAN NETWORK',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();

                try {
                  await GoogleSignIn.instance.signOut();
                } catch (_) {
                  // Ignore Google sign-out error.
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        'Logout failed: $e',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3B159B),
                      Color(0xFF241064),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Welcome to POWER FAN NETWORK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF241064),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                user?.displayName ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                user?.email ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.05,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF159B61),
                      size: 45,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Firebase Connected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your account is successfully connected to Firebase.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FIREBASE AUTH ERROR MESSAGES
// ============================================================

String firebaseAuthMessage(
  FirebaseAuthException e,
) {
  switch (e.code) {
    case 'invalid-email':
      return 'The email address is invalid.';

    case 'user-not-found':
      return 'No account was found with this email.';

    case 'wrong-password':
      return 'Incorrect email or password.';

    case 'invalid-credential':
      return 'Incorrect email or password.';

    case 'email-already-in-use':
      return 'This email is already registered.';

    case 'weak-password':
      return 'Password is too weak.';

    case 'network-request-failed':
      return 'Network error. Check your internet connection.';

    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';

    case 'operation-not-allowed':
      return 'This sign-in method is not enabled in Firebase.';

    case 'missing-google-id-token':
      return 'Google did not return an ID token.';

    case 'user-disabled':
      return 'This account has been disabled.';

    case 'account-exists-with-different-credential':
      return 'An account already exists with a different sign-in method.';

    default:
      return 'Authentication error: '
          '${e.code}\n'
          '${e.message ?? ''}';
  }
}
