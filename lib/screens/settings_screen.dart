import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onProfile,
    this.onNotifications,
    this.onLanguage,
    this.onSecurity,
    this.onAbout,
    this.onLogout,
  });

  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final VoidCallback? onLanguage;
  final VoidCallback? onSecurity;
  final VoidCallback? onAbout;
  final VoidCallback? onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _loggingOut = false;

  final List<String> _languages = const [
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

  Color get _purple => const Color(0xFF3B159B);
  Color get _deepPurple => const Color(0xFF241064);
  Color get _background => const Color(0xFFF8F8FC);

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      widget.onLogout?.call();

      if (widget.onLogout == null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to logout. ${error.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  void _showLanguageDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ..._languages.map(
                  (language) {
                    final selected =
                        _selectedLanguage == language;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: selected
                            ? _purple.withValues(alpha: 0.10)
                            : Colors.grey.shade100,
                        child: Icon(
                          Icons.language_rounded,
                          color: selected
                              ? _purple
                              : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(
                        language,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: _purple,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLanguage = language;
                        });

                        Navigator.pop(context);

                        widget.onLanguage?.call();

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              '$language selected.',
                            ),
                            duration:
                                const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotifications() {
    if (widget.onNotifications != null) {
      widget.onNotifications!.call();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Push Notifications',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Receive mining and account notifications.',
                      ),
                      value: _notificationsEnabled,
                      activeColor: _purple,
                      onChanged: (value) {
                        setSheetState(() {
                          _notificationsEnabled = value;
                        });

                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSecurity() {
    if (widget.onSecurity != null) {
      widget.onSecurity!.call();
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security_rounded),
              SizedBox(width: 10),
              Text('Security'),
            ],
          ),
          content: const Text(
            'Your account session is protected. '
            'Keep your login details private and do not share '
            'your account information with anyone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAbout() {
    if (widget.onAbout != null) {
      widget.onAbout!.call();
      return;
    }

    showAboutDialog(
      context: context,
      applicationName: 'POWER FAN NETWORK',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 POWER FAN NETWORK',
      applicationIcon: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: _purple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.bolt_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'POWER FAN NETWORK is a digital mining and '
          'community platform built for the FAN ecosystem.',
        ),
      ],
    );
  }

  void _openProfile() {
    if (widget.onProfile != null) {
      widget.onProfile!.call();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: (iconColor ?? _purple)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: iconColor ?? _purple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        trailing: trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade500,
            ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Account';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF241064),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            30,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _deepPurple,
                    _purple,
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
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'POWER FAN NETWORK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.78,
                            ),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(
                left: 4,
                bottom: 10,
              ),
              child: Text(
                'ACCOUNT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF77727F),
                ),
              ),
            ),

            _settingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle:
                  'View and manage your account profile',
              onTap: _openProfile,
            ),

            _settingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: _notificationsEnabled
                  ? 'Notifications are enabled'
                  : 'Notifications are disabled',
              onTap: _showNotifications,
              trailing: Switch(
                value: _notificationsEnabled,
                activeColor: _purple,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
            ),

            _settingsTile(
              icon: Icons.language_rounded,
              title: 'Language',
              subtitle: _selectedLanguage,
              onTap: _showLanguageDialog,
            ),

            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.only(
                left: 4,
                bottom: 10,
              ),
              child: Text(
                'SECURITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF77727F),
                ),
              ),
            ),

            _settingsTile(
              icon: Icons.shield_outlined,
              title: 'Security',
              subtitle:
                  'Account protection and security information',
              onTap: _showSecurity,
              iconColor: const Color(0xFF159B61),
            ),

            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.only(
                left: 4,
                bottom: 10,
              ),
              child: Text(
                'INFORMATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF77727F),
                ),
              ),
            ),

            _settingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle:
                  'About POWER FAN NETWORK',
              onTap: _showAbout,
            ),

            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(
                      alpha: 0.09,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'Sign out of your account',
                    style: TextStyle(
                      fontSize: 12.5,
                    ),
                  ),
                ),
                trailing: _loggingOut
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.red,
                      ),
                onTap: _loggingOut ? null : _logout,
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                'POWER FAN NETWORK',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 4),

            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
