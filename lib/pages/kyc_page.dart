import 'dart:async';

import 'package:camera/camera.dart';
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

  CameraController? _cameraController;
  Timer? _timer;

  KycStatus _status = KycStatus.initial();

  bool _loading = true;
  bool _starting = false;
  bool _completing = false;
  bool _cameraReady = false;
  bool _verificationRunning = false;

  int _secondsRemaining = 30;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadKyc();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadKyc() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final status = await _kycService.getStatus();

      if (!mounted) return;

      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openCameraAndStart() async {
    if (_starting || _verificationRunning) return;

    if (!_status.requirementsComplete) {
      _showMessage(
        'KYC is not available yet. Complete 30 days of Daily Check-in and 30 days of Boost first.',
        isError: true,
      );
      return;
    }

    if (_status.faceVerified) {
      _showMessage('Your face verification is already completed.');
      return;
    }

    setState(() {
      _starting = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'No camera was found on this device.',
        );
      }

      CameraDescription? frontCamera;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      frontCamera ??= cameras.first;

      final response =
          await _kycService.startFaceVerification();

      final success = _readBool(
        response['success'],
        fallback: true,
      );

      if (!success) {
        throw Exception(
          response['message']?.toString() ??
              'Unable to start face verification.',
        );
      }

      await _cameraController?.dispose();

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;

      setState(() {
        _starting = false;
        _cameraReady = true;
        _verificationRunning = true;
        _secondsRemaining = 30;
      });

      _startCountdown();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _starting = false;
        _cameraReady = false;
        _verificationRunning = false;
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });

      _showMessage(
        _errorMessage ?? 'Unable to start face verification.',
        isError: true,
      );
    }
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
          });

          await _completeVerification();
          return;
        }

        setState(() {
          _secondsRemaining--;
        });
      },
    );
  }

  Future<void> _completeVerification() async {
    if (_completing) return;

    setState(() {
      _completing = true;
    });

    try {
      final response =
          await _kycService.completeFaceVerification();

      final success = _readBool(
        response['success'],
        fallback: false,
      );

      final completed = _readBool(
        response['completed'],
        fallback: success,
      );

      if (!success && !completed) {
        throw Exception(
          response['message']?.toString() ??
              'Face verification could not be completed.',
        );
      }

      await _stopCamera();

      if (!mounted) return;

      setState(() {
        _completing = false;
        _verificationRunning = false;
        _cameraReady = false;
        _status = KycStatus(
          available: true,
          comingSoon: false,
          migrationAvailable:
              _status.migrationAvailable,
          checkInDays: _status.checkInDays,
          boostDays: _status.boostDays,
          checkedInToday: _status.checkedInToday,
          boostedToday: _status.boostedToday,
          faceVerificationUnlocked: true,
          faceVerified: true,
          faceVerificationStarted: false,
        );
      });

      _showMessage(
        'Face verification completed successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _completing = false;
        _verificationRunning = false;
        _cameraReady = false;
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });

      await _stopCamera();

      if (!mounted) return;

      _showMessage(
        _errorMessage ??
            'Face verification could not be completed.',
        isError: true,
      );

      await _loadKyc();
    }
  }

  Future<void> _stopCamera() async {
    _timer?.cancel();
    _timer = null;

    final controller = _cameraController;
    _cameraController = null;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _cameraReady = false;
      _verificationRunning = false;
    });
  }

  Future<void> _cancelVerification() async {
    if (_completing) return;

    await _stopCamera();

    if (!mounted) return;

    setState(() {
      _secondsRemaining = 30;
    });

    _showMessage(
      'Face verification was cancelled.',
      isError: true,
    );

    await _loadKyc();
  }

  Future<void> _refresh() async {
    await _loadKyc();
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

  bool _readBool(
    dynamic value, {
    required bool fallback,
  }) {
    if (value == null) return fallback;

    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    final text = value.toString().toLowerCase().trim();

    if (text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'success') {
      return true;
    }

    if (text == 'false' ||
        text == '0' ||
        text == 'no') {
      return false;
    }

    return fallback;
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
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ||
                    _starting ||
                    _verificationRunning
                ? null
                : _refresh,
            icon: const Icon(Icons.refresh),
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
              onRefresh: _refresh,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  35,
                ),
                children: [
                  if (_verificationRunning)
                    _buildCameraVerification()
                  else ...[
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    _buildRequirementsCard(),
                    const SizedBox(height: 16),
                    _buildFaceVerificationCard(),
                    const SizedBox(height: 16),
                    _buildMigrationCard(),
                    const SizedBox(height: 16),
                    _buildSecurityCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
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
            child: const Icon(
              Icons.verified_user,
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
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _status.faceVerified
                ? 'Face verification completed'
                : _status.requirementsComplete
                    ? 'Face verification is ready'
                    : 'Complete the requirements first',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard() {
    final checkinProgress =
        (_status.checkInDays / 30).clamp(0.0, 1.0);

    final boostProgress =
        (_status.boostDays / 30).clamp(0.0, 1.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KYC Requirements',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: deepPurple,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You must complete both requirements for 30 days.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          _buildProgressItem(
            icon: Icons.calendar_today,
            title: 'Daily Check-in',
            current: _status.checkInDays,
            total: 30,
            progress: checkinProgress,
            completed:
                _status.checkInRequirementComplete,
            todayDone: _status.checkedInToday,
          ),
          const SizedBox(height: 18),
          _buildProgressItem(
            icon: Icons.bolt,
            title: 'Daily Boost',
            current: _status.boostDays,
            total: 30,
            progress: boostProgress,
            completed:
                _status.boostRequirementComplete,
            todayDone: _status.boostedToday,
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: completed
                    ? greenColor.withOpacity(0.10)
                    : primaryColor.withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                completed
                    ? Icons.check
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
                      fontWeight: FontWeight.bold,
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
                Icons.verified,
                color: greenColor,
              )
            else if (todayDone)
              const Icon(
                Icons.check_circle,
                color: greenColor,
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: Colors.grey.shade200,
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

  Widget _buildFaceVerificationCard() {
    final verified = _status.faceVerified;
    final unlocked =
        _status.faceVerificationUnlocked ||
            _status.requirementsComplete;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      ? Icons.face_retouching_natural
                      : Icons.face,
                  color: verified
                      ? greenColor
                      : primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Live Face Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            verified
                ? 'Your face verification has been completed.'
                : unlocked
                    ? 'You can now verify your face using the front camera.'
                    : 'Face verification will unlock after completing 30 days of Daily Check-in and 30 days of Daily Boost.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          if (!verified && unlocked)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _starting
                    ? null
                    : _openCameraAndStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                icon: _starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                      ),
                label: Text(
                  _starting
                      ? 'OPENING CAMERA...'
                      : 'START FACE VERIFICATION',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else if (verified)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color:
                    greenColor.withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: greenColor,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KYC Face Verification Completed',
                      style: TextStyle(
                        color: greenColor,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraVerification() {
    final controller = _cameraController;

    return Column(
      children: [
        _card(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const Text(
                'Live Face Verification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: deepPurple,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _completing
                    ? 'Completing verification...'
                    : 'Keep your face inside the frame.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 18),
              if (_cameraReady &&
                  controller != null &&
                  controller.value.isInitialized)
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio:
                        controller.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        Center(
                          child: Container(
                            width: 230,
                            height: 310,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                120,
                              ),
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black
                                  .withOpacity(0.60),
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                            child: Text(
                              'Keep your face visible • $_secondsRemaining seconds',
                              textAlign:
                                  TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  height: 430,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value:
                      (30 - _secondsRemaining) / 30,
                  minHeight: 10,
                  backgroundColor:
                      Colors.grey.shade200,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _completing
                    ? 'Please wait...'
                    : 'Verification time remaining: $_secondsRemaining seconds',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: deepPurple,
                ),
              ),
              const SizedBox(height: 18),
              if (!_completing)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed:
                        _cancelVerification,
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          Colors.red.shade700,
                      side: BorderSide(
                        color: Colors.red.shade300,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: primaryColor,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Keep your face clearly visible during the entire verification. Do not close the camera until the timer reaches zero.',
                  style: TextStyle(
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMigrationCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz,
                color: primaryColor,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'FAN → AFAM Migration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
              ),
              _comingSoonBadge(),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '100 FAN = 1 AFAM',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Migration is currently unavailable. When migration opens, eligible FAN will be converted to AFAM automatically according to the official conversion rate.',
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.5,
              fontSize: 13,
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
          const Row(
            children: [
              Icon(
                Icons.security,
                color: greenColor,
              ),
              SizedBox(width: 10),
              Text(
                'Security',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KYC is designed to help protect the network from duplicate accounts. Account-device restrictions are enforced by the server.',
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Note: the 30-second camera session alone is not a complete biometric liveness system. Strong anti-spoofing requires a dedicated liveness/identity verification system.',
            style: TextStyle(
              color: Colors.orange.shade800,
              height: 1.5,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'COMING SOON',
        style: TextStyle(
          color: Colors.orange.shade800,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding =
        const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
