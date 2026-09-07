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

  final TextEditingController _referralCodeController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReferralInfo();
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralInfo() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
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

    if (code.isEmpty) {
      _showMessage(
        'Your referral code is not available yet.',
        isError: true,
      );
      return;
    }

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

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Join POWER FAN NETWORK',
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _referralCodeController.text.trim();

    if (code.isEmpty) {
      _showMessage(
        'Please enter a referral code.',
        isError: true,
      );
      return;
    }

    if (_applying) return;

    setState(() {
      _applying = true;
    });

    try {
      final result =
          await _referralService.applyReferralCode(code);

      if (!mounted) return;

      if (!result.success) {
        _showMessage(
          result.message,
          isError: true,
        );
        return;
      }

      _referralCodeController.clear();

      _showMessage(result.message);

      await _loadReferralInfo();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _applying = false;
      });
    }
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
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Colors.red.shade700 : deepPurple,
        ),
      );
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final info = _referralInfo;

    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: lightBackground,
        foregroundColor: deepPurple,
        centerTitle: true,
        title: const Text(
          'Referral',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primaryPurple,
        onRefresh: _loadReferralInfo,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryPurple,
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroCard(info),
                    const SizedBox(height: 16),
                    _buildStatsCard(info),
                    const SizedBox(height: 16),
                    _buildReferralCodeCard(info),
                    const SizedBox(height: 16),
                    _buildMiningBonusCard(info),
                    const SizedBox(height: 16),
                    _buildApplyReferralCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeroCard(ReferralInfo? info) {
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
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'INVITE & EARN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Invite friends and earn FAN rewards.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${info?.totalReferrals ?? 0}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Total Referrals',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ReferralInfo? info) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral Statistics',
            style: TextStyle(
              color: deepPurple,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statItem(
                  icon: Icons.people_alt_rounded,
                  title: 'Total',
                  value: '${info?.totalReferrals ?? 0}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statItem(
                  icon: Icons.bolt_rounded,
                  title: 'Active',
                  value: '${info?.activeReferrals ?? 0}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statItem(
            icon: Icons.monetization_on_rounded,
            title: 'Inviter Rewards',
            value:
                '${(info?.totalInviterRewards ?? 0).toStringAsFixed(4)} FAN',
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String title,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryPurple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: primaryPurple,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: deepPurple,
                    fontSize: 16,
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

  Widget _buildReferralCodeCard(ReferralInfo? info) {
    final code = info?.referralCode ?? '';

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Code',
            style: TextStyle(
              color: deepPurple,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share this code with your friends.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryPurple.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code.isEmpty ? 'Not available' : code,
                    style: const TextStyle(
                      color: deepPurple,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      code.isEmpty ? null : _copyReferralCode,
                  tooltip: 'Copy',
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
              icon: const Icon(Icons.share_rounded),
              label: const Text('SHARE REFERRAL CODE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningBonusCard(ReferralInfo? info) {
    final active = info?.activeReferrals ?? 0;
    final bonus = info?.miningBonus ?? 0;
    final perReferral =
        info?.miningBonusPerActiveReferral ?? 0.02;

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.amber,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mining Referral Bonus',
                  style: TextStyle(
                    color: deepPurple,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '+${bonus.toStringAsFixed(2)} FAN/H',
            style: const TextStyle(
              color: primaryPurple,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$active active referral${active == 1 ? '' : 's'} × '
            '${perReferral.toStringAsFixed(2)} FAN/H',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyReferralCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apply Referral Code',
            style: TextStyle(
              color: deepPurple,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'If someone invited you, enter their referral code here.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _referralCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Enter referral code',
              prefixIcon: const Icon(
                Icons.card_giftcard_rounded,
                color: primaryPurple,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F2FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applying ? null : _applyReferralCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _applying
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'APPLY REFERRAL CODE',
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

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
