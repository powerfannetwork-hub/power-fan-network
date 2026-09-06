import 'package:flutter/material.dart';

import '../services/kyc_service.dart';

class KycPage extends StatefulWidget {
  const KycPage({super.key});

  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  static const Color primaryColor = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color lightBackground = Color(0xFFF8F8FC);
  static const Color greenColor = Color(0xFF159B61);

  final KycService _kycService = KycService();

  KycStatus _status = KycStatus.initial();

  bool _loading = true;
  bool _checkingIn = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final status = await _kycService.getProgress();

      if (!mounted) return;

      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  Future<void> _claimCheckIn() async {
    if (_checkingIn || _status.checkedInToday) {
      return;
    }

    setState(() {
      _checkingIn = true;
      _errorMessage = null;
    });

    try {
      final updatedStatus =
          await _kycService.claimDailyCheckIn();

      if (!mounted) return;

      setState(() {
        _status = updatedStatus;
        _checkingIn = false;
      });

      _showMessage(
        updatedStatus.checkedInToday
            ? 'Daily Check-in completed successfully.'
            : 'Daily Check-in completed.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _checkingIn = false;
        _errorMessage = _cleanError(error);
      });

      _showMessage(
        _errorMessage ?? 'Unable to complete Daily Check-in.',
        isError: true,
      );
    }
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
        ? 'Something went wrong. Please try again.'
        : text.trim();
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
              isError ? Colors.red.shade700 : greenColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: lightBackground,
        foregroundColor: deepPurple,
        title: const Text(
          'KYC Verification',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 21,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadKyc,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _loadKyc,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  32,
                ),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    _buildErrorCard(),
                  if (_errorMessage != null)
                    const SizedBox(height: 16),
                  _buildRequirementsCard(),
                  const SizedBox(height: 16),
                  _buildFaceVerificationCard(),
                  const SizedBox(height: 16),
                  _buildMigrationCard(),
                  const SizedBox(height: 16),
                  _buildSecurityCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final bool verified = _status.faceVerified;
    final bool ready = _status.requirementsComplete;

    String subtitle;

    if (verified) {
      subtitle =
          'Your KYC face verification has been completed.';
    } else if (ready) {
      subtitle =
          'Your 30-day requirements are complete.';
    } else {
      subtitle =
          'Complete the required activities to unlock KYC.';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            primaryColor,
            deepPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              verified
                  ? Icons.verified_rounded
                  : ready
                      ? Icons.lock_open_rounded
                      : Icons.verified_user_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'POWER FAN KYC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          _buildHeaderStatus(
            verified: verified,
            ready: ready,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatus({
    required bool verified,
    required bool ready,
  }) {
    final String label;

    if (verified) {
      label = 'KYC VERIFIED';
    } else if (ready) {
      label = 'KYC READY';
    } else {
      label = 'IN PROGRESS';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard() {
    final double checkInProgress =
        _status.checkInProgress;

    final double boostProgress =
        _status.boostProgress;

    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'KYC Requirements',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: deepPurple,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Both requirements must reach 30 days.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildProgressItem(
            icon: Icons.calendar_today_rounded,
            title: 'Daily Check-in',
            current: _status.checkInDays,
            total: 30,
            progress: checkInProgress,
            completed:
                _status.checkInDays >= 30,
            todayDone:
                _status.checkedInToday,
          ),
          const SizedBox(height: 22),
          _buildProgressItem(
            icon: Icons.bolt_rounded,
            title: 'Daily Boost',
            current: _status.boostDays,
            total: 30,
            progress: boostProgress,
            completed:
                _status.boostDays >= 30,
            todayDone:
                _status.boostedToday,
          ),
          const SizedBox(height: 20),
          _buildCheckInButton(),
        ],
      ),
    );
  }

  Widget _buildProgressItem({
    required IconData icon,
    required String title,
    required int current,
    required int total,
    required double progress,
    required bool completed,
    required bool todayDone,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: completed
                    ? greenColor.withOpacity(0.10)
                    : primaryColor.withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                completed
                    ? Icons.check_rounded
                    : icon,
                color: completed
                    ? greenColor
                    : primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$current / $total days',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (completed)
              const Icon(
                Icons.verified_rounded,
                color: greenColor,
              )
            else if (todayDone)
              const Icon(
                Icons.check_circle_rounded,
                color: greenColor,
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor:
                Colors.grey.shade200,
            color: completed
                ? greenColor
                : primaryColor,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          completed
              ? 'Requirement completed'
              : todayDone
                  ? 'Today completed'
                  : 'Complete today to continue',
          style: TextStyle(
            fontSize: 12,
            color: completed
                ? greenColor
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    if (_status.checkedInToday) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: greenColor.withOpacity(0.08),
          borderRadius:
              BorderRadius.circular(13),
        ),
        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: greenColor,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'TODAY CHECK-IN COMPLETED',
              style: TextStyle(
                color: greenColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed:
            _checkingIn ? null : _claimCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
        icon: _checkingIn
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.event_available_rounded,
              ),
        label: Text(
          _checkingIn
              ? 'CHECKING IN...'
              : 'DAILY CHECK-IN',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildFaceVerificationCard() {
    final bool verified =
        _status.faceVerified;

    final bool ready =
        _status.requirementsComplete;

    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: verified
                      ? greenColor.withOpacity(0.10)
                      : primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  verified
                      ? Icons.face_retouching_natural_rounded
                      : Icons.face_rounded,
                  color: verified
                      ? greenColor
                      : primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Face Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: deepPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            verified
                ? 'Your identity has been verified.'
                : ready
                    ? 'Your KYC requirements are complete. Real face verification can now be performed when the biometric provider is integrated.'
                    : 'Face verification unlocks after completing 30 days of Daily Check-in and 30 days of Daily Boost.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          if (verified)
            _statusBox(
              icon:
                  Icons.check_circle_rounded,
              title: 'KYC VERIFIED',
              message:
                  'Face verification completed successfully.',
              color: greenColor,
            )
          else if (ready)
            _statusBox(
              icon:
                  Icons.hourglass_top_rounded,
              title: 'KYC READY',
              message:
                  'Real biometric verification is not connected yet. This feature will be available soon.',
              color: primaryColor,
            )
          else
            _statusBox(
              icon: Icons.lock_outline_rounded,
              title: 'KYC LOCKED',
              message:
                  'Complete both 30-day requirements first.',
              color: Colors.grey.shade700,
            ),
        ],
      ),
    );
  }

  Widget _statusBox({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationCard() {
    return _card(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.orange,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'AFAM Migration',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Migration is currently COMING SOON. Your FAN balance will remain available until the official migration period.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'COMING SOON',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
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

  Widget _buildSecurityCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'KYC Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'KYC progress is controlled by the Supabase backend. '
            'Daily check-ins and boosts are protected against duplicate claims.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding =
        const EdgeInsets.all(17),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
