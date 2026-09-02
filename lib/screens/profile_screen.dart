import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final String? name;
  final String? email;
  final double fanBalance;
  final double afamBalance;
  final int activeReferrals;
  final bool kyc1Verified;
  final bool kyc2Eligible;

  const ProfileScreen({
    super.key,
    this.name,
    this.email,
    this.fanBalance = 0.0,
    this.afamBalance = 0.0,
    this.activeReferrals = 0,
    this.kyc1Verified = false,
    this.kyc2Eligible = false,
  });

  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'POWER FAN User' : value;
  }

  String get displayEmail {
    final value = email?.trim() ?? '';
    return value.isEmpty ? 'No email available' : value;
  }

  String get verificationStatus {
    if (kyc2Eligible) {
      return 'KYC 2 Eligible';
    }

    if (kyc1Verified) {
      return 'KYC 1 Verified';
    }

    return 'KYC 1 In Progress';
  }

  Color get verificationColor {
    if (kyc2Eligible || kyc1Verified) {
      return const Color(0xFF159B61);
    }

    return Colors.orange;
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
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 16),
              _buildBalances(),
              const SizedBox(height: 16),
              _buildAccountInfo(),
              const SizedBox(height: 16),
              _buildVerification(),
              const SizedBox(height: 16),
              _buildReferralInfo(),
              const SizedBox(height: 16),
              _buildMigrationInfo(),
            ],
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
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.30,
                ),
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
              color: Colors.white.withValues(
                alpha: 0.80,
              ),
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
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
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

    final parts = value.split(
      RegExp(r'\s+'),
    );

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length > 2
                ? 2
                : parts.first.length,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
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

  Widget _buildVerification() {
    return _buildSection(
      title: 'Verification',
      icon: Icons.verified_outlined,
      children: [
        _buildInfoRow(
          icon: Icons.looks_one,
          title: 'KYC 1',
          value: kyc1Verified
              ? 'Verified'
              : 'In Progress',
          valueColor: kyc1Verified
              ? const Color(0xFF159B61)
              : Colors.orange,
        ),
        _buildInfoRow(
          icon: Icons.looks_two,
          title: 'KYC 2',
          value: kyc2Eligible
              ? 'Eligible'
              : 'In Progress',
          valueColor: kyc2Eligible
              ? const Color(0xFF159B61)
              : Colors.orange,
        ),
        _buildInfoRow(
          icon: Icons.verified_user,
          title: 'Current Status',
          value: verificationStatus,
          valueColor: verificationColor,
        ),
      ],
    );
  }

  Widget _buildReferralInfo() {
    final bonus =
        activeReferrals * 0.02;

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
              '+${bonus.toStringAsFixed(2)} FAN/H',
          valueColor:
              const Color(0xFF159B61),
        ),
        _buildInfoRow(
          icon: Icons.card_giftcard,
          title: 'Referral Reward',
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
              color: const Color(0xFF3B159B)
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz,
              color: Color(0xFF3B159B),
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
                  'Coming Soon • 2027 Q1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B159B),
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
              color: const Color(0xFF3B159B)
                  .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(8),
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: const Color(0xFF3B159B),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.only(
        bottom: 11,
      ),
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
                color: valueColor ??
                    Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
