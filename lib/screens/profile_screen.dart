import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? name;
  final String? email;
  final String? profileImageUrl;
  final double fanBalance;
  final double afamBalance;
  final int activeReferrals;

  final int checkInDays;
  final int boostDays;
  final bool faceVerificationUnlocked;
  final bool faceVerified;

  const ProfileScreen({
    super.key,
    this.name,
    this.email,
    this.profileImageUrl,
    this.fanBalance = 0.0,
    this.afamBalance = 0.0,
    this.activeReferrals = 0,
    this.checkInDays = 0,
    this.boostDays = 0,
    this.faceVerificationUnlocked = false,
    this.faceVerified = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color successGreen = Color(0xFF159B61);

  late int _checkInDays;
  late int _boostDays;
  late bool _faceVerificationUnlocked;
  late bool _faceVerified;

  bool _checkedInToday = false;
  bool _boostedToday = false;
  bool _loadingKyc = false;

  @override
  void initState() {
    super.initState();

    _checkInDays = _clampDays(widget.checkInDays);
    _boostDays = _clampDays(widget.boostDays);
    _faceVerificationUnlocked =
        widget.faceVerificationUnlocked;
    _faceVerified = widget.faceVerified;

    _loadKycProgress();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.checkInDays != widget.checkInDays ||
        oldWidget.boostDays != widget.boostDays ||
        oldWidget.faceVerificationUnlocked !=
            widget.faceVerificationUnlocked ||
        oldWidget.faceVerified != widget.faceVerified) {
      setState(() {
        _checkInDays = _clampDays(widget.checkInDays);
        _boostDays = _clampDays(widget.boostDays);
        _faceVerificationUnlocked =
            widget.faceVerificationUnlocked;
        _faceVerified = widget.faceVerified;
      });

      _loadKycProgress();
    }
  }

  int _clampDays(int value) {
    if (value < 0) return 0;
    if (value > 30) return 30;
    return value;
  }

  Future<void> _loadKycProgress() async {
    if (_loadingKyc) return;

    setState(() {
      _loadingKyc = true;
    });

    try {
      final response = await SupabaseService.client.rpc(
        'get_kyc_progress',
      );

      if (!mounted) return;

      if (response is Map) {
        final map = Map<String, dynamic>.from(response);

        final checkInValue =
            map['kyc_checkin_days'] ??
            map['checkin_days'] ??
            0;

        final boostValue =
            map['kyc_boost_days'] ??
            map['boost_days'] ??
            0;

        final checkedTodayValue =
            map['checked_in_today'] ??
            map['checkedInToday'] ??
            false;

        final boostedTodayValue =
            map['boosted_today'] ??
            map['boostedToday'] ??
            false;

        final unlockedValue =
            map['face_verification_unlocked'] ??
            false;

        final verifiedValue =
            map['face_verified'] ??
            false;

        setState(() {
          _checkInDays = _clampDays(
            _toInt(checkInValue),
          );

          _boostDays = _clampDays(
            _toInt(boostValue),
          );

          _checkedInToday = _toBool(
            checkedTodayValue,
          );

          _boostedToday = _toBool(
            boostedTodayValue,
          );

          _faceVerificationUnlocked =
              _toBool(unlockedValue);

          _faceVerified =
              _toBool(verifiedValue);

          _loadingKyc = false;
        });
      } else {
        setState(() {
          _loadingKyc = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingKyc = false;
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    final text = value?.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  String get displayName {
    final value = widget.name?.trim() ?? '';
    return value.isEmpty ? 'POWER FAN User' : value;
  }

  String get displayEmail {
    final value = widget.email?.trim() ?? '';
    return value.isEmpty ? 'No email available' : value;
  }

  bool get requirementsComplete {
    return _checkInDays >= 30 &&
        _boostDays >= 30;
  }

  bool get effectiveFaceVerificationUnlocked {
    return _faceVerificationUnlocked ||
        requirementsComplete;
  }

  String get kycStatus {
    if (_faceVerified) {
      return 'Face Verified';
    }

    if (effectiveFaceVerificationUnlocked) {
      return 'Ready for Face Verification';
    }

    return 'Coming Soon';
  }

  Color get kycStatusColor {
    if (_faceVerified) {
      return successGreen;
    }

    if (effectiveFaceVerificationUnlocked) {
      return primaryPurple;
    }

    return Colors.orange;
  }

  double get referralMiningBonus {
    return widget.activeReferrals * 0.02;
  }

  bool get hasProfileImage {
    final url =
        widget.profileImageUrl?.trim() ?? '';

    return url.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: deepPurple,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryPurple,
          onRefresh: _loadKycProgress,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 16),
                _buildBalances(),
                const SizedBox(height: 16),
                _buildAccountInfo(),
                const SizedBox(height: 16),
                _buildKycSection(),
                const SizedBox(height: 16),
                _buildReferralInfo(),
                const SizedBox(height: 16),
                _buildMigrationInfo(),
                const SizedBox(height: 16),
                _buildSecurityInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primaryPurple,
            deepPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _buildProfilePhoto(),
          const SizedBox(height: 12),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            displayEmail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color:
                  Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 5),
                Text(
                  'POWER FAN NETWORK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhoto() {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              Colors.white.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasProfileImage
            ? Image.network(
                widget.profileImageUrl!.trim(),
                width: 98,
                height: 98,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _buildInitialAvatar();
                },
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Container(
                    color: Colors.white.withValues(
                      alpha: 0.15,
                    ),
                    alignment: Alignment.center,
                    child:
                        const SizedBox(
                      width: 25,
                      height: 25,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              )
            : _buildInitialAvatar(),
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Container(
      width: 98,
      height: 98,
      alignment: Alignment.center,
      color:
          Colors.white.withValues(alpha: 0.15),
      child: Text(
        _initials(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _initials() {
    final value = displayName.trim();

    if (value.isEmpty) {
      return 'PF';
    }

    final parts =
        value.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      final text = parts.first;

      return text
          .substring(
            0,
            text.length > 2
                ? 2
                : text.length,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}'
        '${parts.last[0]}'
        .toUpperCase();
  }

  Widget _buildBalances() {
    return Row(
      children: [
        Expanded(
          child: _buildBalanceCard(
            title: 'FAN Balance',
            value: widget.fanBalance
                .toStringAsFixed(4),
            suffix: 'FAN',
            icon: Icons.bolt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBalanceCard(
            title: 'AFAM Balance',
            value: widget.afamBalance
                .toStringAsFixed(4),
            suffix: 'AFAM',
            icon:
                Icons.account_balance_wallet,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required String value,
    required String suffix,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: primaryPurple,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            suffix,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: primaryPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfo() {
    return _buildSection(
      title: 'Account Information',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow(
          icon: Icons.person,
          title: 'Name',
          value: displayName,
        ),
        _buildInfoRow(
          icon: Icons.email_outlined,
          title: 'Email',
          value: displayEmail,
        ),
        _buildInfoRow(
          icon: Icons.shield_outlined,
          title: 'Account Status',
          value: 'Active',
          valueColor: successGreen,
        ),
      ],
    );
  }

  Widget _buildKycSection() {
    final checkInComplete =
        _checkInDays >= 30;

    final boostComplete =
        _boostDays >= 30;

    final requirementsComplete =
        checkInComplete &&
        boostComplete;

    return _buildSection(
      title: 'KYC Face Verification',
      icon:
          Icons.face_retouching_natural,
      children: [
        _buildProgressRow(
          icon: Icons.calendar_month,
          title: 'Daily Check-in',
          value:
              '$_checkInDays / 30 days',
          progress:
              _checkInDays / 30,
          completed:
              checkInComplete,
          todayCompleted:
              _checkedInToday,
        ),
        _buildProgressRow(
          icon: Icons.bolt,
          title: 'Daily Boost',
          value:
              '$_boostDays / 30 days',
          progress:
              _boostDays / 30,
          completed:
              boostComplete,
          todayCompleted:
              _boostedToday,
        ),
        _buildInfoRow(
          icon: Icons.face,
          title: 'Face Verification',
          value: kycStatus,
          valueColor:
              kycStatusColor,
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryPurple.withValues(
              alpha: 0.05,
            ),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Text(
            requirementsComplete
                ? 'KYC requirements completed. Face Verification is now unlocked.'
                : 'KYC Face Verification becomes available after 30 consecutive daily check-ins and at least one boost every day for 30 days.',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
        if (_loadingKyc) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            minHeight: 2,
            color: primaryPurple,
          ),
        ],
      ],
    );
  }

  Widget _buildProgressRow({
    required IconData icon,
    required String title,
    required String value,
    required double progress,
    required bool completed,
    required bool todayCompleted,
  }) {
    final safeProgress =
        progress.clamp(0.0, 1.0);

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    Colors.grey.shade500,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                  color: completed
                      ? successGreen
                      : Colors.black87,
                ),
              ),
              if (completed) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: successGreen,
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),
            child:
                LinearProgressIndicator(
              value: safeProgress,
              minHeight: 6,
              backgroundColor:
                  Colors.grey.shade200,
              valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                completed
                    ? successGreen
                    : primaryPurple,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment:
                Alignment.centerLeft,
            child: Row(
              children: [
                Icon(
                  todayCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 13,
                  color: todayCompleted
                      ? successGreen
                      : Colors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  todayCompleted
                      ? 'Completed today'
                      : 'Not completed today',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w500,
                    color: todayCompleted
                        ? successGreen
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralInfo() {
    return _buildSection(
      title: 'Referral Information',
      icon: Icons.people_outline,
      children: [
        _buildInfoRow(
          icon: Icons.people,
          title: 'Active Referrals',
          value:
              '${widget.activeReferrals}',
        ),
        _buildInfoRow(
          icon: Icons.bolt,
          title: 'Mining Bonus',
          value:
              '+${referralMiningBonus.toStringAsFixed(2)} FAN/H',
          valueColor: successGreen,
        ),
        _buildInfoRow(
          icon: Icons.card_giftcard,
          title: 'Your Referral Reward',
          value: '5 FAN',
        ),
        _buildInfoRow(
          icon: Icons.person_add_alt,
          title: 'New User Reward',
          value: '20 FAN',
        ),
      ],
    );
  }

  Widget _buildMigrationInfo() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  primaryPurple.withValues(
                alpha: 0.08,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: primaryPurple,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Migration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'FAN → AFAM',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '100 FAN = 1 AFAM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                    color: primaryPurple,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color:
                  primaryPurple.withValues(
                alpha: 0.08,
              ),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: const Text(
              'COMING SOON',
              style: TextStyle(
                fontSize: 8,
                fontWeight:
                    FontWeight.bold,
                color: primaryPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.security,
            color: successGreen,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Security',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'POWER FAN NETWORK uses one-device-per-account protection to help prevent multiple accounts from being used on the same device.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: primaryPurple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
                Colors.grey.shade500,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
                color:
                    valueColor ??
                        Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
