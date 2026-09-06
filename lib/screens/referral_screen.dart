import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/referral_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  static const Color primaryPurple = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color lightBackground = Color(0xFFF8F8FC);

  final ReferralService _referralService = ReferralService.instance;

  ReferralInfo? _referralInfo;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadReferralInfo();
  }

  Future<void> _loadReferralInfo() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final info = await _referralService.getReferralInfo();

      if (!mounted) return;

      setState(() {
        _referralInfo = info;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  Future<void> _copyReferralCode() async {
    final code = _referralInfo?.referralCode ?? '';

    if (code.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: code),
    );

    if (!mounted) return;

    _showMessage('Referral code copied.');
  }

  Future<void> _shareReferralCode() async {
    final code = _referralInfo?.referralCode ?? '';

    if (code.isEmpty) {
      _showMessage(
        'Your referral code is not available yet.',
        isError: true,
      );
      return;
    }

    final message =
        'Join POWER FAN NETWORK and start mining FAN.\n\n'
        'Use my referral code: $code\n\n'
        'POWER FAN NETWORK';

    await Share.share(message);
  }

  Future<void> _showApplyReferralDialog() async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Apply Referral Code',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter a valid referral code from the person who invited you.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    textCapitalization:
                        TextCapitalization.characters,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Referral Code',
                      hintText: 'Enter code',
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _applying
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _applying
                      ? null
                      : () async {
                          final code =
                              controller.text.trim();

                          if (code.isEmpty) {
                            setDialogState(() {
                              errorText =
                                  'Enter your referral code.';
                            });
                            return;
                          }

                          setDialogState(() {
                            errorText = null;
                          });

                          if (mounted) {
                            setState(() {
                              _applying = true;
                            });
                          }

                          final result =
                              await _referralService
                                  .applyReferralCode(code);

                          if (!mounted) return;

                          setState(() {
                            _applying = false;
                          });

                          if (!result.success) {
                            setDialogState(() {
                              errorText = result.message;
                            });
                            return;
                          }

                          Navigator.of(dialogContext).pop();

                          _showMessage(
                            result.message.isEmpty
                                ? 'Referral code applied successfully.'
                                : result.message,
                          );

                          await _loadReferralInfo();
                        },
                  child: _applying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('APPLY'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    if (text.startsWith('PostgrestException: ')) {
      text = text.substring(19);
    }

    return text.trim().isEmpty
        ? 'Unable to load referral information.'
        : text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        backgroundColor: lightBackground,
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
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildReferralCodeCard(),
                  const SizedBox(height: 16),
                  _buildApplyReferralCard(),
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
            'Invite your friends to join POWER FAN NETWORK and earn FAN rewards.',
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
                  onPressed:
                      code.isEmpty ? null : _copyReferralCode,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  code.isEmpty ? null : _shareReferralCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(
                Icons.share_rounded,
              ),
              label: const Text(
                'SHARE REFERRAL CODE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyReferralCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a Referral Code?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Apply the code from the person who invited you.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _applying ? null : _showApplyReferralDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryPurple,
                side: const BorderSide(
                  color: primaryPurple,
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(
                Icons.input_rounded,
              ),
              label: const Text(
                'ENTER REFERRAL CODE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final activeReferrals =
        _referralInfo?.activeReferrals ?? 0;

    final earnings =
        _referralInfo?.totalInviterRewards ?? 0;

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
                  value:
                      '${earnings.toStringAsFixed(0)} FAN',
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
        color: lightBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
            title: 'Inviter reward',
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
            borderRadius:
                BorderRadius.circular(11),
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
    final active =
        _referralInfo?.activeReferrals ?? 0;

    final bonus =
        _referralInfo?.miningBonus ?? 0.0;

    return _card(
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: Colors.green,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mining Rate Bonus',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+0.02 FAN/H per active referral',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$active active • +${bonus.toStringAsFixed(2)} FAN/H',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
