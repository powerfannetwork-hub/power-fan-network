import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/referral_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);

  final ReferralService _referralService = ReferralService.instance;

  ReferralInfo? _referralInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralInfo();
  }

  Future<void> _loadReferralInfo() async {
    setState(() => _loading = true);

    try {
      final info = await _referralService.getReferralInfo();

      if (!mounted) return;

      setState(() {
        _referralInfo = info;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _copyReferralCode() async {
    final code = _referralInfo?.referralCode ?? '';

    if (code.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Referral code copied'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8FC),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Referral',
          style: TextStyle(
            color: deepPurple,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryPurple,
              ),
            )
          : RefreshIndicator(
              color: primaryPurple,
              onRefresh: _loadReferralInfo,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildReferralCodeCard(),
                  const SizedBox(height: 16),
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildRewardsCard(),
                  const SizedBox(height: 16),
                  _buildMiningBonusCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.people_alt_rounded,
            color: Colors.white,
            size: 38,
          ),
          SizedBox(height: 13),
          Text(
            'Invite Friends & Earn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Invite your friends to join POWER FAN NETWORK.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    final code = _referralInfo?.referralCode ?? '';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Code',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code.isEmpty ? '------' : code,
                    style: const TextStyle(
                      color: primaryPurple,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: code.isEmpty ? null : _copyReferralCode,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final activeReferrals = _referralInfo?.activeReferrals ?? 0;
    final earnings = _referralInfo?.earnings ?? 0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral Statistics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Active Referrals',
                  value: '$activeReferrals',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statItem(
                  icon: Icons.monetization_on_rounded,
                  title: 'Referral Earnings',
                  value: '${earnings.toStringAsFixed(0)} FAN',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: primaryPurple,
            size: 23,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral Rewards',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _rewardRow(
            icon: Icons.person_add_alt_1_rounded,
            title: 'New user reward',
            value: '+20 FAN',
          ),
          const SizedBox(height: 10),
          _rewardRow(
            icon: Icons.card_giftcard_rounded,
            title: 'Successful referral',
            value: '+5 FAN',
          ),
        ],
      ),
    );
  }

  Widget _rewardRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryPurple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: primaryPurple,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: primaryPurple,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMiningBonusCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: Colors.green,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mining Rate Bonus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '+0.02 FAN/H for each active referral',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: child,
    );
  }
}
