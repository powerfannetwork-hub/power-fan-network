import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_screen.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService.instance;

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _notificationsEnabled = true;
  String _language = 'English';

  static const Color purple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color background = Color(0xFFF8F8FC);
  static const Color green = Color(0xFF159B61);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  String get _name {
    final value = _profile?['name']?.toString().trim() ?? '';

    if (value.isNotEmpty) return value;

    final fullName =
        _profile?['full_name']?.toString().trim() ?? '';

    if (fullName.isNotEmpty) return fullName;

    final username =
        _profile?['username']?.toString().trim() ?? '';

    if (username.isNotEmpty) return username;

    return 'POWER FAN User';
  }

  String get _email {
    final profileEmail =
        _profile?['email']?.toString().trim() ?? '';

    if (profileEmail.isNotEmpty) {
      return profileEmail;
    }

    return _client.auth.currentUser?.email ??
        'No email available';
  }

  double _number(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _integer(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          name: _name,
          email: _email,
          fanBalance: _number(_profile?['fan_balance']),
          afamBalance: _number(_profile?['afam_balance']),
          activeReferrals:
              _integer(_profile?['active_referrals']),
          kyc1Verified:
              _profile?['kyc1_verified'] == true,
          kyc2Eligible:
              _profile?['kyc2_eligible'] == true,
        ),
      ),
    );

    _loadProfile();
  }

  Future<void> _selectLanguage() async {
    const languages = [
      'English',
      'Hindi',
      'Urdu',
      'Chinese',
      'Bahasa Indonesia',
      'Vietnamese',
      'Bengali',
      'Russian',
      'Spanish',
      'Turkish',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              vertical: 10,
            ),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  8,
                ),
                child: Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...languages.map(
                (language) => ListTile(
                  title: Text(language),
                  trailing: language == _language
                      ? const Icon(
                          Icons.check_circle,
                          color: purple,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext)
                        .pop(language);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _language = selected;
    });
  }

  Future<void> _showSecurity() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: purple,
              ),
              SizedBox(width: 10),
              Text('Security'),
            ],
          ),
          content: const Text(
            'Your account is protected by Supabase authentication and database security policies.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAbout() async {
    await showAboutDialog(
      context: context,
      applicationName: 'POWER FAN NETWORK',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Mine FAN. Earn More',
      children: const [
        SizedBox(height: 12),
        Text(
          'POWER FAN NETWORK is a FAN mining and rewards application.',
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    return text.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadProfile,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: purple,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  30,
                ),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Account',
                    children: [
                      _buildSettingTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        subtitle:
                            'View your account information',
                        onTap: _openProfile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Preferences',
                    children: [
                      _buildNotificationTile(),
                      _buildSettingTile(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: _language,
                        onTap: _selectLanguage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Security',
                    children: [
                      _buildSettingTile(
                        icon: Icons.security_rounded,
                        title: 'Security',
                        subtitle:
                            'Account and data protection',
                        onTap: _showSecurity,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'About',
                    children: [
                      _buildSettingTile(
                        icon: Icons.info_outline_rounded,
                        title: 'About POWER FAN',
                        subtitle:
                            'Version 1.0.0',
                        onTap: _showAbout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final fanBalance =
        _number(_profile?['fan_balance']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            deepPurple,
            purple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.14,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${fanBalance.toStringAsFixed(4)} FAN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }

  String _initials() {
    final value = _name.trim();

    if (value.isEmpty) return 'PF';

    final parts = value.split(
      RegExp(r'\s+'),
    );

    if (parts.length == 1) {
      final text = parts.first;

      return text
          .substring(
            0,
            text.length > 2 ? 2 : text.length,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              15,
              16,
              8,
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: deepPurple,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 3,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: purple.withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: purple,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 10.5,
          color: Colors.grey,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildNotificationTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 3,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: purple.withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: purple,
          size: 21,
        ),
      ),
      title: const Text(
        'Notifications',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: const Text(
        'Mining and reward notifications',
        style: TextStyle(
          fontSize: 10.5,
          color: Colors.grey,
        ),
      ),
      trailing: Switch(
        value: _notificationsEnabled,
        activeColor: purple,
        onChanged: (value) {
          setState(() {
            _notificationsEnabled = value;
          });
        },
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(
          Icons.logout_rounded,
        ),
        label: const Text(
          'LOGOUT',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(
            color: Colors.red.shade200,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}
