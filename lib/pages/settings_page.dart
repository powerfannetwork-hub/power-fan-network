// lib/pages/settings_page.dart

import 'package:flutter/material.dart';

import '../globals/app_constants.dart';
import '../globals/app_state.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  final AuthService authService;
  final AppState appState;

  const SettingsPage({
    super.key,
    required this.authService,
    required this.appState,
  });

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsPage> {
  bool _loading = false;

  Future<void> _refreshProfile() async {
    setState(() => _loading = true);

    try {
      final result =
          await widget.authService.getMe();

      if (!mounted) return;

      if (result['success'] == true &&
          result['user'] is Map) {
        widget.appState.updateUser(
          Map<String, dynamic>.from(
            result['user'],
          ),
        );

        _message(
          'Profile refreshed successfully.',
        );
      } else {
        _message(
          '${result['message'] ?? 'Could not refresh profile.'}',
        );
      }
    } catch (_) {
      if (!mounted) return;

      _message(
        'Could not refresh profile.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editName() async {
    final user = widget.appState.user;

    if (user == null) return;

    final controller =
        TextEditingController(
      text: user.name,
    );

    final newName =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Name',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText: 'Name',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                controller.text.trim(),
              ),
              child:
                  const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newName == null ||
        newName.isEmpty ||
        newName == user.name) {
      return;
    }

    setState(() => _loading = true);

    try {
      final result =
          await widget.authService
              .updateProfile(
        name: newName,
      );

      if (!mounted) return;

      if (result['success'] == true &&
          result['user'] is Map) {
        widget.appState.updateUser(
          Map<String, dynamic>.from(
            result['user'],
          ),
        );

        _message(
          'Profile updated successfully.',
        );
      } else {
        _message(
          '${result['message'] ?? 'Could not update profile.'}',
        );
      }
    } catch (_) {
      if (!mounted) return;

      _message(
        'Could not update profile.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final currentController =
        TextEditingController();

    final newController =
        TextEditingController();

    final confirmController =
        TextEditingController();

    final formKey =
        GlobalKey<FormState>();

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller:
                            currentController,
                        obscureText:
                            obscureCurrent,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Current password',
                          border:
                              const OutlineInputBorder(),
                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setDialogState(
                                () {
                                  obscureCurrent =
                                      !obscureCurrent;
                                },
                              );
                            },
                            icon: Icon(
                              obscureCurrent
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Enter current password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextFormField(
                        controller:
                            newController,
                        obscureText:
                            obscureNew,
                        decoration:
                            InputDecoration(
                          labelText:
                              'New password',
                          border:
                              const OutlineInputBorder(),
                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setDialogState(
                                () {
                                  obscureNew =
                                      !obscureNew;
                                },
                              );
                            },
                            icon: Icon(
                              obscureNew
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.length <
                                  6) {
                            return 'Minimum 6 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextFormField(
                        controller:
                            confirmController,
                        obscureText:
                            obscureConfirm,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Confirm password',
                          border:
                              const OutlineInputBorder(),
                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setDialogState(
                                () {
                                  obscureConfirm =
                                      !obscureConfirm;
                                },
                              );
                            },
                            icon: Icon(
                              obscureConfirm
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value !=
                              newController
                                  .text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    context,
                    false,
                  ),
                  child:
                      const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!
                        .validate()) {
                      Navigator.pop(
                        context,
                        true,
                      );
                    }
                  },
                  child:
                      const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );

    final current =
        currentController.text;
    final newPassword =
        newController.text;

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      final result =
          await widget.authService
              .changePassword(
        currentPassword: current,
        newPassword: newPassword,
      );

      if (!mounted) return;

      _message(
        '${result['message'] ?? 'Password update completed.'}',
      );
    } catch (_) {
      if (!mounted) return;

      _message(
        'Could not change password.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
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
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      await widget.authService.logout();
    } catch (_) {
      widget.appState.logout();
    }

    if (!mounted) return;

    setState(() => _loading = false);

    _message(
      'You have been logged out.',
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        widget.appState.user;

    return Scaffold(
      backgroundColor:
          const Color(
        AppConstants.lightBackgroundColorValue,
      ),
      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _loading
                    ? null
                    : _refreshProfile,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              32,
            ),
            children: [
              _profileHeader(user),
              const SizedBox(height: 18),
              _sectionTitle(
                'Account',
              ),
              const SizedBox(height: 8),
              _settingTile(
                icon:
                    Icons.person_outline_rounded,
                title: 'Name',
                subtitle:
                    user?.name.isNotEmpty ==
                            true
                        ? user!.name
                        : 'Not set',
                onTap: _editName,
              ),
              _settingTile(
                icon:
                    Icons.email_outlined,
                title: 'Email',
                subtitle:
                    user?.email.isNotEmpty ==
                            true
                        ? user!.email
                        : 'Not available',
                onTap: null,
              ),
              _settingTile(
                icon:
                    Icons.password_rounded,
                title: 'Change Password',
                subtitle:
                    'Update your account password',
                onTap:
                    _changePassword,
              ),
              const SizedBox(height: 20),
              _sectionTitle(
                'Mining',
              ),
              const SizedBox(height: 8),
              _valueTile(
                icon:
                    Icons.speed_rounded,
                title: 'Mining Rate',
                value:
                    '${widget.appState.miningRate.toStringAsFixed(2)} FAN/h',
              ),
              _valueTile(
                icon:
                    Icons.people_alt_outlined,
                title: 'Active Referrals',
                value:
                    '${widget.appState.activeReferrals}',
              ),
              _valueTile(
                icon:
                    Icons.ondemand_video_rounded,
                title: 'Ads Today',
                value:
                    '${widget.appState.dailyAdsWatched}/${AppConstants.maxDailyAds}',
              ),
              const SizedBox(height: 20),
              _sectionTitle(
                'Security & Verification',
              ),
              const SizedBox(height: 8),
              _verificationTile(
                title: 'KYC 1',
                eligible:
                    user?.kyc1Eligible ??
                        false,
                verified:
                    user?.kyc1Verified ??
                        false,
              ),
              _verificationTile(
                title: 'KYC 2',
                eligible:
                    user?.kyc2Eligible ??
                        false,
                verified:
                    user?.kyc2Verified ??
                        false,
              ),
              _verificationTile(
                title: 'KYC 3',
                eligible: false,
                verified:
                    user?.kyc3Verified ??
                        false,
              ),
              const SizedBox(height: 20),
              _sectionTitle(
                'App',
              ),
              const SizedBox(height: 8),
              _valueTile(
                icon:
                    Icons.language_rounded,
                title: 'Language',
                value: 'English',
              ),
              _valueTile(
                icon:
                    Icons.info_outline_rounded,
                title: 'Version',
                value:
                    AppConstants.appVersion,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                      _loading
                          ? null
                          : _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        Colors.red.shade700,
                    side: BorderSide(
                      color:
                          Colors.red.shade200,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black
                    .withOpacity(0.08),
                child: const Center(
                  child:
                      CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileHeader(
    AppUser? user,
  ) {
    final name =
        user?.name.trim() ?? '';

    final initial =
        name.isEmpty
            ? 'F'
            : name
                .substring(0, 1)
                .toUpperCase();

    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(
              AppConstants.primaryColorValue,
            ),
            Color(
              AppConstants.deepPurpleColorValue,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor:
                Colors.white
                    .withOpacity(0.15),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight:
                    FontWeight.w900,
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
                  name.isEmpty
                      ? 'POWER FAN USER'
                      : name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        left: 4,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 4,
        ),
        leading: _iconBox(icon),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 3,
          ),
          child: Text(
            subtitle,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
        trailing: onTap == null
            ? null
            : const Icon(
                Icons
                    .chevron_right_rounded,
                color: Colors.black38,
              ),
      ),
    );
  }

  Widget _valueTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 15,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(
                AppConstants.primaryColorValue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationTile({
    required String title,
    required bool eligible,
    required bool verified,
  }) {
    String status;

    if (verified) {
      status = 'Verified';
    } else if (eligible) {
      status = 'Eligible';
    } else {
      status = 'Locked';
    }

    final Color iconColor;

    if (verified) {
      iconColor = const Color(
        AppConstants.greenColorValue,
      );
    } else if (eligible) {
      iconColor = const Color(
        AppConstants.primaryColorValue,
      );
    } else {
      iconColor = Colors.black38;
    }

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 15,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(
            verified
                ? Icons.verified_rounded
                : eligible
                    ? Icons
                        .pending_actions_rounded
                    : Icons.lock_outline_rounded,
            color: iconColor,
            size: 25,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(
    IconData icon,
  ) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(
          AppConstants.primaryColorValue,
        ).withOpacity(0.08),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: const Color(
          AppConstants.primaryColorValue,
        ),
        size: 22,
      ),
    );
  }
}
