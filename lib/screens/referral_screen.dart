import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/referral_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({
    super.key,
  });

  @override
  State<ReferralScreen> createState() =>
      _ReferralScreenState();
}

class _ReferralScreenState
    extends State<ReferralScreen> {
  final ReferralService _referralService =
      ReferralService.instance;

  ReferralInfo? _info;

  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadReferralInfo();
  }

  Future<void> _loadReferralInfo() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final info =
          await _referralService.getReferralInfo();

      if (!mounted) return;

      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        _cleanError(error),
      );
    }
  }

  Future<void> _copyReferralCode() async {
    final code = _info?.referralCode.trim() ?? '';

    if (code.isEmpty) {
      _showMessage(
        'Your referral code is not available yet.',
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: code),
    );

    if (!mounted) return;

    _showMessage(
      'Referral code copied.',
    );
  }

  Future<void> _applyReferralCode() async {
    final controller =
        TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Enter Referral Code',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Referral Code',
              hintText: 'Enter code',
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'CANCEL',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext)
                    .pop(value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF3B159B),
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'APPLY',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (code == null ||
        code.trim().isEmpty) {
      return;
    }

    await _submitReferralCode(
      code.trim(),
    );
  }

  Future<void> _submitReferralCode(
    String code,
  ) async {
    if (_applying) return;

    setState(() {
      _applying = true;
    });

    try {
      final result =
          await _referralService
              .applyReferralCode(code);

      if (!mounted) return;

      setState(() {
        _applying = false;
      });

      if (result.success) {
        await _loadReferralInfo();

        if (!mounted) return;

        _showMessage(
          result.message.isNotEmpty
              ? result.message
              : 'Referral code applied successfully.',
        );

        return;
      }

      _showMessage(
        result.message.isNotEmpty
            ? result.message
            : 'Unable to apply referral code.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _applying = false;
      });

      _showMessage(
        _cleanError(error),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    if (text.startsWith(
      'PostgrestException: ',
    )) {
      text = text.substring(19);
    }

    return text.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text(
          'Referrals',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            const Color(0xFFF8F8FC),
        foregroundColor:
            const Color(0xFF241064),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : _loadReferralInfo,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReferralInfo,
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  30,
                ),
                children: [
                  _buildHero(info),
                  const SizedBox(height: 16),
                  _buildReferralCode(info),
                  const SizedBox(height: 16),
                  _buildStats(info),
                  const SizedBox(height: 16),
                  _buildRewards(),
                  const SizedBox(height: 16),
                  _buildMiningBonus(info),
                  const SizedBox(height: 16),
                  _buildApplyReferral(),
                  const SizedBox(height: 16),
                  _buildInfo(),
                ],
              ),
      ),
    );
  }

  Widget _buildHero(
    ReferralInfo? info,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF241064),
            Color(0xFF3B159B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.13),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Invite Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Build your referral network and increase your mining rate.',
            style: TextStyle(
              color: Colors.white
                  .withValues(alpha: 0.76),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  title: 'ACTIVE',
                  value:
                      '${info?.activeReferrals ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  title: 'BONUS',
                  value:
                      '+${(info?.miningBonus ?? 0).toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white
                  .withValues(alpha: 0.60),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCode(
    ReferralInfo? info,
  ) {
    final code =
        info?.referralCode.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.qr_code_rounded,
                color: Color(0xFF3B159B),
              ),
              SizedBox(width: 9),
              Text(
                'My Referral Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFF8F8FC),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code.isEmpty
                        ? 'Not available'
                        : code,
                    style: const TextStyle(
                      color:
                          Color(0xFF241064),
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: code.isEmpty
                      ? null
                      : _copyReferralCode,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color:
                        Color(0xFF3B159B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Share this code with new users when they create their account.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(
    ReferralInfo? info,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  icon: Icons.people_alt_rounded,
                  title: 'Total Referrals',
                  value:
                      '${info?.totalReferrals ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  icon:
                      Icons.person_rounded,
                  title: 'Active',
                  value:
                      '${info?.activeReferrals ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  icon: Icons.bolt_rounded,
                  title: 'Mining Bonus',
                  value:
                      '+${(info?.miningBonus ?? 0).toStringAsFixed(2)} FAN/H',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox(
                  icon:
                      Icons.card_giftcard_rounded,
                  title: 'Rewards Earned',
                  value:
                      '${(info?.totalInviterRewards ?? 0).toStringAsFixed(0)} FAN',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF8F8FC),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF3B159B),
            size: 21,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewards() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFF3B159B),
              ),
              SizedBox(width: 9),
              Text(
                'Referral Rewards',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _rewardRow(
            icon:
                Icons.person_add_alt_rounded,
            title:
                'New user reward',
            value: '+20 FAN',
          ),
          const SizedBox(height: 10),
          _rewardRow(
            icon:
                Icons.card_giftcard_rounded,
            title:
                'Inviter reward',
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF8F8FC),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(
                0xFF3B159B,
              ).withValues(alpha: 0.09),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color:
                  const Color(0xFF3B159B),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color:
                  Color(0xFF159B61),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningBonus(
    ReferralInfo? info,
  ) {
    final perReferral =
        info?.miningBonusPerActiveReferral ??
            0.02;

    final active =
        info?.activeReferrals ?? 0;

    final bonus =
        info?.miningBonus ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF159B61)
                .withValues(alpha: 0.10),
            const Color(0xFF159B61)
                .withValues(alpha: 0.04),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(
            0xFF159B61,
          ).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color:
                    Color(0xFF159B61),
              ),
              SizedBox(width: 9),
              Text(
                'Mining Rate Bonus',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            '+${bonus.toStringAsFixed(2)} FAN/H',
            style: const TextStyle(
              color:
                  Color(0xFF159B61),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$active active referral${active == 1 ? '' : 's'} × ${perReferral.toStringAsFixed(2)} FAN/H',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyReferral() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.input_rounded,
                color: Color(0xFF3B159B),
              ),
              SizedBox(width: 9),
              Text(
                'Have a Referral Code?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the referral code from the person who invited you.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _applying
                  ? null
                  : _applyReferralCode,
              icon: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.link_rounded,
                    ),
              label: Text(
                _applying
                    ? 'APPLYING...'
                    : 'APPLY REFERRAL CODE',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF3B159B),
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    Colors.grey.shade400,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF3B159B),
              ),
              SizedBox(width: 9),
              Text(
                'How Referrals Work',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 13),
          _InfoPoint(
            number: '1',
            text:
                'Share your referral code with a new user.',
          ),
          SizedBox(height: 9),
          _InfoPoint(
            number: '2',
            text:
                'The new user joins using your referral code.',
          ),
          SizedBox(height: 9),
          _InfoPoint(
            number: '3',
            text:
                'The new user receives 20 FAN and the inviter receives 5 FAN.',
          ),
          SizedBox(height: 9),
          _InfoPoint(
            number: '4',
            text:
                'Each active referral adds 0.02 FAN/H to the inviter mining rate.',
          ),
        ],
      ),
    );
  }
}

class _InfoPoint extends StatelessWidget {
  const _InfoPoint({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(
              0xFF3B159B,
            ).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color:
                  Color(0xFF3B159B),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
