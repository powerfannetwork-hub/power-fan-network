import 'package:flutter/material.dart';

class ReferralItem {
  final String id;
  final String name;
  final String username;
  final bool isMining;
  final bool isActive;
  final double miningRate;

  const ReferralItem({
    required this.id,
    required this.name,
    this.username = '',
    this.isMining = false,
    this.isActive = true,
    this.miningRate = 0.0,
  });
}

class ReferralCard extends StatelessWidget {
  final List<ReferralItem> referrals;
  final Future<void> Function(ReferralItem referral)? onPing;
  final bool loading;

  const ReferralCard({
    super.key,
    required this.referrals,
    this.onPing,
    this.loading = false,
  });

  static const double referralReward = 5.0;
  static const double newUserReward = 20.0;
  static const double miningBonusPerReferral = 0.02;

  @override
  Widget build(BuildContext context) {
    final activeCount =
        referrals.where((referral) => referral.isActive).length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 14),

            _buildStats(activeCount),

            const SizedBox(height: 16),

            if (referrals.isEmpty)
              _buildEmptyState()
            else
              ...referrals.map(
                (referral) => _buildReferral(
                  context,
                  referral,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3B159B).withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.people_alt,
            color: Color(0xFF3B159B),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Referrals',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Invite friends and grow your mining rate',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(int activeCount) {
    final miningBonus =
        activeCount * miningBonusPerReferral;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B159B).withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStat(
              icon: Icons.people,
              title: 'Active',
              value: '$activeCount',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildStat(
              icon: Icons.bolt,
              title: 'Mining Bonus',
              value:
                  '+${miningBonus.toStringAsFixed(2)} FAN/H',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF3B159B),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildReferral(
    BuildContext context,
    ReferralItem referral,
  ) {
    final canPing =
        referral.isActive &&
        !referral.isMining &&
        onPing != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(referral),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  referral.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (referral.username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    referral.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: referral.isMining
                            ? const Color(0xFF159B61)
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      referral.isMining
                          ? 'Mining'
                          : 'Mining stopped',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: referral.isMining
                            ? const Color(0xFF159B61)
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),

                if (referral.miningRate > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${referral.miningRate.toStringAsFixed(2)} FAN/H',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (referral.isMining)
            _buildMiningBadge()
          else if (canPing)
            _buildPingButton(
              context,
              referral,
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ReferralItem referral) {
    final letter = referral.name.trim().isEmpty
        ? '?'
        : referral.name
            .trim()
            .substring(0, 1)
            .toUpperCase();

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3B159B).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFF3B159B),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMiningBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF159B61).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.bolt,
            size: 14,
            color: Color(0xFF159B61),
          ),
          SizedBox(width: 3),
          Text(
            'MINING',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF159B61),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPingButton(
    BuildContext context,
    ReferralItem referral,
  ) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: loading
            ? null
            : () => _handlePing(
                  context,
                  referral,
                ),
        icon: const Icon(
          Icons.notifications_active,
          size: 15,
        ),
        label: const Text(
          'PING',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFF3B159B),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Colors.grey.shade300,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePing(
    BuildContext context,
    ReferralItem referral,
  ) async {
    if (onPing == null) {
      return;
    }

    try {
      await onPing!(referral);

      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Mining reminder sent to ${referral.name}.',
              ),
            ),
          );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Unable to send reminder: $error',
              ),
            ),
          );
      }
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 38,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            'No referrals yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Invite friends to start building your referral network.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
