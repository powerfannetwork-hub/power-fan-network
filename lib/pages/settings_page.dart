import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../globals/app_state.dart';
import '../services/kyc_service.dart';

class SettingsPage extends StatefulWidget {
  final AuthService authService;
  final AppState appState;

  const SettingsPage({
    super.key,
    required this.authService,
    required this.appState,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final KycService _kyc = KycService();

  KycStatus _kycStatus = KycStatus.initial();

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    try {
      final status = await _kyc.getProgress();

      if (!mounted) return;

      setState(() {
        _kycStatus = status;
      });
    } catch (_) {
      // Keep the existing Settings page working even if
      // KYC status cannot be loaded temporarily.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.user;

    final rawUsername = user?['name']?.toString().trim();
    final username =
        rawUsername != null && rawUsername.isNotEmpty ? rawUsername : 'Miner';

    final email = user?['email']?.toString() ?? '';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color(0xFF241064),
            ),
          ),
          const SizedBox(height: 20),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if (_kycStatus.isVerified) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22A660),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(email),
          ),

          const Divider(),

          ListTile(
            title: const Text('Logout'),
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            onTap: () async {
              await widget.authService.logout();
              await widget.appState.logout();
            },
          ),
        ],
      ),
    );
  }
}
