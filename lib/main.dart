import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';

const Color primaryPurple = Color(0xFF3B159B);
const Color deepPurple = Color(0xFF241064);
const Color lightBackground = Color(0xFFF8F8FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize();

  runApp(const PowerFanNetworkApp());
}

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
          seedColor: primaryPurple,
        ),
        scaffoldBackgroundColor: lightBackground,
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
// FIRESTORE USER PROFILE
// ============================================================

class UserProfileService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<void> createOrUpdateProfile(User user) async {
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(user.uid);

    final existing = await userRef.get();

    final Map<String, dynamic> profile = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      profile.addAll({
        'fanBalance': 0.0,
        'afamBalance': 0.0,
        'miningRate': 0.2,
        'baseMiningRate': 0.2,
        'adBoostRate': 0.0,
        'activeReferralCount': 0,
        'referralCode': user.uid.substring(
          0,
          user.uid.length >= 8 ? 8 : user.uid.length,
        ).toUpperCase(),
        'referredBy': null,
        'referralRewardReceived': false,
        'emailVerified': user.emailVerified,
        'biometricVerified': false,
        'kycStatus': 'COMING_SOON',
        'deviceLinked': false,
        'accountStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await userRef.set(
      profile,
      SetOptions(merge: true),
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
      backgroundColor: lightBackground,
      body: Center(
        child: CircularProgressIndicator(
          color: primaryPurple,
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN
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

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user != null) {
        await UserProfileService.createOrUpdateProfile(user);
      }
    } on FirebaseAuthException catch (e) {
      showMessage(authErrorMessage(e.code));
    } catch (_) {
      showMessage('Login failed. Please try again.');
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> googleLogin() async {
    if (googleLoading) return;

    setState(() {
      googleLoading = true;
    });

    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google ID token is unavailable.');
      }

      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user != null) {
        await UserProfileService.createOrUpdateProfile(user);
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        showMessage(
          'Google Sign-In failed. Please try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(authErrorMessage(e.code));
    } catch (_) {
      showMessage(
        'Google Sign-In failed. Please check your connection.',
      );
    }

    if (mounted) {
      setState(() {
        googleLoading = false;
      });
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      showMessage(
        'Password reset email has been sent.',
        success: true,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(authErrorMessage(e.code));
    } catch (_) {
      showMessage(
        'Unable to send password reset email.',
      );
    }
  }

  String authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'user-not-found':
        return 'No account was found with this email.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Check your internet connection.';

      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';

      default:
        return 'Authentication failed. Please try again.';
    }
  }

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

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
                  const LogoSection(),

                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
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
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Sign in to your POWER FAN account.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 26),

                        const FieldLabel(text: 'Email'),

                        const SizedBox(height: 8),

                        TextField(
                          controller: emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          decoration: inputDecoration(
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const FieldLabel(text: 'Password'),

                        const SizedBox(height: 8),

                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: inputDecoration(
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
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
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                loading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
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

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: googleLoading
                                ? null
                                : googleLogin,
                            icon: googleLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: TextButton(
                            onPressed: forgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: primaryPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        Center(
                          child: TextButton(
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
                              "Don't have an account? Register",
                              style: TextStyle(
                                color: primaryPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
// REGISTER
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword =
        confirmPasswordController.text;

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage('Please fill all fields.');
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password must be at least 6 characters.',
      );
      return;
    }

    if (password != confirmPassword) {
      showMessage('Passwords do not match.');
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
        await UserProfileService.createOrUpdateProfile(user);
      }

      if (mounted) {
        showMessage(
          'Account created successfully.',
          success: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(registerErrorMessage(e.code));
    } catch (_) {
      showMessage(
        'Registration failed. Please try again.',
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  String registerErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';

      case 'email-already-in-use':
        return 'An account already exists with this email.';

      case 'weak-password':
        return 'Please choose a stronger password.';

      case 'network-request-failed':
        return 'Check your internet connection.';

      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase.';

      default:
        return 'Registration failed. Please try again.';
    }
  }

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                  const LogoSection(),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.06),
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
                          'Create Account',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Join POWER FAN NETWORK.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 26),

                        const FieldLabel(text: 'Email'),

                        const SizedBox(height: 8),

                        TextField(
                          controller: emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          decoration: inputDecoration(
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const FieldLabel(text: 'Password'),

                        const SizedBox(height: 8),

                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: inputDecoration(
                            hint: 'Create a password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
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
                          ),
                        ),

                        const SizedBox(height: 18),

                        const FieldLabel(
                          text: 'Confirm Password',
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller:
                              confirmPasswordController,
                          obscureText:
                              obscureConfirmPassword,
                          decoration: inputDecoration(
                            hint: 'Confirm your password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                loading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(15),
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'CREATE ACCOUNT',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            child: const Text(
                              'Already have an account? Login',
                              style: TextStyle(
                                color: primaryPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
// HOME
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'POWER FAN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryPurple,
              ),
            );
          }

          final data = snapshot.data?.data();

          final double fanBalance =
              (data?['fanBalance'] as num?)?.toDouble() ?? 0.0;

          final double afamBalance =
              (data?['afamBalance'] as num?)?.toDouble() ?? 0.0;

          final double miningRate =
              (data?['miningRate'] as num?)?.toDouble() ?? 0.2;

          final int referrals =
              (data?['activeReferralCount'] as num?)?.toInt() ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        primaryPurple,
                        deepPurple,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'POWER FAN NETWORK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        user.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'FAN Balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${fanBalance.toStringAsFixed(4)} FAN',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryPurple,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BalanceItem(
                          title: 'AFAM',
                          value:
                              afamBalance.toStringAsFixed(4),
                        ),
                      ),
                      Expanded(
                        child: _BalanceItem(
                          title: 'Mining Rate',
                          value:
                              '${miningRate.toStringAsFixed(2)} FAN/H',
                        ),
                      ),
                      Expanded(
                        child: _BalanceItem(
                          title: 'Referrals',
                          value: '$referrals',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mining',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Real mining engine will be connected in the next stage.',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: primaryPurple,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Biometric / KYC verification: Coming Soon',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// BALANCE ITEM
// ============================================================

class _BalanceItem extends StatelessWidget {
  final String title;
  final String value;

  const _BalanceItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: deepPurple,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ============================================================
// LOGO
// ============================================================

class LogoSection extends StatelessWidget {
  const LogoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                primaryPurple,
                deepPurple,
              ],
            ),
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: 50,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'POWER FAN',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: deepPurple,
          ),
        ),

        const Text(
          'NETWORK',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: primaryPurple,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// FIELD LABEL
// ============================================================

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ============================================================
// INPUT DECORATION
// ============================================================

InputDecoration inputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(
      icon,
      color: primaryPurple,
    ),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF7F7FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(
        color: primaryPurple,
        width: 1.5,
      ),
    ),
  );
}
