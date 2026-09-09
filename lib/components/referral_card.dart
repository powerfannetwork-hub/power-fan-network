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
                (referral) => _buildReferralItem(
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF3B159B),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.people_alt_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REFERRALS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Invite friends and earn FAN',
                style: TextStyle(
                  color: Color(0xFF66666F),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(int activeCount) {
    final total = referrals.length;
    final bonusRate = activeCount * miningBonusPerReferral;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat(
              'TOTAL',
              '$total',
            ),
          ),
          _divider(),
          Expanded(
            child: _stat(
              'ACTIVE',
              '$activeCount',
            ),
          ),
          _divider(),
          Expanded(
            child: _stat(
              'BONUS',
              '+${bonusRate.toStringAsFixed(2)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String title,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF3B159B),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF777780),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.group_add_rounded,
            size: 42,
            color: Color(0xFF3B159B),
          ),
          SizedBox(height: 10),
          Text(
            'No referrals yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Invite friends to earn referral rewards.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF777780),
              fontSize: 13,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '+20 FAN for new users • +5 FAN for inviter',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3B159B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralItem(
    BuildContext context,
    ReferralItem referral,
  ) {
    final displayName = referral.name.trim().isNotEmpty
        ? referral.name.trim()
        : referral.username.trim().isNotEmpty
            ? referral.username.trim()
            : 'Power Fan User';

    final canPing =
        onPing != null &&
        referral.isActive &&
        !loading;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: const Color(0xFFF0EEFA),
            child: Text(
              displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : 'P',
              style: const TextStyle(
                color: Color(0xFF3B159B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (referral.username.trim().isNotEmpty)
                  Text(
                    '@${referral.username.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF777780),
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      referral.isMining
                          ? Icons.bolt_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 14,
                      color: referral.isMining
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      referral.isMining
                          ? 'Mining'
                          : 'Not mining',
                      style: TextStyle(
                        color: referral.isMining
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (referral.miningRate > 0)
                      Text(
                        '${referral.miningRate.toStringAsFixed(2)} FAN/H',
                        style: const TextStyle(
                          color: Color(0xFF3B159B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canPing)
            IconButton(
              onPressed: () async {
                await onPing!(referral);
              },
              icon: const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF3B159B),
              ),
              tooltip: 'Ping',
            ),
        ],
      ),
    );
  }
}
