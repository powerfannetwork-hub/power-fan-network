import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/kyc_service.dart';

class KycPage extends StatefulWidget {
  const KycPage({super.key});

  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  static const Color primaryColor =
      Color(0xFF3B159B);

  static const Color deepPurple =
      Color(0xFF241064);

  static const Color lightBackground =
      Color(0xFFF8F8FC);

  static const Color greenColor =
      Color(0xFF159B61);

  static const Color orangeColor =
      Color(0xFFE88900);

  static const String _bucket =
      'kyc-photos';

  final KycService _kycService =
      KycService();

  final ImagePicker _picker =
      ImagePicker();

  KycStatus _status =
      KycStatus.initial();

  MigrationStatus _migrationStatus =
      MigrationStatus.initial();

  final Map<String, Uint8List> _photos =
      <String, Uint8List>{};

  bool _loading = true;
  bool _checkingIn = false;
  bool _submitting = false;

  String? _errorMessage;

  static const List<Map<String, String>>
      _photoSteps = [
    {
      'key': 'front',
      'title': 'Look straight',
      'hint':
          'Keep your face centered and look directly at the camera.',
    },
    {
      'key': 'left',
      'title': 'Turn left',
      'hint':
          'Slowly turn your face to the left.',
    },
    {
      'key': 'right',
      'title': 'Turn right',
      'hint':
          'Slowly turn your face to the right.',
    },
    {
      'key': 'up',
      'title': 'Look up',
      'hint':
          'Tilt your face slightly upward.',
    },
    {
      'key': 'down',
      'title': 'Look down',
      'hint':
          'Tilt your face slightly downward.',
    },
    {
      'key': 'eyes',
      'title': 'Open your eyes',
      'hint':
          'Look straight and keep both eyes clearly visible.',
    },
  ];

  @override
  void initState() {
    super.initState();

    _log(
      'KYC page initialized.',
    );

    _loadKyc();
  }

  void _log(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'PowerFan.KYC',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadKyc() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _kycService.getProgress(),
        _kycService.getMigrationStatus(),
      ]);

      if (!mounted) return;

      setState(() {
        _status =
            results[0] as KycStatus;

        _migrationStatus =
            results[1] as MigrationStatus;

        _loading = false;
      });

      _log(
        'KYC loaded. '
        'checkIns=${_status.checkInDays}, '
        'boosts=${_status.boostDays}, '
        'requirements=${_status.requirementsComplete}, '
        'submission=${_status.submissionStatus}, '
        'verified=${_status.isVerified}',
      );
    } catch (error, stackTrace) {
      _log(
        'Failed to load KYC.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            _cleanError(error);
      });
    }
  }

  // ============================================================
  // DAILY CHECK-IN
  // ============================================================

  Future<void> _claimCheckIn() async {
    if (_checkingIn ||
        _status.checkedInToday) {
      return;
    }

    setState(() {
      _checkingIn = true;
      _errorMessage = null;
    });

    try {
      await _kycService
          .claimDailyCheckIn();

      if (!mounted) return;

      await _loadKyc();

      if (!mounted) return;

      _showMessage(
        'Daily Check-in completed successfully.',
      );
    } catch (error, stackTrace) {
      _log(
        'Daily check-in failed.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      final message =
          _cleanError(error);

      setState(() {
        _errorMessage = message;
      });

      _showMessage(
        message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingIn = false;
        });
      }
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _captureKycPhoto(
    String key,
    String title,
  ) async {
    if (_submitting ||
        _status.isInReview ||
        _status.isVerified) {
      return;
    }

    try {
      final XFile? image =
          await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice:
            CameraDevice.front,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      final Uint8List bytes =
          await image.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception(
          'The captured photo is empty.',
        );
      }

      if (!mounted) return;

      setState(() {
        _photos[key] = bytes;
      });

      _showMessage(
        '$title photo captured.',
      );
    } catch (error, stackTrace) {
      _log(
        'Camera capture failed for $key.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  // ============================================================
  // SUBMIT KYC
  // ============================================================

  Future<void> _submitManualKyc() async {
    if (_submitting) return;

    if (!_status.requirementsComplete) {
      _showMessage(
        'Complete 30 days of Daily Check-in and Daily Boost first.',
        isError: true,
      );
      return;
    }

    if (_status.isInReview) {
      _showMessage(
        'Your verification is already being processed.',
      );
      return;
    }

    if (_status.isVerified) {
      _showMessage(
        'Your KYC is already verified.',
      );
      return;
    }

    const requiredKeys = [
      'front',
      'left',
      'right',
      'up',
      'down',
      'eyes',
    ];

    for (final key in requiredKeys) {
      if (!_photos.containsKey(key)) {
        _showMessage(
          'Please capture all six required photos first.',
          isError: true,
        );
        return;
      }
    }

    final User? user =
        _kycService.currentUser;

    if (user == null) {
      _showMessage(
        'User session is not available. Please login again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final Map<String, String>
          photoPaths =
          <String, String>{};

      final String timestamp =
          DateTime.now()
              .toUtc()
              .millisecondsSinceEpoch
              .toString();

      for (final step in _photoSteps) {
        final String key =
            step['key']!;

        final Uint8List bytes =
            _photos[key]!;

        final String path =
            '${user.id}/${key}_$timestamp.jpg';

        await Supabase.instance.client
            .storage
            .from(_bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions:
                  const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        photoPaths[key] = path;
      }

      await _kycService.submitManualKyc(
        photoPaths: photoPaths,
      );

      if (!mounted) return;

      setState(() {
        _photos.clear();
      });

      await _loadKyc();

      if (!mounted) return;

      _showMessage(
        'KYC submitted successfully.',
      );
    } catch (error, stackTrace) {
      _log(
        'Manual KYC submission failed.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      final message =
          _cleanError(error);

      setState(() {
        _errorMessage = message;
      });

      _showMessage(
        message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _cleanError(Object error) {
    var text =
        error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      text = text.substring(11);
    }

    if (text.startsWith(
      'PostgrestException: ',
    )) {
      text = text.substring(19);
    }

    if (text.trim().isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    return text.trim();
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
              isError
                  ? Colors.red.shade700
                  : greenColor,
          behavior:
              SnackBarBehavior.floating,
          duration:
              Duration(
            seconds:
                isError ? 6 : 4,
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          lightBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            lightBackground,
        foregroundColor:
            deepPurple,
        title: const Text(
          'KYC Verification',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 21,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _loading
                    ? null
                    : _loadKyc,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _loadKyc,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  32,
                ),
                children: [
                  _buildHeaderCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  if (_errorMessage != null)
                    _buildErrorCard(),

                  if (_errorMessage != null)
                    const SizedBox(
                      height: 16,
                    ),

                  _buildRequirementsCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildFaceVerificationCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildMigrationCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  _buildSecurityCard(),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderCard() {
    final bool verified =
        _status.isVerified;

    final bool inReview =
        _status.isInReview;

    final bool ready =
        _status.requirementsComplete;

    String subtitle;

    if (verified) {
      subtitle =
          'Your KYC verification has been completed.';
    } else if (inReview) {
      subtitle =
          'Your verification is being processed.';
    } else if (ready) {
      subtitle =
          'Your 30-day requirements are complete.';
    } else {
      subtitle =
          'Complete the required activities to unlock KYC verification.';
    }

    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            primaryColor,
            deepPurple,
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                primaryColor.withValues(
              alpha: 0.20,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withValues(
                alpha: 0.15,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              verified
                  ? Icons.verified_rounded
                  : inReview
                      ? Icons
                          .hourglass_top_rounded
                      : ready
                          ? Icons
                              .lock_open_rounded
                          : Icons
                              .verified_user_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'POWER FAN KYC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.white.withValues(
                alpha: 0.90,
              ),
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          _buildHeaderStatus(),
        ],
      ),
    );
  }

  Widget _buildHeaderStatus() {
    final String label;

    if (_status.isVerified) {
      label = 'KYC VERIFIED';
    } else if (_status.isInReview) {
      label = 'IN REVIEW';
    } else if (_status.requirementsComplete) {
      label = 'KYC READY';
    } else {
      label = 'IN PROGRESS';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: 0.14,
        ),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color:
              Colors.white.withValues(
            alpha: 0.25,
          ),
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

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            Colors.red.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              Colors.red.withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade700,
            size: 23,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),

          IconButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUIREMENTS
  // ============================================================

  Widget _buildRequirementsCard() {
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
            icon:
                Icons.calendar_today_rounded,
            title: 'Daily Check-in',
            current:
                _status.checkInDays,
            total: 30,
            progress:
                _status.checkInProgress,
            completed:
                _status.checkInDays >= 30,
            todayDone:
                _status.checkedInToday,
          ),

          const SizedBox(height: 22),

          _buildProgressItem(
            icon: Icons.bolt_rounded,
            title: 'Daily Boost',
            current:
                _status.boostDays,
            total: 30,
            progress:
                _status.boostProgress,
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
              decoration:
                  BoxDecoration(
                color: completed
                    ? greenColor.withValues(
                        alpha: 0.10,
                      )
                    : primaryColor.withValues(
                        alpha: 0.08,
                      ),
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
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$current / $total days',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
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
          child:
              LinearProgressIndicator(
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
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 14,
        ),
        decoration:
            BoxDecoration(
          color:
              greenColor.withValues(
            alpha: 0.08,
          ),
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
                fontWeight:
                    FontWeight.w800,
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
            _checkingIn
                ? null
                : _claimCheckIn,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primaryColor,
          foregroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
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
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FACE KYC
  // ============================================================

  Widget _buildFaceVerificationCard() {
    if (_status.isVerified) {
      return _card(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildFaceTitle(
              verified: true,
            ),
            const SizedBox(height: 15),
            _statusBox(
              icon:
                  Icons.check_circle_rounded,
              title: 'KYC VERIFIED',
              message:
                  'Your identity verification has been completed successfully.',
              color: greenColor,
            ),
          ],
        ),
      );
    }

    if (_status.isInReview) {
      return _card(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildFaceTitle(
              verified: false,
            ),
            const SizedBox(height: 15),
            _statusBox(
              icon:
                  Icons.hourglass_top_rounded,
              title: 'VERIFICATION IN REVIEW',
              message:
                  'Your verification is being processed. You do not need to submit the photos again.',
              color: primaryColor,
            ),
          ],
        ),
      );
    }

    if (!_status.requirementsComplete) {
      return _card(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildFaceTitle(
              verified: false,
            ),
            const SizedBox(height: 15),
            _statusBox(
              icon:
                  Icons.lock_outline_rounded,
              title: 'KYC LOCKED',
              message:
                  'Complete both 30-day requirements first.',
              color: Colors.grey.shade700,
            ),
          ],
        ),
      );
    }

    return _buildReadyVerificationCard();
  }

  Widget _buildFaceTitle({
    required bool verified,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration:
              BoxDecoration(
            color: verified
                ? greenColor.withValues(
                    alpha: 0.10,
                  )
                : primaryColor.withValues(
                    alpha: 0.08,
                  ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            verified
                ? Icons
                    .face_retouching_natural_rounded
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
    );
  }

  // ============================================================
  // READY / PHOTO CAPTURE
  // ============================================================

  Widget _buildReadyVerificationCard() {
    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildFaceTitle(
            verified: false,
          ),

          const SizedBox(height: 15),

          Text(
            'Your KYC requirements are complete. Capture the six required face photos.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
                  Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 16),

          ..._photoSteps.map(
            (step) => _buildPhotoStep(
              step,
            ),
          ),

          const SizedBox(height: 8),

          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildPhotoStep(
    Map<String, String> step,
  ) {
    final String key =
        step['key']!;

    final bool captured =
        _photos.containsKey(key);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color: captured
            ? greenColor.withValues(
                alpha: 0.06,
              )
            : Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: captured
              ? greenColor.withValues(
                  alpha: 0.20,
                )
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color: captured
                  ? greenColor.withValues(
                      alpha: 0.10,
                    )
                  : primaryColor.withValues(
                      alpha: 0.08,
                    ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              captured
                  ? Icons.check_rounded
                  : Icons.camera_alt_rounded,
              color: captured
                  ? greenColor
                  : primaryColor,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  step['title']!,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  captured
                      ? 'Photo captured'
                      : step['hint']!,
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          OutlinedButton(
            onPressed:
                _submitting
                    ? null
                    : () =>
                        _captureKycPhoto(
                          key,
                          step['title']!,
                        ),
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  primaryColor,
              side: BorderSide(
                color:
                    primaryColor.withValues(
                  alpha: 0.30,
                ),
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),
            child: Text(
              captured
                  ? 'RETAKE'
                  : 'CAPTURE',
              style: const TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool complete =
        _photos.length == 6;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed:
            !complete || _submitting
                ? null
                : _submitManualKyc,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primaryColor,
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              Colors.grey.shade300,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
        icon: _submitting
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
                Icons
                    .cloud_upload_rounded,
              ),
        label: Text(
          _submitting
              ? 'SUBMITTING...'
              : complete
                  ? 'SUBMIT KYC'
                  : 'CAPTURE ALL 6 PHOTOS',
          style: const TextStyle(
            fontWeight:
                FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BOX
  // ============================================================

  Widget _statusBox({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: 0.07),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              color.withValues(alpha: 0.12),
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
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
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

  // ============================================================
  // MIGRATION
  // ============================================================

  Widget _buildMigrationCard() {
    final double fanBalance =
        _migrationStatus.fanBalance;

    final double afamBalance =
        _migrationStatus.afamBalance;

    final double conversion =
        _migrationStatus.fanPerAfam;

    return _card(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color:
                      orangeColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: orangeColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'AFAM Migration',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    color: deepPurple,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _balanceRow(
            label: 'FAN Balance',
            value:
                '${fanBalance.toStringAsFixed(4)} FAN',
          ),

          const SizedBox(height: 8),

          _balanceRow(
            label: 'AFAM Balance',
            value:
                '${afamBalance.toStringAsFixed(4)} AFAM',
          ),

          const SizedBox(height: 8),

          _balanceRow(
            label: 'Conversion',
            value:
                '${conversion.toStringAsFixed(0)} FAN = 1 AFAM',
          ),

          const SizedBox(height: 14),

          _statusBox(
            icon:
                Icons.schedule_rounded,
            title: 'COMING SOON',
            message:
                'AFAM migration is not open yet. Your FAN balance remains safe.',
            color: orangeColor,
          ),
        ],
      ),
    );
  }

  Widget _balanceRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: deepPurple,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY
  // ============================================================

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
                decoration:
                    BoxDecoration(
                  color:
                      primaryColor.withValues(
                    alpha: 0.08,
                  ),
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
                  fontWeight:
                      FontWeight.w800,
                  color: deepPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            'KYC progress is controlled by the secure backend. Daily check-ins, boosts, identity verification, and migration status are protected by server-side checks.',
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsets padding =
        const EdgeInsets.all(17),
  }) {
    return Container(
      padding: padding,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
