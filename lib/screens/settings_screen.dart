import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';
import '../localization/app_localizations.dart';
import '../localization/language_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService.instance;
  final LanguageController _languageController =
      LanguageController.instance;

  final KycService _kycService = KycService();

  Map<String, dynamic>? _profile;
  KycStatus? _kycStatus;

  bool _loading = true;
  bool _notificationsEnabled = true;

  static const Color purple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color background = Color(0xFFF8F8FC);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _t(String key, [String fallback = '']) {
    final value = AppLocalizations.of(context).translate(key);

    if (value.isEmpty || value == key) {
      return fallback.isEmpty ? key : fallback;
    }

    return value;
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _profile = null;
          _kycStatus = null;
          _loading = false;
        });

        return;
      }

      final results = await Future.wait<dynamic>([
        _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle(),
        _kycService.getStatus(),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _kycStatus = results[1] as KycStatus;
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
    final name = _profile?['name']?.toString().trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    final fullName = _profile?['full_name']?.toString().trim() ?? '';

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final username = _profile?['username']?.toString().trim() ?? '';

    if (username.isNotEmpty) {
      return username;
    }

    return 'POWER FAN User';
  }

  String get _email {
    final email = _profile?['email']?.toString().trim() ?? '';

    if (email.isNotEmpty) {
      return email;
    }

    return _client.auth.currentUser?.email ?? 'No email available';
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

  String get _languageName {
    final code = _languageController.languageCode;

    for (final language in AppLocalizations.languages) {
      if (language.code == code) {
        return language.nativeName;
      }
    }

    return 'English';
  }

  Future<void> _selectLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.language_rounded,
                          color: purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t(
                            'selectLanguage',
                            'Select Language',
                          ),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: AppLocalizations.languages.length,
                    itemBuilder: (context, index) {
                      final language =
                          AppLocalizations.languages[index];

                      final isSelected =
                          _languageController.languageCode ==
                              language.code;

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? purple.withOpacity(0.12)
                                : Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            language.code.toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? purple
                                  : Colors.grey.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          language.nativeName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? purple
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          language.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: purple,
                              )
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext)
                              .pop(language.code);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    if (_languageController.languageCode == selected) {
      return;
    }

    // IMPORTANT: await the language change.
    await _languageController.setLanguage(selected);

    if (!mounted) return;

    setState(() {});

    _showMessage(
      _t(
        'languageChanged',
        'Language changed successfully',
      ),
    );
  }

  Future<void> _openProfile() async {
    final kyc = _kycStatus;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          name: _name,
          email: _email,
          fanBalance: _number(
            _profile?['fan_balance'],
          ),
          afamBalance: _number(
            _profile?['afam_balance'],
          ),
          activeReferrals: _integer(
            _profile?['active_referrals'],
          ),
          checkInDays: kyc?.checkInDays ?? 0,
          boostDays: kyc?.boostDays ?? 0,
          faceVerificationUnlocked:
              kyc?.faceVerificationUnlocked ?? false,
          faceVerified:
              kyc?.faceVerified ?? false,
        ),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _showSecurity() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('security', 'Security'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: deepPurple,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '${_t('security', 'Security')}\n\n'
            '${_t('oneDeviceOneAccount', 'One device = one account')}\n\n'
            '${_t('deviceSecurity', 'Device security')}',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                _t('close', 'Close').toUpperCase(),
                style: const TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAbout() async {
    showAboutDialog(
      context: context,
      applicationName: _t(
        'powerFanNetwork',
        'POWER FAN NETWORK',
      ),
      applicationVersion: '1.0.0',
      applicationLegalese: 'Mine FAN. Earn More',
      children: [
        const SizedBox(height: 12),
        Text(
          _t(
            'powerFanNetwork',
            'POWER FAN NETWORK',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_t('fan', 'FAN')} & ${_t('afam', 'AFAM')}',
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            _t('logout', 'Logout'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: deepPurple,
            ),
          ),
          content: Text(
            _t(
              'logoutConfirm',
              'Are you sure you want to logout?',
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                _t('cancel', 'Cancel').toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _t('logout', 'Logout').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(_cleanError(error));
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
        ? _t(
            'somethingWentWrong',
            'Something went wrong',
          )
        : text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            title: Text(
              _t('settings', 'Settings'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: deepPurple,
              ),
            ),
            centerTitle: true,
            backgroundColor: background,
            foregroundColor: deepPurple,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: _t('refresh', 'Refresh'),
                onPressed: _loading ? null : _loadData,
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
                  color: purple,
                  onRefresh: _loadData,
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
                        title: _t('account', 'Account'),
                        children: [
                          _buildSettingTile(
                            icon:
                                Icons.person_outline_rounded,
                            title: _t('profile', 'Profile'),
                            subtitle:
                                _t('account', 'Account'),
                            onTap: _openProfile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: _t('language', 'Language'),
                        children: [
                          _buildNotificationTile(),
                          _buildSettingTile(
                            icon:
                                Icons.language_rounded,
                            title: _t('language', 'Language'),
                            subtitle: _languageName,
                            onTap: _selectLanguage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: _t('security', 'Security'),
                        children: [
                          _buildSettingTile(
                            icon:
                                Icons.security_rounded,
                            title:
                                _t('security', 'Security'),
                            subtitle: _t(
                              'deviceSecurity',
                              'Device security',
                            ),
                            onTap: _showSecurity,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: _t('about', 'About'),
                        children: [
                          _buildSettingTile(
                            icon:
                                Icons.info_outline_rounded,
                            title: _t(
                              'powerFanNetwork',
                              'POWER FAN NETWORK',
                            ),
                            subtitle: 'Version 1.0.0',
                            onTap: _showAbout,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildLogoutButton(),
                    ],
                  ),
                ),
        );
      },
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
        boxShadow: [
          BoxShadow(
            color: purple.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
              ),
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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${fanBalance.toStringAsFixed(4)} ${_t('fan', 'FAN')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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

    if (value.isEmpty) {
      return 'PF';
    }

    final parts = value.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      final text = parts.first;

      return text.substring(
        0,
        text.length > 2 ? 2 : text.length,
      ).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
          color: purple.withOpacity(0.08),
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
          color: purple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: purple,
          size: 21,
        ),
      ),
      title: Text(
        _t('notifications', 'Notifications'),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _notificationsEnabled
            ? _t('enabled', 'Enabled')
            : _t('disabled', 'Disabled'),
        style: const TextStyle(
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
        label: Text(
          _t('logout', 'Logout').toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
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
