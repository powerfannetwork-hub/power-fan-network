// lib/pages/referral_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../globals/app_constants.dart';
import '../services/auth_service.dart';

class ReferralPage extends StatefulWidget {
  final AuthService authService;

  const ReferralPage({
    super.key,
    required this.authService,
  });

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  bool _loading = true;
  bool _applying = false;

  String _referralCode = '';
  int _activeReferrals = 0;
  double _miningRate = AppConstants.baseMiningRate;

  List<Map<String, dynamic>> _referrals = [];

  final TextEditingController _referralController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _loadReferrals() async {
    setState(() => _loading = true);

    try {
      final result =
          await widget.authService.getReferrals();

      if (!mounted) return;

      if (result['success'] == true) {
        final referrals =
            result['referrals'];

        setState(() {
          _referralCode =
              '${result['referralCode'] ?? ''}';

          _activeReferrals =
              int.tryParse(
                    '${result['activeReferrals'] ?? 0}',
                  ) ??
                  0;

          _miningRate =
              double.tryParse(
                    '${result['miningRate'] ?? AppConstants.baseMiningRate}',
                  ) ??
                  AppConstants.baseMiningRate;

          _referrals =
              referrals is List
                  ? referrals
                      .whereType<Map>()
                      .map(
                        (item) =>
                            Map<String, dynamic>.from(item),
                      )
                      .toList()
                  : [];
        });
      } else {
        _showMessage(
          '${result['message'] ?? 'Could not load referrals.'}',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Could not load referrals.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _applyReferral() async {
    final code =
        _referralController.text.trim();

    if (code.isEmpty) {
      _showMessage(
        'Enter a referral code.',
      );
      return;
    }

    setState(() => _applying = true);

    try {
      final result =
          await widget.authService.applyReferral(
        code,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _referralController.clear();

        _showMessage(
          '${result['message'] ?? 'Referral applied successfully.'}',
        );

        await _loadReferrals();
      } else {
        _showMessage(
          '${result['message'] ?? 'Could not apply referral.'}',
        );
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Could not apply referral.',
      );
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  void _copyReferralCode() {
    if (_referralCode.isEmpty) return;

    Clipboard.setData(
      ClipboardData(
        text: _referralCode,
      ),
    );

    _showMessage(
      'Referral code copied.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty ||
        parts.first.isEmpty) {
      return 'F';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return (
      '${parts.first[0]}${parts.last[0]}'
    ).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          const Color(
            AppConstants.lightBackgroundColorValue,
          ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Referrals',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReferrals,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  32,
                ),
                children: [
                  _buildReferralHero(theme),
                  const SizedBox(height: 16),
                  _buildStats(),
                  const SizedBox(height: 16),
                  _buildHowItWorks(),
                  const SizedBox(height: 20),
                  _buildApplyReferral(),
                  const SizedBox(height: 24),
                  _buildReferralList(),
                ],
              ),
            ),
    );
  }

  Widget _buildReferralHero(
    ThemeData theme,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(
              AppConstants.primaryColorValue,
            ),
            Color(
              AppConstants.deepPurpleColorValue,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(
              AppConstants.primaryColorValue,
            ).withOpacity(0.22),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Invite & Earn FAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Share your referral code with friends.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your referral code',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  _referralCode.isEmpty
                      ? '—'
                      : _referralCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      _referralCode.isEmpty
                          ? null
                          : _copyReferralCode,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon:
                Icons.people_alt_rounded,
            title: 'Active Referrals',
            value:
                '$_activeReferrals',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon:
                Icons.speed_rounded,
            title: 'Mining Rate',
            value:
                '${_miningRate.toStringAsFixed(2)} FAN/h',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black
              .withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(
              AppConstants.greenColorValue,
            ),
            size: 25,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral Rewards',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _rewardRow(
            Icons.person_add_alt_1_rounded,
            'New user reward',
            '+20 FAN',
          ),
          const SizedBox(height: 13),
          _rewardRow(
            Icons.card_giftcard_rounded,
            'Inviter reward',
            '+5 FAN',
          ),
          const SizedBox(height: 13),
          _rewardRow(
            Icons.trending_up_rounded,
            'Mining boost',
            '+0.02 FAN/h',
          ),
        ],
      ),
    );
  }

  Widget _rewardRow(
    IconData icon,
    String title,
    String reward,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(
            color: const Color(
              AppConstants.greenColorValue,
            ).withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(
              AppConstants.greenColorValue,
            ),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          reward,
          style: const TextStyle(
            color: Color(
              AppConstants.greenColorValue,
            ),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildApplyReferral() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a referral code?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Apply a valid referral code to your account.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller:
                _referralController,
            textCapitalization:
                TextCapitalization.characters,
            decoration:
                InputDecoration(
              hintText:
                  'Enter referral code',
              prefixIcon:
                  const Icon(
                Icons.confirmation_number_outlined,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _applying
                      ? null
                      : _applyReferral,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  AppConstants.primaryColorValue,
                ),
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: _applying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Text(
                      'Apply Referral',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralList() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your Referrals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$_activeReferrals',
              style: const TextStyle(
                color: Color(
                  AppConstants.greenColorValue,
                ),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_referrals.isEmpty)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(24),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 48,
                  color: Colors.black26,
                ),
                SizedBox(height: 10),
                Text(
                  'No referrals yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share your referral code to invite new users.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ..._referrals.map(
            _referralTile,
          ),
      ],
    );
  }

  Widget _referralTile(
    Map<String, dynamic> referral,
  ) {
    final name =
        '${referral['name'] ?? ''}'.trim();

    final email =
        '${referral['email'] ?? ''}'.trim();

    final miningActive =
        referral['miningActive'] == true;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor:
                const Color(
              AppConstants.primaryColorValue,
            ).withOpacity(0.10),
            child: Text(
              _initials(
                name.isEmpty
                    ? 'FAN'
                    : name,
              ),
              style: const TextStyle(
                color: Color(
                  AppConstants.primaryColorValue,
                ),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? 'POWER FAN user'
                      : name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color: miningActive
                  ? const Color(
                      AppConstants.greenColorValue,
                    ).withOpacity(0.10)
                  : Colors.black
                      .withOpacity(0.05),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Text(
              miningActive
                  ? 'Mining'
                  : 'Inactive',
              style: TextStyle(
                color: miningActive
                    ? const Color(
                        AppConstants.greenColorValue,
                      )
                    : Colors.black54,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
