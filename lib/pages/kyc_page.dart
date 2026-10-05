import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:didit_sdk_autodetection/sdk_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const Color orangeColor = Color(0xFFE88900);

  static const String _diditWorkflowId =
      'cf608b75-86b5-4d03-80ac-9ffc0371dde6';

  static const Duration _diditTimeout =
      Duration(seconds: 60);

  final KycService _kycService = KycService();

  KycStatus _status = KycStatus.initial();

  MigrationStatus _migrationStatus =
      MigrationStatus.initial();

  bool _loading = true;
  bool _checkingIn = false;
  bool _startingVerification = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _log(
      'KYC page initialized.',
    );

    _loadKyc();
  }

  // ============================================================
  // LOGGING
  // ============================================================

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
  // LOAD KYC
  // ============================================================

  Future<void> _loadKyc() async {
    if (!mounted) return;

    _log(
      'Loading KYC progress and migration status.',
    );

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

      final KycStatus kycStatus =
          results[0] as KycStatus;

      final MigrationStatus migrationStatus =
          results[1] as MigrationStatus;

      _log(
        'KYC loaded successfully. '
        'checkInDays=${kycStatus.checkInDays}, '
        'boostDays=${kycStatus.boostDays}, '
        'requirementsComplete=${kycStatus.requirementsComplete}, '
        'faceUnlocked=${kycStatus.faceVerificationUnlocked}, '
        'faceVerified=${kycStatus.faceVerified}',
      );

      setState(() {
        _status = kycStatus;
        _migrationStatus = migrationStatus;
        _loading = false;
      });
    } catch (error, stackTrace) {
      _log(
        'Failed to load KYC data.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      final String message =
          _cleanError(error);

      setState(() {
        _loading = false;
        _errorMessage = message;
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

    if (!mounted) return;

    _log(
      'Starting daily check-in.',
    );

    setState(() {
      _checkingIn = true;
      _errorMessage = null;
    });

    try {
      await _kycService.claimDailyCheckIn();

      _log(
        'Daily check-in RPC completed successfully.',
      );

      if (!mounted) return;

      setState(() {
        _checkingIn = false;
      });

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

      final String message =
          _cleanError(error);

      setState(() {
        _checkingIn = false;
        _errorMessage = message;
      });

      _showMessage(
        message,
        isError: true,
      );
    }
  }

  // ============================================================
  // DIDIT FACE VERIFICATION
  //
  // IMPORTANT:
  //
  // Didit is launched directly through the official Flutter SDK.
  //
  // No Android MethodChannel is used here.
  //
  // The workflow ID creates the verification flow.
  //
  // The authenticated Supabase user ID is passed as vendorData.
  //
  // A timeout is used so the UI cannot remain stuck forever on
  // "OPENING VERIFICATION...".
  // ============================================================

  Future<void> _startFaceVerification() async {
    if (_startingVerification) {
      _log(
        'Verification launch ignored because another launch '
        'is already in progress.',
      );
      return;
    }

    if (!_status.requirementsComplete) {
      _log(
        'Verification blocked because KYC requirements are incomplete. '
        'checkInDays=${_status.checkInDays}, '
        'boostDays=${_status.boostDays}',
      );

      _showMessage(
        'Complete 30 days of Daily Check-in and 30 days of Daily Boost first.',
        isError: true,
      );

      return;
    }

    if (_status.faceVerified) {
      _log(
        'Verification launch blocked because KYC is already verified.',
      );

      _showMessage(
        'Your KYC is already verified.',
      );

      return;
    }

    final User? user =
        _kycService.currentUser;

    if (user == null) {
      _log(
        'Verification launch failed because Supabase user session '
        'is unavailable.',
      );

      _showMessage(
        'User session is not available. Please login again.',
        isError: true,
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      _startingVerification = true;
      _errorMessage = null;
    });

    final String shortUserId =
        user.id.length > 8
            ? user.id.substring(0, 8)
            : user.id;

    _log(
      'Starting Didit verification. '
      'workflowId=$_diditWorkflowId, '
      'userIdPrefix=$shortUserId, '
      'timeout=${_diditTimeout.inSeconds}s',
    );

    try {
      _log(
        'Calling DiditSdk.startVerificationWithWorkflow().',
      );

      final VerificationResult result =
          await DiditSdk
              .startVerificationWithWorkflow(
                _diditWorkflowId,
                vendorData: user.id,
                config: const DiditConfig(
                  loggingEnabled: true,
                ),
              )
              .timeout(
                _diditTimeout,
                onTimeout: () {
                  throw TimeoutException(
                    'Didit verification did not return '
                    'within ${_diditTimeout.inSeconds} seconds.',
                  );
                },
              );

      _log(
        'Didit SDK returned a VerificationResult: '
        '${result.runtimeType}',
      );

      if (!mounted) return;

      switch (result) {
        // --------------------------------------------------------
        // COMPLETED
        // --------------------------------------------------------

        case VerificationCompleted(
            :final session,
          ):
          _log(
            'Didit VerificationCompleted received. '
            'sessionId=${session.sessionId}, '
            'status=${session.status}',
          );

          switch (session.status) {
            case VerificationStatus.approved:
              _log(
                'Didit verification status is APPROVED. '
                'Refreshing KYC status.',
              );

              _showMessage(
                'Verification completed successfully. '
                'Refreshing your KYC status...',
              );
              break;

            case VerificationStatus.pending:
              _log(
                'Didit verification status is PENDING.',
              );

              _showMessage(
                'Verification submitted. '
                'Your KYC status will update after secure confirmation.',
              );
              break;

            case VerificationStatus.declined:
              _log(
                'Didit verification status is DECLINED.',
              );

              _showMessage(
                'Verification was declined. Please try again.',
                isError: true,
              );
              break;
          }

          break;

        // --------------------------------------------------------
        // CANCELLED
        // --------------------------------------------------------

        case VerificationCancelled():
          _log(
            'User cancelled Didit verification.',
          );

          _showMessage(
            'KYC verification was cancelled.',
            isError: true,
          );

          break;

        // --------------------------------------------------------
        // FAILED
        // --------------------------------------------------------

        case VerificationFailed(
            :final error,
          ):
          final String diditError =
              _formatDiditError(error);

          _log(
            'Didit VerificationFailed received. '
            'type=${error.type}, '
            'message=${error.message}',
            error: error,
          );

          setState(() {
            _errorMessage =
                diditError;
          });

          _showMessage(
            diditError,
            isError: true,
          );

          break;
      }

      /*
       * IMPORTANT:
       *
       * Flutter does NOT directly mark the user as KYC verified.
       *
       * Didit/backend remains the source of truth.
       *
       * We only refresh the current KYC state after the Didit
       * verification flow returns.
       */

      _log(
        'Refreshing KYC state after Didit returned.',
      );

      await _loadKyc();
    } on TimeoutException catch (error, stackTrace) {
      _log(
        'DIDIT TIMEOUT: Didit did not return within '
        '${_diditTimeout.inSeconds} seconds.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      const String message =
          'Didit verification timed out. '
          'The verification screen did not respond within 60 seconds. '
          'Check your internet connection and try again.';

      setState(() {
        _errorMessage = message;
      });

      _showMessage(
        message,
        isError: true,
      );
    } catch (error, stackTrace) {
      _log(
        'Unexpected exception while starting Didit.',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      final String message =
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
          _startingVerification = false;
        });

        _log(
          'Didit verification launch state reset. '
          'Button is available again.',
        );
      }
    }
  }

  // ============================================================
  // DIDIT ERROR FORMAT
  // ============================================================

  String _formatDiditError(
    VerificationError error,
  ) {
    final String type =
        error.type.toString().contains('.')
            ? error.type
                .toString()
                .split('.')
                .last
            : error.type.toString();

    final String message =
        error.message.trim();

    _log(
      'Formatting Didit error. '
      'type=$type, message=$message',
    );

    switch (type) {
      case 'networkError':
        return 'Didit Network Error: '
            '${message.isEmpty ? 'Unable to connect to Didit.' : message} '
            'Please check your internet connection and try again.';

      case 'cameraAccessDenied':
        return 'Didit Camera Error: '
            'Camera permission was denied. '
            'Please allow camera permission for Power Fan Network '
            'in Android Settings and try again.';

      case 'notInitialized':
        return 'Didit SDK Error: '
            'The Didit SDK was not initialized correctly. '
            'Please restart the app and try again.';

      case 'apiError':
        return 'Didit API Error: '
            '${message.isEmpty ? 'Didit API request failed.' : message}';

      case 'sessionExpired':
        return 'Didit Session Expired: '
            '${message.isEmpty ? 'The verification session expired.' : message} '
            'Please start verification again.';

      case 'unknown':
        return 'Didit Error: '
            '${message.isEmpty ? 'An unknown verification error occurred.' : message}';

      default:
        return 'Didit Error [$type]: '
            '${message.isEmpty ? 'Verification could not be started.' : message}';
    }
  }

  // ============================================================
  // ERROR CLEANUP
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    var text =
        error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      text =
          text.substring(11);
    }

    if (text.startsWith(
      'PostgrestException: ',
    )) {
      text =
          text.substring(19);
    }

    final String cleaned =
        text.trim();

    if (cleaned.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    return cleaned;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

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
          duration: Duration(
            seconds: isError ? 6 : 4,
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
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
            fontWeight:
                FontWeight.w800,
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
                color:
                    primaryColor,
              ),
            )
          : RefreshIndicator(
              color:
                  primaryColor,
              onRefresh:
                  _loadKyc,
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

                  if (_errorMessage !=
                      null)
                    _buildErrorCard(),

                  if (_errorMessage !=
                      null)
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
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard() {
    final bool verified =
        _status.faceVerified;

    final bool ready =
        _status.requirementsComplete;

    String subtitle;

    if (verified) {
      subtitle =
          'Your KYC face verification has been completed.';
    } else if (ready) {
      subtitle =
          'Your 30-day requirements are complete. You can now verify your identity.';
    } else {
      subtitle =
          'Complete the required activities to unlock KYC verification.';
    }

    return Container(
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
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
                primaryColor
                    .withValues(
              alpha: 0.20,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              8,
            ),
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
                  Colors.white
                      .withValues(
                alpha: 0.15,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              verified
                  ? Icons
                      .verified_rounded
                  : ready
                      ? Icons
                          .lock_open_rounded
                      : Icons
                          .verified_user_rounded,
              color:
                  Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'POWER FAN KYC',
            style: TextStyle(
              color:
                  Colors.white,
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
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
                  Colors.white
                      .withValues(
                alpha: 0.90,
              ),
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          _buildHeaderStatus(
            verified:
                verified,
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white
                .withValues(
          alpha: 0.14,
        ),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color:
              Colors.white
                  .withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Text(
        label,
        style:
            const TextStyle(
          color:
              Colors.white,
          fontSize: 11,
          fontWeight:
              FontWeight.w800,
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
            Colors.red
                .withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              Colors.red
                  .withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color:
                  Colors.red
                      .withValues(
                alpha: 0.10,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: Icon(
              Icons
                  .error_outline_rounded,
              color:
                  Colors.red.shade700,
              size: 23,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'VERIFICATION ERROR',
                  style: TextStyle(
                    color:
                        Colors.red.shade800,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  _errorMessage ?? '',
                  style: TextStyle(
                    color:
                        Colors.red.shade800,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                TextButton(
                  onPressed: () {
                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _errorMessage =
                          null;
                    });
                  },
                  style:
                      TextButton.styleFrom(
                    padding:
                        EdgeInsets.zero,
                    minimumSize:
                        const Size(
                      0,
                      30,
                    ),
                    tapTargetSize:
                        MaterialTapTargetSize
                            .shrinkWrap,
                  ),
                  child:
                      const Text(
                    'DISMISS',
                    style:
                        TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          primaryColor,
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

  // ============================================================
  // REQUIREMENTS CARD
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
              fontWeight:
                  FontWeight.w800,
              color:
                  deepPurple,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Both requirements must reach 30 days.',
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          _buildProgressItem(
            icon:
                Icons.calendar_today_rounded,
            title:
                'Daily Check-in',
            current:
                _status.checkInDays,
            total: 30,
            progress:
                _status.checkInProgress,
            completed:
                _status.checkInDays >=
                    30,
            todayDone:
                _status.checkedInToday,
          ),

          const SizedBox(
            height: 22,
          ),

          _buildProgressItem(
            icon:
                Icons.bolt_rounded,
            title:
                'Daily Boost',
            current:
                _status.boostDays,
            total: 30,
            progress:
                _status.boostProgress,
            completed:
                _status.boostDays >=
                    30,
            todayDone:
                _status.boostedToday,
          ),

          const SizedBox(
            height: 20,
          ),

          _buildCheckInButton(),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS ITEM
  // ============================================================

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
                    ? greenColor
                        .withValues(
                        alpha: 0.10,
                      )
                    : primaryColor
                        .withValues(
                        alpha: 0.08,
                      ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
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

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    '$current / $total days',
                    style:
                        TextStyle(
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
                color:
                    greenColor,
              )
            else if (todayDone)
              const Icon(
                Icons
                    .check_circle_rounded,
                color:
                    greenColor,
              ),
          ],
        ),

        const SizedBox(
          height: 10,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            10,
          ),
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

        const SizedBox(
          height: 7,
        ),

        Text(
          completed
              ? 'Requirement completed'
              : todayDone
                  ? 'Today completed'
                  : 'Complete today to continue',
          style:
              TextStyle(
            fontSize: 12,
            color: completed
                ? greenColor
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CHECK-IN BUTTON
  // ============================================================

  Widget _buildCheckInButton() {
    if (_status.checkedInToday) {
      return Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 14,
        ),
        decoration:
            BoxDecoration(
          color:
              greenColor
                  .withValues(
            alpha: 0.08,
          ),
          borderRadius:
              BorderRadius.circular(
            13,
          ),
        ),
        child:
            const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .check_circle_rounded,
              color:
                  greenColor,
              size: 20,
            ),
            SizedBox(
              width: 8,
            ),
            Text(
              'TODAY CHECK-IN COMPLETED',
              style: TextStyle(
                color:
                    greenColor,
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
      width:
          double.infinity,
      height: 50,
      child:
          ElevatedButton.icon(
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
                BorderRadius.circular(
              13,
            ),
          ),
        ),
        icon: _checkingIn
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      Colors.white,
                ),
              )
            : const Icon(
                Icons
                    .event_available_rounded,
              ),
        label: Text(
          _checkingIn
              ? 'CHECKING IN...'
              : 'DAILY CHECK-IN',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FACE VERIFICATION CARD
  // ============================================================

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
                decoration:
                    BoxDecoration(
                  color: verified
                      ? greenColor
                          .withValues(
                          alpha: 0.10,
                        )
                      : primaryColor
                          .withValues(
                          alpha: 0.08,
                        ),
                  shape:
                      BoxShape.circle,
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

              const SizedBox(
                width: 14,
              ),

              const Expanded(
                child: Text(
                  'Face Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        deepPurple,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            verified
                ? 'Your identity has been verified.'
                : ready
                    ? 'Your KYC requirements are complete. You can now start real identity verification.'
                    : 'Face verification unlocks after completing 30 days of Daily Check-in and 30 days of Daily Boost.',
            style:
                TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
                  Colors.grey.shade700,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          if (verified)
            _statusBox(
              icon:
                  Icons.check_circle_rounded,
              title:
                  'KYC VERIFIED',
              message:
                  'Face verification completed successfully.',
              color:
                  greenColor,
            )
          else if (ready)
            _buildReadyVerificationBox()
          else
            _statusBox(
              icon:
                  Icons.lock_outline_rounded,
              title:
                  'KYC LOCKED',
              message:
                  'Complete both 30-day requirements first.',
              color:
                  Colors.grey.shade700,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // READY VERIFICATION BOX
  // ============================================================

  Widget _buildReadyVerificationBox() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        color:
            primaryColor
                .withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color:
              primaryColor
                  .withValues(
            alpha: 0.13,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons
                    .verified_user_rounded,
                color:
                    primaryColor,
                size: 23,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KYC READY',
                      style:
                          TextStyle(
                        color:
                            primaryColor,
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Your requirements are complete. Start the secure identity verification now.',
                      style:
                          TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 50,
            child:
                ElevatedButton.icon(
              onPressed:
                  _startingVerification
                      ? null
                      : _startFaceVerification,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryColor,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    primaryColor
                        .withValues(
                  alpha: 0.45,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              icon: _startingVerification
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons
                          .camera_alt_rounded,
                    ),
              label: Text(
                _startingVerification
                    ? 'OPENING VERIFICATION...'
                    : 'START FACE VERIFICATION',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          Text(
            'Camera and identity checks will be handled securely by the verification provider.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 10.5,
            ),
          ),
        ],
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
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              color.withValues(
            alpha: 0.12,
          ),
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

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      TextStyle(
                    color: color,
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  message,
                  style:
                      TextStyle(
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
  // MIGRATION CARD
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
                      orangeColor
                          .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons
                      .swap_horiz_rounded,
                  color:
                      orangeColor,
                  size: 25,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Expanded(
                child: Text(
                  'AFAM Migration',
                  style:
                      TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        deepPurple,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          _balanceRow(
            label:
                'FAN Balance',
            value:
                '${fanBalance.toStringAsFixed(4)} FAN',
          ),

          const SizedBox(
            height: 8,
          ),

          _balanceRow(
            label:
                'AFAM Balance',
            value:
                '${afamBalance.toStringAsFixed(4)} AFAM',
          ),

          const SizedBox(
            height: 8,
          ),

          _balanceRow(
            label:
                'Conversion',
            value:
                '${conversion.toStringAsFixed(0)} FAN = 1 AFAM',
          ),

          const SizedBox(
            height: 14,
          ),

          _statusBox(
            icon:
                Icons.schedule_rounded,
            title:
                'COMING SOON',
            message:
                'AFAM migration is not open yet. Your FAN balance remains safe. Migration will be enabled separately when the migration phase opens.',
            color:
                orangeColor,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BALANCE ROW
  // ============================================================

  Widget _balanceRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style:
              const TextStyle(
            color:
                deepPurple,
            fontSize: 13,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECURITY CARD
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
                      primaryColor
                          .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color:
                      primaryColor,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              const Text(
                'KYC Security',
                style:
                    TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      deepPurple,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Text(
            'KYC progress is controlled by the secure backend. '
            'Daily check-ins, boosts, identity verification, '
            'and migration status are protected by server-side checks.',
            style:
                TextStyle(
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
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
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
