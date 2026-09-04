import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String? name;
  final String? email;
  final double fanBalance;
  final double afamBalance;
  final int activeReferrals;

  // New KYC progress
  final int checkInDays;
  final int boostDays;
  final bool faceVerificationUnlocked;
  final bool faceVerified;

  const ProfileScreen({
    super.key,
    this.name,
    this.email,
    this.fanBalance = 0.0,
    this.afamBalance = 0.0,
    this.activeReferrals = 0,
    this.checkInDays = 0,
    this.boostDays = 0,
    this.faceVerificationUnlocked = false,
    this.faceVerified = false,
  });

  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'POWER FAN User' : value;
  }

  String get displayEmail {
    final value = email?.trim() ?? '';
    return value.isEmpty ? 'No email available' : value;
  }

  String get kycStatus {
    if (faceVerified) {
      return 'Face Verified';
    }

    if (faceVerificationUnlocked) {
      return 'Ready for Face Verification';
    }

    return 'Coming Soon';
  }

  Color get kycStatusColor {
    if (faceVerified) {
      return const Color(0xFF159B61);
    }

    if (faceVerificationUnlocked) {
      return const Color(0xFF3B159B);
    }

    return Colors.orange;
  }

  int get checkInProgress {
    if (checkInDays < 0) return 0;
    if (checkInDays > 30) return 30;
    return checkInDays;
  }

  int get boostProgress {
    if (boostDays < 0) return 0;
    if (boostDays > 30) return 30;
    return boostDays;
  }

  double get referralMiningBonus {
    return activeReferrals * 0.02;
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
        foregroundColor: const Color(0xFF241064),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF3B159B),
          onRefresh: () async {
            // Profile data is supplied by the parent.
            // Refresh can be connected later if needed.
            await Future<void>.delayed(
              const Duration(milliseconds: 300),
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
            Color(0xFF3B159B),
            Color(0xFF241064),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 2,
              ),
            ),
            child: Text(
              _initials(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
              color: Colors.white.withValues(alpha: 0.80),
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
              color: Colors.white.withValues(alpha: 0.12),
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

  String _initials() {
    final value = displayName.trim();

    if (value.isEmpty) {
      return 'PF';
    }

    final parts = value.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      final text = parts.first;

      return text
          .substring(
            0,
            text.length > 2 ? 2 : text.length,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildBalances() {
    return Row(
      children: [
        Expanded(
          child: _buildBalanceCard(
            title: 'FAN Balance',
            value: fanBalance.toStringAsFixed(4),
            suffix: 'FAN',
            icon: Icons.bolt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBalanceCard(
            title: 'AFAM Balance',
            value: afamBalance.toStringAsFixed(4),
            suffix: 'AFAM',
            icon: Icons.account_balance_wallet,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF3B159B),
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
              color: Color(0xFF3B159B),
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
          valueColor: const Color(0xFF159B61),
        ),
      ],
    );
  }

  Widget _buildKycSection() {
    final checkInComplete = checkInProgress >= 30;
    final boostComplete = boostProgress >= 30;

    return _buildSection(
      title: 'KYC Face Verification',
      icon: Icons.face_retouching_natural,
      children: [
        _buildProgressRow(
          icon: Icons.calendar_month,
          title: 'Daily Check-in',
          value: '$checkInProgress / 30 days',
          progress: checkInProgress / 30,
          completed: checkInComplete,
        ),
        _buildProgressRow(
          icon: Icons.bolt,
          title: 'Daily Boost',
          value: '$boostProgress / 30 days',
          progress: boostProgress / 30,
          completed: boostComplete,
        ),
        _buildInfoRow(
          icon: Icons.face,
          title: 'Face Verification',
          value: kycStatus,
          valueColor: kycStatusColor,
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3B159B).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'KYC Face Verification becomes available after '
            '30 consecutive daily check-ins and at least one '
            'boost every day for 30 days.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow({
    required IconData icon,
    required String title,
    required String value,
    required double progress,
    required bool completed,
  }) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: completed
                      ? const Color(0xFF159B61)
                      : Colors.black87,
                ),
              ),
              if (completed) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF159B61),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                completed
                    ? const Color(0xFF159B61)
                    : const Color(0xFF3B159B),
              ),
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
          value: '$activeReferrals',
        ),
        _buildInfoRow(
          icon: Icons.bolt,
          title: 'Mining Bonus',
          value:
              '+${referralMiningBonus.toStringAsFixed(2)} FAN/H',
          valueColor: const Color(0xFF159B61),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3B159B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: Color(0xFF3B159B),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Migration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B159B),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Coming Soon • 2027 Q1',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF3B159B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'COMING SOON',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B159B),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.security,
            color: Color(0xFF159B61),
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Security',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'POWER FAN NETWORK uses one-device-per-account '
                  'protection to help prevent multiple accounts '
                  'from being used on the same device.',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: const Color(0xFF3B159B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
