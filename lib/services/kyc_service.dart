import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

/// ===============================================================
/// POWER FAN NETWORK
/// KYC STATUS MODEL
/// ===============================================================

class KycStatus {
  final bool available;
  final bool comingSoon;
  final bool migrationAvailable;

  /// 30-day requirements
  final int checkInDays;
  final int boostDays;

  final bool checkedInToday;
  final bool boostedToday;

  /// Face verification
  final bool faceVerificationUnlocked;
  final bool faceVerified;
  final bool faceVerificationStarted;

  const KycStatus({
    required this.available,
    required this.comingSoon,
    required this.migrationAvailable,
    required this.checkInDays,
    required this.boostDays,
    required this.checkedInToday,
    required this.boostedToday,
    required this.faceVerificationUnlocked,
    required this.faceVerified,
    required this.faceVerificationStarted,
  });

  /// Default status
  factory KycStatus.initial() {
    return const KycStatus(
      available: false,
      comingSoon: true,
      migrationAvailable: false,
      checkInDays: 0,
      boostDays: 0,
      checkedInToday: false,
      boostedToday: false,
      faceVerificationUnlocked: false,
      faceVerified: false,
      faceVerificationStarted: false,
    );
  }

  /// Convert Supabase response to KycStatus
  factory KycStatus.fromMap(Map<String, dynamic> data) {
    final bool faceUnlocked =
        _toBool(data['face_verification_unlocked']) ||
        _toBool(data['available']);

    final bool verified =
        _toBool(data['face_verified']) ||
        _toBool(data['verified']);

    final int checkInDays = _toInt(data['checkin_days']);
    final int boostDays = _toInt(data['boost_days']);

    final bool migrationAvailable =
        _toBool(data['migration_available']);

    return KycStatus(
      available: faceUnlocked || verified,
      comingSoon: !faceUnlocked && !verified,
      migrationAvailable: migrationAvailable,

      checkInDays: checkInDays.clamp(0, 30),
      boostDays: boostDays.clamp(0, 30),

      checkedInToday: _toBool(data['checked_in_today']),
      boostedToday: _toBool(data['boosted_today']),

      faceVerificationUnlocked: faceUnlocked,
      faceVerified: verified,

      faceVerificationStarted:
          _toBool(data['face_verification_started']),
    );
  }

  /// =============================================================
  /// 30-DAY REQUIREMENTS
  /// =============================================================

  bool get checkInRequirementComplete {
    return checkInDays >= 30;
  }

  bool get boostRequirementComplete {
    return boostDays >= 30;
  }

  bool get requirementsComplete {
    return checkInRequirementComplete &&
        boostRequirementComplete;
  }

  int get remainingCheckInDays {
    return (30 - checkInDays).clamp(0, 30);
  }

  int get remainingBoostDays {
    return (30 - boostDays).clamp(0, 30);
  }

  /// =============================================================
  /// FACE VERIFICATION
  /// =============================================================

  bool get canStartFaceVerification {
    return faceVerificationUnlocked && !faceVerified;
  }

  bool get faceVerifiedStatus {
    return faceVerified;
  }

  /// Old KYC compatibility getters.
  /// These remain so older UI code will not break.
  bool get canStartKyc1 => false;

  bool get canCompleteKyc1 => false;

  bool get canStartKyc2 => false;

  bool get kyc1Verified => false;

  bool get kyc2Verified => false;

  bool get kyc2Eligible => false;

  /// =============================================================
  /// HELPERS
  /// =============================================================

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    final String text = value.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }
}

/// ===============================================================
/// POWER FAN NETWORK
/// KYC SERVICE
/// ===============================================================

class KycService {
  KycService({
    SupabaseClient? client,
  }) : _supabase =
            client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// =============================================================
  /// CURRENT USER CHECK
  /// =============================================================

  Future<void> _requireUser() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be logged in to use KYC.',
      );
    }
  }

  /// =============================================================
  /// GET KYC STATUS
  /// =============================================================

  Future<KycStatus> getStatus() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc('get_kyc_progress');

      if (response is Map) {
        return KycStatus.fromMap(
          Map<String, dynamic>.from(response),
        );
      }

      return KycStatus.initial();
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  /// =============================================================
  /// GET KYC PROGRESS
  /// =============================================================

  Future<Map<String, dynamic>> getKycProgress() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc('get_kyc_progress');

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return <String, dynamic>{
        'success': false,
        'message': 'Unable to load KYC progress.',
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  /// =============================================================
  /// DAILY CHECK-IN
  /// =============================================================

  Future<Map<String, dynamic>> claimDailyCheckIn() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc('claim_daily_checkin');

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return <String, dynamic>{
        'success': false,
        'message':
            'Unable to complete daily check-in.',
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  /// =============================================================
  /// RECORD DAILY BOOST
  ///
  /// One successful boost per day is enough
  /// to count that day toward the 30-day KYC requirement.
  /// =============================================================

  Future<Map<String, dynamic>> recordDailyBoost() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc('record_daily_boost');

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return <String, dynamic>{
        'success': false,
        'message':
            'Unable to record daily boost.',
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  /// =============================================================
  /// START LIVE FACE VERIFICATION
  ///
  /// The server starts the verification session.
  /// The required minimum duration is 30 seconds.
  /// =============================================================

  Future<Map<String, dynamic>>
      startFaceVerification() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc(
        'start_face_verification',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return <String, dynamic>{
        'success': false,
        'message':
            'Unable to start face verification.',
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  /// =============================================================
  /// COMPLETE 30-SECOND FACE VERIFICATION
  ///
  /// IMPORTANT:
  /// Supabase checks that at least 30 seconds have passed
  /// since the verification session started.
  /// =============================================================

  Future<Map<String, dynamic>>
      completeFaceVerification() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc(
        'complete_face_verification',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return <String, dynamic>{
        'success': false,
        'completed': false,
        'message':
            'Unable to complete face verification.',
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  /// =============================================================
  /// CHECK IF KYC IS AVAILABLE
  /// =============================================================

  Future<bool> isKycAvailable() async {
    final status = await getStatus();

    return status.faceVerificationUnlocked ||
        status.faceVerified;
  }

  /// =============================================================
  /// KYC SUMMARY
  /// =============================================================

  Future<Map<String, dynamic>>
      getKycSummary() async {
    final status = await getStatus();

    return <String, dynamic>{
      'available': status.available,
      'coming_soon': status.comingSoon,

      'checkin_days': status.checkInDays,
      'boost_days': status.boostDays,

      'checked_in_today':
          status.checkedInToday,

      'boosted_today':
          status.boostedToday,

      'checkin_complete':
          status.checkInRequirementComplete,

      'boost_complete':
          status.boostRequirementComplete,

      'requirements_complete':
          status.requirementsComplete,

      'remaining_checkin_days':
          status.remainingCheckInDays,

      'remaining_boost_days':
          status.remainingBoostDays,

      'face_verification_unlocked':
          status.faceVerificationUnlocked,

      'face_verification_started':
          status.faceVerificationStarted,

      'face_verified':
          status.faceVerified,

      'migration_available':
          status.migrationAvailable,
    };
  }

  /// =============================================================
  /// MIGRATION
  ///
  /// Still Coming Soon.
  /// =============================================================

  Future<Map<String, dynamic>>
      getMigrationStatus() async {
    await _requireUser();

    return <String, dynamic>{
      'available': false,
      'coming_soon': true,
      'message':
          'AFAM migration is coming soon.',
      'conversion':
          '100 FAN = 1 AFAM',
    };
  }

  /// =============================================================
  /// OLD KYC METHODS
  ///
  /// Kept for compatibility with any old UI code.
  /// The old KYC1/KYC2 system is no longer used.
  /// =============================================================

  Future<Map<String, dynamic>>
      startKyc1() async {
    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'The old KYC1 system is no longer used.',
    };
  }

  Future<Map<String, dynamic>>
      completeKyc1() async {
    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'The old KYC1 system is no longer used.',
    };
  }

  Future<Map<String, dynamic>>
      startKyc2() async {
    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'The old KYC2 system is no longer used.',
    };
  }

  Future<bool> isKyc2Eligible() async {
    return false;
  }

  /// =============================================================
  /// LABELS
  /// =============================================================

  String get statusLabel {
    return '30-Day KYC Requirement';
  }

  String get verificationMethod {
    return 'Live Face Verification';
  }

  String get migrationLabel {
    return AppConfig.comingSoon;
  }

  /// =============================================================
  /// ERROR CLEANUP
  /// =============================================================

  String _cleanError(Object error) {
    final String message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();

    if (message.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    final String lower =
        message.toLowerCase();

    if (lower.contains('jwt')) {
      return 'Your session has expired. Please login again.';
    }

    if (lower.contains('not authenticated') ||
        lower.contains('unauthorized')) {
      return 'You are not authenticated. Please login again.';
    }

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Network connection problem. Please check your internet and try again.';
    }

    return message;
  }
}
