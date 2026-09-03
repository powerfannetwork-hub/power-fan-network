import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

class KycStatus {
  final bool available;
  final bool comingSoon;
  final bool migrationAvailable;

  const KycStatus({
    required this.available,
    required this.comingSoon,
    required this.migrationAvailable,
  });

  factory KycStatus.comingSoon() {
    return const KycStatus(
      available: false,
      comingSoon: true,
      migrationAvailable: false,
    );
  }

  factory KycStatus.fromMap(
    Map<String, dynamic> data,
  ) {
    final available =
        _toBool(data['available']);

    final migrationAvailable =
        _toBool(
      data['migration_available'],
    );

    return KycStatus(
      available: available,
      comingSoon:
          !available &&
          !_toBool(data['verified']),
      migrationAvailable:
          migrationAvailable,
    );
  }

  bool get canStartKyc1 => false;

  bool get canCompleteKyc1 => false;

  bool get canStartKyc2 => false;

  bool get kyc1Verified => false;

  bool get kyc2Verified => false;

  bool get kyc2Eligible => false;

  bool get faceVerified => false;

  int get checkInDays => 0;

  int get activeReferrals => 0;

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value?.toString().toLowerCase();

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

  // ---------------------------------------------------------------------------
  // STATUS
  // ---------------------------------------------------------------------------

  Future<KycStatus> getStatus() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'User is not signed in.',
      );
    }

    /*
     * KYC is intentionally disabled for the
     * current version of POWER FAN NETWORK.
     *
     * We do NOT call old KYC RPCs here because
     * those RPCs are not part of the current
     * backend contract.
     */
    return KycStatus.comingSoon();
  }

  // ---------------------------------------------------------------------------
  // KYC 1
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> startKyc1() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'coming_soon': true,
      'message':
          'KYC is coming soon.',
    };
  }

  Future<Map<String, dynamic>> startFaceVerification() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'coming_soon': true,
      'message':
          'Face verification is coming soon.',
    };
  }

  Future<Map<String, dynamic>> completeKyc1() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'coming_soon': true,
      'message':
          'KYC verification is coming soon.',
    };
  }

  // ---------------------------------------------------------------------------
  // KYC 2
  // ---------------------------------------------------------------------------

  Future<bool> isKyc2Eligible() async {
    await _requireUser();

    return false;
  }

  Future<Map<String, dynamic>> startKyc2() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'coming_soon': true,
      'message':
          'KYC is coming soon.',
    };
  }

  Future<Map<String, dynamic>> completeKyc2() async {
    await _requireUser();

    return <String, dynamic>{
      'success': false,
      'available': false,
      'coming_soon': true,
      'message':
          'KYC verification is coming soon.',
    };
  }

  // ---------------------------------------------------------------------------
  // MIGRATION
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getMigrationStatus() async {
    await _requireUser();

    return <String, dynamic>{
      'available': false,
      'status': AppConfig.migrationStatus,
      'period': AppConfig.migrationPeriod,
      'message':
          'Migration is coming soon.',
    };
  }

  // ---------------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // LEGACY-COMPATIBILITY HELPERS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getKycSummary() async {
    await _requireUser();

    return <String, dynamic>{
      'available': false,
      'coming_soon': true,
      'status': AppConfig.comingSoon,
    };
  }

  Future<bool> isKycAvailable() async {
    await _requireUser();

    return false;
  }

  String get statusLabel =>
      AppConfig.comingSoon;

  String get verificationMethod =>
      AppConfig.faceVerificationLabel;
}
