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

   
