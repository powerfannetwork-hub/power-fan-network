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
              _buildEmptyState
