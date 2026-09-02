import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

class KycStatus {
  final int checkInDays;
  final int activeReferrals;
  final bool faceVerified;
  final bool kyc1Verified;
  final bool kyc2Eligible;
  final bool kyc2Verified;
  final bool migrationAvailable;

  const KycStatus({
    required this.checkInDays,
    required this.activeReferrals,
    required this.faceVerified,
    required this.kyc1Verified,
    required this.kyc2Eligible,
    required this.kyc2Verified,
    required this.migrationAvailable,
  });

  factory KycStatus.fromMap(Map<String, dynamic> data) {
    return KycStatus(
      checkInDays: _toInt(data['check_in_days']),
      activeReferrals: _toInt(data['active_referrals']),
      faceVerified: _toBool(data['face_verified']),
      kyc1Verified: _toBool(data['kyc1_verified']),
      kyc2Eligible: _toBool(data['kyc2_eligible']),
      kyc2Verified: _toBool(data['kyc2_verified']),
      migrationAvailable: _toBool(data['migration_available']),
    );
  }

  bool get canStartKyc1 {
    return !kyc1Verified &&
        checkInDays >= AppConfig.kyc1Days;
  }

  bool get canCompleteKyc1 {
    return !kyc1Verified &&
        checkInDays >= AppConfig.kyc1Days &&
        faceVerified;
  }

  bool get canStartKyc2 {
    return kyc1Verified &&
        !kyc2Verified &&
        checkInDays >= AppConfig.kyc2Days &&
        activeReferrals >= AppConfig.kyc2Referrals;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}

class KycService {
  KycService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Gets the current KYC/eligibility information for the signed-in user.
  ///
  /// The server remains authoritative for eligibility.
  Future<KycStatus> getStatus() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not signed in.');
    }

    try {
      final response = await _supabase.rpc(
        AppConfig.rpcGetKycStatus,
      );

      if (response is Map<String, dynamic>) {
        return KycStatus.fromMap(response);
      }

      if (response is List && response.isNotEmpty) {
        final first = response.first;

        if (first is Map) {
          return KycStatus.fromMap(
            Map<String, dynamic>.from(first),
          );
        }
      }

      return await _getStatusFromProfile();
    } on PostgrestException {
      return await _getStatusFromProfile();
    }
  }

  /// Starts the KYC 1 face-verification process.
  ///
  /// Face verification itself must be performed by a trusted
  /// verification provider/backend. The mobile app must not simply
  /// mark the user as verified.
  Future<Map<String, dynamic>> startKyc1() async {
    final status = await getStatus();

    if (status.kyc1Verified) {
      return {
        'success': true,
        'already_verified': true,
        'message': 'KYC 1 is already verified.',
      };
    }

    if (status.checkInDays < AppConfig.kyc1Days) {
      return {
        'success': false,
        'eligible': false,
        'required_days': AppConfig.kyc1Days,
        'current_days': status.checkInDays,
        'message':
            'Complete ${AppConfig.kyc1Days} consecutive daily check-ins first.',
      };
    }

    try {
      final response = await _supabase.rpc(
        AppConfig.rpcStartKyc1,
      );

      return _mapResponse(
        response,
        fallbackMessage: 'KYC 1 is ready for face verification.',
      );
    } on PostgrestException catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Requests/starts face verification.
  ///
  /// This does NOT directly change face_verified.
  /// A trusted verification process must confirm the result.
  Future<Map<String, dynamic>> startFaceVerification() async {
    final status = await getStatus();

    if (status.kyc1Verified) {
      return {
        'success': true,
        'already_verified': true,
        'message': 'KYC 1 is already verified.',
      };
    }

    if (status.checkInDays < AppConfig.kyc1Days) {
      return {
        'success': false,
        'eligible': false,
        'required_days': AppConfig.kyc1Days,
        'current_days': status.checkInDays,
        'message':
            'Complete ${AppConfig.kyc1Days} consecutive daily check-ins first.',
      };
    }

    try {
      final response = await _supabase.rpc(
        AppConfig.rpcStartFaceVerification,
      );

      return _mapResponse(
        response,
        fallbackMessage: 'Face verification has been started.',
      );
    } on PostgrestException catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Completes KYC 1 after the trusted verification process has
  /// confirmed the user's face.
  ///
  /// The backend must verify that the face verification really passed.
  Future<Map<String, dynamic>> completeKyc1() async {
    final status = await getStatus();

    if (status.kyc1Verified) {
      return {
        'success': true,
        'already_verified': true,
        'message': 'KYC 1 is already verified.',
      };
    }

    if (status.checkInDays < AppConfig.kyc1Days) {
      return {
        'success': false,
        'eligible': false,
        'message':
            'KYC 1 requires ${AppConfig.kyc1Days} consecutive daily check-ins.',
      };
    }

    if (!status.faceVerified) {
      return {
        'success': false,
        'face_verified': false,
        'message': 'Face verification has not been completed yet.',
      };
    }

    try {
      final response = await _supabase.rpc(
        AppConfig.rpcCompleteKyc1,
      );

      return _mapResponse(
        response,
        fallbackMessage: 'KYC 1 verification completed.',
      );
    } on PostgrestException catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Checks whether KYC 2 requirements have been reached.
  ///
  /// KYC 2 requires:
  /// - KYC 1 completed
  /// - 60 consecutive daily check-ins
  /// - 5 active referrals
  Future<bool> isKyc2Eligible() async {
    final status = await getStatus();

    return status.kyc1Verified &&
        !status.kyc2Verified &&
        status.checkInDays >= AppConfig.kyc2Days &&
        status.activeReferrals >= AppConfig.kyc2Referrals;
  }

  /// Starts KYC 2 when the server confirms eligibility.
  Future<Map<String, dynamic>> startKyc2() async {
    final status = await getStatus();

    if (status.kyc2Verified) {
      return {
        'success': true,
        'already_verified': true,
        'message': 'KYC 2 is already verified.',
      };
    }

    if (!status.kyc1Verified) {
      return {
        'success': false,
        'eligible': false,
        'message': 'Complete KYC 1 first.',
      };
    }

    if (status.checkInDays < AppConfig.kyc2Days) {
      return {
        'success': false,
        'eligible': false,
        'required_days': AppConfig.kyc2Days,
        'current_days': status.checkInDays,
        'message':
            'KYC 2 requires ${AppConfig.kyc2Days} consecutive daily check-ins.',
      };
    }

    if (status.activeReferrals < AppConfig.kyc2Referrals) {
      return {
        'success': false,
        'eligible': false,
        'required_referrals': AppConfig.kyc2Referrals,
        'current_referrals': status.activeReferrals,
        'message':
            'KYC 2 requires ${AppConfig.kyc2Referrals} active referrals.',
      };
    }

    try {
      final response = await _supabase.rpc(
        AppConfig.rpcStartKyc2,
      );

      return _mapResponse(
        response,
        fallbackMessage: 'KYC 2 is now available.',
      );
    } on PostgrestException catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Completes KYC 2 after the trusted backend has confirmed it.
  Future<Map<String, dynamic>> completeKyc2() async {
    final status = await getStatus();

    if (status.kyc2Verified) {
      return {
        'success': true,
        'already_verified': true,
        'message': 'KYC 2 is already verified.',
      };
    }

    final eligible =
        status.kyc1Verified &&
        status.checkInDays >= AppConfig.kyc2Days &&
        status.activeReferrals >= AppConfig.kyc2Referrals;

    if (!eligible) {
      return {
        'success': false,
        'eligible': false,
        'message':
            'KYC 2 requirements have not been completed.',
      };
    }

    try {
      final response = await _supabase.rpc(
        AppConfig.rpcCompleteKyc2,
      );

      return _mapResponse(
        response,
        fallbackMessage: 'KYC 2 verification completed.',
      );
    } on PostgrestException catch (e) {
      throw _friendlyException(e);
    }
  }

  /// Migration remains unavailable until the official migration period.
  Future<Map<String, dynamic>> getMigrationStatus() async {
    final status = await getStatus();

    return {
      'available': status.migrationAvailable,
      'status': AppConfig.migrationStatus,
      'period': AppConfig.migrationPeriod,
    };
  }

  Future<KycStatus> _getStatusFromProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException('User is not signed in.');
    }

    final response = await _supabase
        .from('profiles')
        .select(
          'kyc1_verified, kyc2_verified, face_verified, '
          'active_referrals, consecutive_checkin_days',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return const KycStatus(
        checkInDays: 0,
        activeReferrals: 0,
        faceVerified: false,
        kyc1Verified: false,
        kyc2Eligible: false,
        kyc2Verified: false,
        migrationAvailable: false,
      );
    }

    final data = Map<String, dynamic>.from(response);

    final checkInDays = _toInt(
      data['consecutive_checkin_days'] ??
          data['check_in_days'] ??
          data['daily_checkin_days'],
    );

    final activeReferrals = _toInt(
      data['active_referrals'],
    );

    final kyc1Verified = _toBool(
      data['kyc1_verified'],
    );

    final kyc2Verified = _toBool(
      data['kyc2_verified'],
    );

    final faceVerified = _toBool(
      data['face_verified'],
    );

    final kyc2Eligible = kyc1Verified &&
        checkInDays >= AppConfig.kyc2Days &&
        activeReferrals >= AppConfig.kyc2Referrals;

    return KycStatus(
      checkInDays: checkInDays,
      activeReferrals: activeReferrals,
      faceVerified: faceVerified,
      kyc1Verified: kyc1Verified,
      kyc2Eligible: kyc2Eligible,
      kyc2Verified: kyc2Verified,
      migrationAvailable: false,
    );
  }

  Map<String, dynamic> _mapResponse(
    dynamic response, {
    required String fallbackMessage,
  }) {
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    if (response is List && response.isNotEmpty) {
      final first = response.first;

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    return {
      'success': true,
      'message': fallbackMessage,
    };
  }

  PostgrestException _friendlyException(PostgrestException error) {
    return PostgrestException(
      message: error.message,
      code: error.code,
      details: error.details,
      hint: error.hint,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }
}
