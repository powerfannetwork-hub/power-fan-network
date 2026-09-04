import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

class KycStatus {
  final bool available;
  final bool comingSoon;
  final bool migrationAvailable;

  // 30-day requirements
  final int checkInDays;
  final int boostDays;
  final bool checkedInToday;
  final bool boostedToday;

  // Face verification
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

  factory KycStatus.fromMap(
    Map<String, dynamic> data,
  ) {
    final faceUnlocked =
        _toBool(data['face_verification_unlocked']) ||
        _toBool(data['available']);

    final verified =
        _toBool(data['face_verified']) ||
        _toBool(data['verified']);

    final checkInDays =
        _toInt(data['checkin_days']);

    final boostDays =
        _toInt(data['boost_days']);

    final migrationAvailable =
        _toBool(data['migration_available']);

    return KycStatus(
      available: faceUnlocked,
      comingSoon: !faceUnlocked && !verified,
      migrationAvailable: migrationAvailable,
      checkInDays: checkInDays.clamp(0, 30),
      boostDays: boostDays.clamp(0, 30),
      checkedInToday:
          _toBool(data['checked_in_today']),
      boostedToday:
          _toBool(data['boosted_today']),
      faceVerificationUnlocked:
          faceUnlocked,
      faceVerified:
          verified,
      faceVerificationStarted:
          _toBool(data['face_verification_started']),
    );
  }

  // ----------------------------------------------------------
  // 30-DAY REQUIREMENTS
  // ----------------------------------------------------------

  bool get checkInRequirementComplete =>
      checkInDays >= 30;

  bool get boostRequirementComplete =>
      boostDays >= 30;

  bool get requirementsComplete =>
      checkInRequirementComplete &&
      boostRequirementComplete;

  int get remainingCheckInDays =>
      (30 - checkInDays).clamp(0, 30);

  int get remainingBoostDays =>
      (30 - boostDays).clamp(0, 30);

  // ----------------------------------------------------------
  // FACE KYC
  // ----------------------------------------------------------

  bool get canStartFaceVerification =>
      faceVerificationUnlocked &&
      !faceVerified;

  // ----------------------------------------------------------
  // LEGACY COMPATIBILITY
  // ----------------------------------------------------------

  bool get canStartKyc1 => false;

  bool get canCompleteKyc1 => false;

  bool get canStartKyc2 => false;

  bool get kyc1Verified => false;

  bool get kyc2Verified => false;

  bool get kyc2Eligible => false;

  // Old code may still use this.
  bool get faceVerifiedStatus => faceVerified;

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value?.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 't';
  }
}

class KycService {
  KycService({
    SupabaseClient? client,
  }) : _supabase =
            client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ==========================================================
  // GET KYC STATUS
  // ==========================================================

  Future<KycStatus> getStatus() async {
    await _requireUser();

    try {
      final response = await _supabase.rpc(
        'get_kyc_progress',
      );

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

  // ==========================================================
  // DAILY CHECK-IN
  // ==========================================================

  Future<Map<String, dynamic>>
      claimDailyCheckIn() async {
    await _requireUser();

    try {
      final response = await _supabase.rpc(
        'claim_daily_checkin',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
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

  // ==========================================================
  // DAILY BOOST
  // ==========================================================

  Future<Map<String, dynamic>>
      recordDailyBoost() async {
    await _requireUser();

    try {
      final response = await _supabase.rpc(
        'record_daily_boost',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
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

  // ==========================================================
  // 30-DAY PROGRESS
  // ==========================================================

  Future<Map<String, dynamic>>
      getKycProgress() async {
    await _requireUser();

    try {
      final response = await _supabase.rpc(
        'get_kyc_progress',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
      }

      return <String, dynamic>{
        'success': false,
        'checkin_days': 0,
        'boost_days': 0,
        'required_days': 30,
        'checked_in_today': false,
        'boosted_today': false,
        'face_verification_unlocked': false,
        'face_verified': false,
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  // ==========================================================
  // START LIVE FACE VERIFICATION
  // ==========================================================

  Future<Map<String, dynamic>>
      startFaceVerification() async {
    await _requireUser();

    try {
      final response =
          await _supabase.rpc(
        'start_face_verification',
      );

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
      }

      return <String, dynamic>{
        'success': false,
        'available': false,
        'message':
            'Face verification is not available.',
      };
    } catch (error) {
      throw AuthException(
        _cleanError(error),
      );
    }
  }

  // ==========================================================
  // OLD KYC METHODS
  // ==========================================================
  // Kept only so existing UI/code does not break.
  // KYC1 and KYC2 are NO LONGER used.

  Future<Map<String, dynamic>>
      startKyc1() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'KYC1 is no longer used. Complete the 30-day requirements first.',
    };
  }

  Future<Map<String, dynamic>>
      completeKyc1() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'KYC1 is no longer used.',
    };
  }

  Future<bool> isKyc2Eligible() async {
    await _requireUser();

    return false;
  }

  Future<Map<String, dynamic>>
      startKyc2() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'KYC2 is no longer used.',
    };
  }

  Future<Map<String, dynamic>>
      completeKyc2() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'message':
          'KYC2 is no longer used.',
    };
  }

  // ==========================================================
  // MIGRATION
  // ==========================================================

  Future<Map<String, dynamic>>
      getMigrationStatus() async {
    await _requireUser();

    return <String, dynamic>{
      'available': false,
      'status': AppConfig.migrationStatus,
      'period': AppConfig.migrationPeriod,
      'message':
          'Migration is coming soon.',
    };
  }

  // ==========================================================
  // LEGACY SUMMARY
  // ==========================================================

  Future<Map<String, dynamic>>
      getKycSummary() async {
    final status = await getStatus();

    return <String, dynamic>{
      'available': status.available,
      'coming_soon': status.comingSoon,

      'checkin_days':
          status.checkInDays,

      'boost_days':
          status.boostDays,

      'required_days': 30,

      'checked_in_today':
          status.checkedInToday,

      'boosted_today':
          status.boostedToday,

      'face_verification_unlocked':
          status.faceVerificationUnlocked,

      'face_verified':
          status.faceVerified,

      'requirements_complete':
          status.requirementsComplete,

      'status':
          status.faceVerified
              ? 'VERIFIED'
              : status.faceVerificationUnlocked
                  ? 'FACE_VERIFICATION_AVAILABLE'
                  : 'LOCKED',
    };
  }

  Future<bool> isKycAvailable() async {
    final status = await getStatus();

    return status.faceVerificationUnlocked;
  }

  // ==========================================================
  // LABELS
  // ==========================================================

  String get statusLabel {
    return '30-Day KYC Requirement';
  }

  String get verificationMethod {
    return 'Live Face Verification';
  }

  // ==========================================================
  // AUTH
  // ==========================================================

  Future<User> _requireUser() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'User is not signed in.',
      );
    }

    return user;
  }

  // ==========================================================
  // ERROR CLEANUP
  // ==========================================================

  String _cleanError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }

    return text;
  }
}
