import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const Color primaryPurple = Color(0xFF35129B);

  bool _isRegister = true;
  bool _isPhoneMode = true;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _continueWithPhone() {
    if (_phoneController.text.trim().isEmpty) {
      _showMessage('Enter your phone number.');
      return;
    }

    _showMessage(
      'Phone OTP will be verified through Firebase Authentication.',
    );
  }

  void _continueWithGoogle() {
    _showMessage(
      'Google Sign-In will be connected to Firebase Authentication.',
    );
  }

  void _continueWithFacebook() {
    _showMessage(
      'Facebook Login will be connected to Firebase Authentication.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Brand
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: primaryPurple,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'POWER FAN NETWORK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryPurple,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isRegister
                    ? 'Create your account'
                    : 'Welcome back',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 30),

              // Register / Login selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _modeButton(
                        title: 'Register',
                        selected: _isRegister,
                        onTap: () {
                          setState(() {
                            _isRegister = true;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _modeButton(
                        title: 'Login',
                        selected: !_isRegister,
                        onTap: () {
                          setState(() {
                            _isRegister = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Phone / Email selector
              Row(
                children: [
                  Expanded(
                    child: _methodButton(
                      icon: Icons.phone_rounded,
                      title: 'Phone',
                      selected: _isPhoneMode,
                      onTap: () {
                        setState(() {
                          _isPhoneMode = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _methodButton(
                      icon: Icons.email_rounded,
                      title: 'Email',
                      selected: !_isPhoneMode,
                      onTap: () {
                        setState(() {
                          _isPhoneMode = false;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              if (_isPhoneMode)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+234...',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                )
              else
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.email_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isPhoneMode
                      ? _continueWithPhone
                      : () {
                          if (_emailController.text.trim().isEmpty) {
                            _showMessage(
                              'Enter your email address.',
                            );
                            return;
                          }

                          _showMessage(
                            'Email authentication will be connected to Firebase.',
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isPhoneMode
                        ? 'CONTINUE WITH PHONE'
                        : 'CONTINUE WITH EMAIL',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Google
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _continueWithGoogle,
                  icon: const Icon(
                    Icons.g_mobiledata_rounded,
                    size: 30,
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.grey.shade200,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Facebook
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _continueWithFacebook,
                  icon: const Icon(
                    Icons.facebook_rounded,
                  ),
                  label: const Text(
                    'Continue with Facebook',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.grey.shade200,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'By continuing, you agree to the Power Fan Network '
                'Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _methodButton({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? primaryPurple.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primaryPurple
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? primaryPurple : Colors.grey,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: selected ? primaryPurple : Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
