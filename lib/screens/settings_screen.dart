import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/kyc_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final KycService _kycService = KycService();

  Map<String, dynamic>? _profile;
  KycStatus? _kycStatus;
  bool _loading = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _profile = null;
          _kycStatus = null;
          _loading = false;
        });

        return;
      }

      final profileFuture = _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final kycFuture = _kycService.getProgress();

      final Map<String, dynamic>? profile = await profileFuture;
      final KycStatus kycStatus = await kycFuture;

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _kycStatus = kycStatus;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  String _profileValue(String key) {
    final value = _profile?[key];
    return value?.toString().trim() ?? '';
  }

  String get _profileImageUrl {
    const keys = [
      'profile_image_url',
      'profile_image',
      'avatar_url',
      'avatar',
      'profileImageUrl',
      'image_url',
      'imageUrl',
    ];

    for (final key in keys) {
      final value = _profileValue(key);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String get _name {
    final name = _profileValue('name');

    if (name.isNotEmpty) {
      return name;
    }

    final username = _profileValue('username');

    if (username.isNotEmpty) {
      return username;
    }

    final user = _supabase.auth.currentUser;

    return user?.userMetadata?['name']?.toString() ?? 'User';
  }

  String get _email {
    return _supabase.auth.currentUser?.email ?? '';
  }

  double _doubleValue(String key) {
    final value = _profile?[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _intValue(String key) {
    final value = _profile?[key];

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _activeReferrals {
    return _intValue('active_referrals');
  }

  Future<void> _openProfile() async {
    final status = _kycStatus;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          name: _name,
          email: _email,
          profileImageUrl: _profileImageUrl,
          fanBalance: _doubleValue('fan_balance'),
          afamBalance: _doubleValue('afam_balance'),
          activeReferrals: _activeReferrals,
          checkInDays: status?.checkInDays ?? 0,
          boostDays: status?.boostDays ?? 0,
          faceVerificationUnlocked:
              status?.faceVerificationUnlocked ?? false,
          faceVerified: status?.faceVerified ?? false,
        ),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await AuthService.instance.logout();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to sign out. Please try again.'),
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

  String _initials() {
    final name = _name.trim();

    if (name.isEmpty) {
      return 'U';
    }

    final parts = name.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length >= 2 ? 2 : 1,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildProfileCard() {
    final imageUrl = _profileImageUrl;

    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3B159B),
              Color(0xFF241064),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Center(
                          child: Text(
                            _initials(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        _initials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'View Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? const Color(0xFF3B159B);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
      trailing: onTap == null
          ? null
          : const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F8FC),
        foregroundColor: const Color(0xFF241064),
        title: Text(
          l10n.settings,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3B159B),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF3B159B),
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 22),
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF241064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'View your profile and KYC progress',
                    onTap: _openProfile,
                  ),
                  _buildSettingTile(
                    icon: Icons.security_outlined,
                    title: 'KYC Verification',
                    subtitle: 'Manage your verification status',
                    onTap: _openProfile,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'App',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF241064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingTile(
                    icon: Icons.notifications_none,
                    title: 'Notifications',
                    subtitle: 'Manage app notifications',
                  ),
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'Power Fan Network',
                  ),
                  const SizedBox(height: 18),
                  _buildSettingTile(
                    icon: Icons.logout,
                    title: 'Sign Out',
                    iconColor: Colors.red,
                    onTap: _loggingOut ? null : _logout,
                  ),
                ],
              ),
            ),
    );
  }
}
