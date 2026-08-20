import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color primaryPurple = Color(0xFF35129B);

  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkModeEnabled = false;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;
      _vibrationEnabled =
          prefs.getBool('vibration_enabled') ?? true;
      _darkModeEnabled =
          prefs.getBool('dark_mode_enabled') ?? false;
      _language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Language',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                title: const Text('English'),
                trailing: _language == 'English'
                    ? const Icon(
                        Icons.check,
                        color: primaryPurple,
                      )
                    : null,
                onTap: () async {
                  setState(() => _language = 'English');
                  await _saveLanguage('English');

                  if (mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Hausa'),
                trailing: _language == 'Hausa'
                    ? const Icon(
                        Icons.check,
                        color: primaryPurple,
                      )
                    : null,
                onTap: () async {
                  setState(() => _language = 'Hausa');
                  await _saveLanguage('Hausa');

                  if (mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Power Fan Network',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Power Fan Network',
      children: const [
        SizedBox(height: 12),
        Text(
          'Power Fan Network mobile application.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryPurple,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          _sectionTitle('Preferences'),

          _settingCard(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Receive important app notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              activeColor: primaryPurple,
              onChanged: (value) async {
                setState(() {
                  _notificationsEnabled = value;
                });

                await _saveBool(
                  'notifications_enabled',
                  value,
                );
              },
            ),
          ),

          _settingCard(
            icon: Icons.vibration,
            title: 'Vibration',
            subtitle: 'Use vibration for supported actions',
            trailing: Switch(
              value: _vibrationEnabled,
              activeColor: primaryPurple,
              onChanged: (value) async {
                setState(() {
                  _vibrationEnabled = value;
                });

                await _saveBool(
                  'vibration_enabled',
                  value,
                );
              },
            ),
          ),

          _settingCard(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Use a dark appearance',
            trailing: Switch(
              value: _darkModeEnabled,
              activeColor: primaryPurple,
              onChanged: (value) async {
                setState(() {
                  _darkModeEnabled = value;
                });

                await _saveBool(
                  'dark_mode_enabled',
                  value,
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          _sectionTitle('Language'),

          _settingCard(
            icon: Icons.language,
            title: 'Language',
            subtitle: _language,
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: _showLanguageSelector,
          ),

          const SizedBox(height: 20),

          _sectionTitle('Information'),

          _settingCard(
            icon: Icons.info_outline,
            title: 'About Power Fan Network',
            subtitle: 'App information and version',
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
            onTap: _showAbout,
          ),

          const SizedBox(height: 24),

          const Center(
            child: Text(
              'Power Fan Network',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: primaryPurple,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _settingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primaryPurple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: primaryPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
