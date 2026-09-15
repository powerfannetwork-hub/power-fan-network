import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _loggingOut = false;

  bool _notificationsEnabled = false;
  bool _notificationLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationStatus();
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
          _loading = false;
        });

        return;
      }

      final profile = await _supabase
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

  Future<void> _loadNotificationStatus() async {
    try {
      final enabled =
          await NotificationService.instance.areNotificationsEnabled();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = enabled;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  Future<void> _enableNotifications() async {
    if (_notificationLoading) return;

    setState(() {
      _notificationLoading = true;
    });

    try {
      final granted =
          await NotificationService.instance.requestPermission();

      final enabled =
          await NotificationService.instance.areNotificationsEnabled();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = enabled || granted;
      });

      if (!enabled && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are currently disabled. '
              'Please allow notifications for POWER FAN NETWORK.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _notificationLoading = false;
        });
      }
    }
  }

  Future<void> _refreshNotificationStatus() async {
    if (_notificationLoading) return;

    setState(() {
      _notificationLoading = true;
    });

    try {
      final enabled =
          await NotificationService.instance.areNotificationsEnabled();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = enabled;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _notificationLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await AuthService.instance.logout();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
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

    return Container(
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
              ],
            ),
          ),
        ],
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

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleEnable() async {
              if (_notificationLoading) return;

              setSheetState(() {
                _notificationLoading = true;
              });

              try {
                await NotificationService.instance.requestPermission();

                final enabled = await NotificationService.instance
                    .areNotificationsEnabled();

                if (!mounted) return;

                setState(() {
                  _notificationsEnabled = enabled;
                });

                setSheetState(() {
                  _notificationLoading = false;
                });

                if (!enabled) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notifications are currently disabled. '
                        'Please allow notifications for POWER FAN NETWORK.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;

                setSheetState(() {
                  _notificationLoading = false;
                });

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            }

            Future<void> handleRefresh() async {
              if (_notificationLoading) return;

              setSheetState(() {
                _notificationLoading = true;
              });

              try {
                final enabled = await NotificationService.instance
                    .areNotificationsEnabled();

                if (!mounted) return;

                setState(() {
                  _notificationsEnabled = enabled;
                });

                setSheetState(() {
                  _notificationLoading = false;
                });
              } catch (_) {
                if (!mounted) return;

                setSheetState(() {
                  _notificationLoading = false;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B159B)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_none,
                            color: Color(0xFF3B159B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF241064),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Manage app notifications',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mining reminders, reward updates, social tasks, '
                      'and other important Power Fan Network notifications '
                      'will appear here.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _notificationsEnabled
                              ? const Color(0xFF3B159B)
                                  .withValues(alpha: 0.15)
                              : const Color(0xFFE5E5EC),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _notificationsEnabled
                                  ? const Color(0xFF3B159B)
                                      .withValues(alpha: 0.10)
                                  : Colors.grey.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _notificationsEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off_outlined,
                              color: _notificationsEnabled
                                  ? const Color(0xFF3B159B)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _notificationsEnabled
                                      ? 'Notifications enabled'
                                      : 'Notifications disabled',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF241064),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _notificationsEnabled
                                      ? 'POWER FAN NETWORK can send important app notifications.'
                                      : 'Allow notifications to receive important app updates.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _notificationLoading ? null : handleEnable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B159B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _notificationLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _notificationsEnabled
                                    ? Icons.refresh
                                    : Icons.notifications_active_outlined,
                              ),
                        label: Text(
                          _notificationsEnabled
                              ? 'Refresh Notification Status'
                              : 'Enable Notifications',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _notificationLoading ? null : handleRefresh,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B159B),
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          side: BorderSide(
                            color: const Color(0xFF3B159B)
                                .withValues(alpha: 0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.sync,
                          size: 20,
                        ),
                        label: const Text(
                          'Check Current Status',
                        ),
                      ),
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

  void _openSecurity() {
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B159B)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.security_outlined,
                        color: Color(0xFF3B159B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Security',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF241064),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account Security',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'POWER FAN NETWORK is designed to protect the '
                  'integrity of the network and its users.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSecurityPoint(
                  icon: Icons.person_outline,
                  title: 'One person = one account',
                  text:
                      'Each user should maintain only one genuine account.',
                ),
                _buildSecurityPoint(
                  icon: Icons.smart_toy_outlined,
                  title: 'No bots or automation',
                  text:
                      'Bots, automated activity, fake activity, or attempts '
                      'to abuse the system are not allowed.',
                ),
                _buildSecurityPoint(
                  icon: Icons.shield_outlined,
                  title: 'Reward protection',
                  text:
                      'Accounts involved in suspicious or abusive activity '
                      'may lose access to rewards and network features.',
                ),
                _buildSecurityPoint(
                  icon: Icons.verified_user_outlined,
                  title: 'Use the network fairly',
                  text:
                      'Please keep your account secure and use '
                      'POWER FAN NETWORK fairly and genuinely.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityPoint({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3B159B)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 21,
              color: const Color(0xFF3B159B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAbout() {
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3B159B),
                            Color(0xFF241064),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'About Power Fan Network',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF241064),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'POWER FAN NETWORK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B159B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'mine FAN. earn more.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF777777),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'About',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'POWER FAN NETWORK is built around consistency, '
                  'patience, participation, and community.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stay active, participate in daily activities, '
                  'complete available tasks, build genuine connections, '
                  'and keep moving forward with the network.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mining is only one part of the journey. '
                  'Your consistency and genuine participation help '
                  'you make the most of the Power Fan Network experience.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B159B),
                        Color(0xFF241064),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'STAY ACTIVE.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'STAY GENUINE.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'STAY CONSISTENT.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F8FC),
        foregroundColor: const Color(0xFF241064),
        title: const Text(
          'Settings',
          style: TextStyle(
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
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  30,
                ),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 22),
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
                    subtitle: _notificationsEnabled
                        ? 'Notifications are enabled'
                        : 'Notifications are disabled',
                    onTap: _openNotifications,
                  ),
                  _buildSettingTile(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    subtitle:
                        'Protect your account and network activity',
                    onTap: _openSecurity,
                  ),
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'About Power Fan Network',
                    subtitle:
                        'Learn more about Power Fan Network',
                    onTap: _openAbout,
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
