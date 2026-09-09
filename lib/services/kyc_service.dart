import 'package:supabase_flutter/supabase_flutter.dart';

class KycStatus {
  final bool available;
  final bool comingSoon;
  final bool migrationAvailable;

  final int checkInDays;
  final int boostDays;

  final bool checkedInToday;
  final bool boostedToday;

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
      comingSoon: false,
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
    Map<String, dynamic> map,
  ) {
    final int checkInDays = _toInt(
      map['kyc_checkin_days'] ??
          map['checkin_days'],
    );

    final int boostDays = _toInt(
      map['kyc_boost_days'] ??
          map['boost_days'],
    );

    final bool faceUnlocked = _toBool(
      map['kyc_face_verification_unlocked'] ??
          map['face_verification_unlocked'] ??
          map['face_unlocked'],
    );

    final bool faceVerified = _toBool(
      map['kyc_face_verified'] ??
          map['face_verified'] ??
          map['verified'],
    );

    final bool faceStarted = _toBool(
      map['face_verification_started'] ??
          map['face_verification_started_at'] != null,
    );

    final bool requirementsComplete =
        checkInDays >= 30 &&
        boostDays >= 30;

    return KycStatus(
      available:
          requirementsComplete ||
          faceUnlocked ||
          faceVerified,
      comingSoon: _toBool(
        map['coming_soon'],
      ),
      migrationAvailable: _toBool(
        map['migration_available'] ??
            map['migrationAvailable'],
      ),
      checkInDays:
          checkInDays.clamp(0, 30),
      boostDays:
          boostDays.clamp(0, 30),
      checkedInToday: _toBool(
        map['checked_in_today'] ??
            map['checkedInToday'],
      ),
      boostedToday: _toBool(
        map['boosted_today'] ??
            map['boostedToday'],
      ),
      faceVerificationUnlocked:
          requirementsComplete ||
          faceUnlocked ||
          faceVerified,
      faceVerified: faceVerified,
      faceVerificationStarted:
          faceStarted,
    );
  }

  bool get requirementsComplete {
    return checkInDays >= 30 &&
        boostDays >= 30;
  }

  bool get canStartFaceVerification {
    return requirementsComplete &&
        faceVerificationUnlocked &&
        !faceVerified &&
        !faceVerificationStarted;
  }

  bool get isVerified => faceVerified;

  double get checkInProgress {
    return (checkInDays / 30)
        .clamp(0.0, 1.0);
  }

  double get boostProgress {
    return (boostDays / 30)
        .clamp(0.0, 1.0);
  }

  String get statusLabel {
    if (faceVerified) {
      return 'KYC VERIFIED';
    }

    if (requirementsComplete &&
        faceVerificationUnlocked) {
      return 'KYC READY';
    }

    return '30-Day KYC Requirement';
  }

  String get verificationMethod {
    return 'Live Face Verification';
  }

  KycStatus copyWith({
    bool? available,
    bool? comingSoon,
    bool? migrationAvailable,
    int? checkInDays,
    int? boostDays,
    bool? checkedInToday,
    bool? boostedToday,
    bool? faceVerificationUnlocked,
    bool? faceVerified,
    bool? faceVerificationStarted,
  }) {
    return KycStatus(
      available:
          available ?? this.available,
      comingSoon:
          comingSoon ?? this.comingSoon,
      migrationAvailable:
          migrationAvailable ??
              this.migrationAvailable,
      checkInDays:
          checkInDays ?? this.checkInDays,
      boostDays:
          boostDays ?? this.boostDays,
      checkedInToday:
          checkedInToday ??
              this.checkedInToday,
      boostedToday:
          boostedToday ??
              this.boostedToday,
      faceVerificationUnlocked:
          faceVerificationUnlocked ??
              this.faceVerificationUnlocked,
      faceVerified:
          faceVerified ?? this.faceVerified,
      faceVerificationStarted:
          faceVerificationStarted ??
              this.faceVerificationStarted,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String text =
        value.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'verified';
  }
}

// ============================================================
// MIGRATION STATUS
// ============================================================

class MigrationStatus {
  final bool success;
  final bool migrationOpen;
  final bool migrationAvailable;
  final bool faceVerified;
  final bool migrationCompleted;

  final double fanBalance;
  final double afamBalance;
  final double fanPerAfam;

  final String message;

  const MigrationStatus({
    required this.success,
    required this.migrationOpen,
    required this.migrationAvailable,
    required this.faceVerified,
    required this.migrationCompleted,
    required this.fanBalance,
    required this.afamBalance,
    required this.fanPerAfam,
    required this.message,
  });

  factory MigrationStatus.initial() {
    return const MigrationStatus(
      success: false,
      migrationOpen: false,
      migrationAvailable: false,
      faceVerified: false,
      migrationCompleted: false,
      fanBalance: 0,
      afamBalance: 0,
      fanPerAfam: 100,
      message: 'Migration is Coming Soon.',
    );
  }

  factory MigrationStatus.fromMap(
    Map<String, dynamic> map,
  ) {
    return MigrationStatus(
      success: _toBool(map['success']),
      migrationOpen:
          _toBool(map['migration_open']),
      migrationAvailable:
          _toBool(map['migration_available']),
      faceVerified:
          _toBool(map['face_verified']),
      migrationCompleted:
          _toBool(map['migration_completed']),
      fanBalance:
          _toDouble(map['fan_balance']),
      afamBalance:
          _toDouble(map['afam_balance']),
      fanPerAfam:
          _toDouble(
            map['fan_per_afam'],
          ) == 0
              ? 100
              : _toDouble(
                  map['fan_per_afam'],
                ),
      message:
          map['message']?.toString() ??
              'Migration is Coming Soon.',
    );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text =
        value?.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }
}

// ============================================================
// KYC SERVICE
// ============================================================

class KycService {
  KycService({
    SupabaseClient? client,
  }) : _supabase =
          client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ==========================================================
  // KYC PROGRESS
  // ==========================================================

  Future<KycStatus> getProgress() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return KycStatus.initial();
    }

    try {
      final dynamic response =
          await _supabase.rpc(
        'get_kyc_progress',
      );

      if (response == null) {
        return KycStatus.initial();
      }

      Map<String, dynamic>? data;

      if (response
          is Map<String, dynamic>) {
        data = response;
      } else if (response is List &&
          response.isNotEmpty) {
        final first = response.first;

        if (first
            is Map<String, dynamic>) {
          data = first;
        } else if (first is Map) {
          data =
              Map<String, dynamic>.from(
            first,
          );
        }
      } else if (response is Map) {
        data =
            Map<String, dynamic>.from(
          response,
        );
      }

      if (data == null) {
        return KycStatus.initial();
      }

      return KycStatus.fromMap(data);
    } on PostgrestException {
      rethrow;
    }
  }

  // ==========================================================
  // DAILY CHECK-IN
  // ==========================================================

  Future<KycStatus>
      claimDailyCheckIn() async {
    await _supabase.rpc(
      'claim_daily_checkin',
    );

    return getProgress();
  }

  // ==========================================================
  // DAILY BOOST
  // ==========================================================

  Future<KycStatus>
      recordDailyBoost() async {
    await _supabase.rpc(
      'record_daily_boost',
    );

    return getProgress();
  }

  // ==========================================================
  // START FACE VERIFICATION
  // ==========================================================

  Future<String?>
      startFaceVerification() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not signed in.',
      );
    }

    final status =
        await getProgress();

    if (!status.requirementsComplete) {
      throw Exception(
        'Complete 30 days of daily check-ins and 30 days of daily boosts first.',
      );
    }

    if (!status.faceVerificationUnlocked) {
      throw Exception(
        'Face verification is not unlocked yet.',
      );
    }

    if (status.faceVerified) {
      return null;
    }

    final dynamic response =
        await _supabase.rpc(
      'start_face_verification',
    );

    if (response == null) {
      return null;
    }

    if (response is String) {
      return response;
    }

    if (response is Map) {
      final map =
          Map<String, dynamic>.from(
        response,
      );

      final value =
          map['verification_id'] ??
              map['id'] ??
              map['session_id'];

      return value?.toString();
    }

    if (response is List &&
        response.isNotEmpty) {
      final first =
          response.first;

      if (first is String) {
        return first;
      }

      if (first is Map) {
        final map =
            Map<String, dynamic>.from(
          first,
        );

        final value =
            map['verification_id'] ??
                map['id'] ??
                map['session_id'];

        return value?.toString();
      }
    }

    return null;
  }

  // ==========================================================
  // COMPLETE FACE VERIFICATION
  // ==========================================================

  Future<KycStatus>
      completeFaceVerification({
    required String verificationId,
  }) async {
    if (verificationId.trim().isEmpty) {
      throw Exception(
        'Invalid verification session.',
      );
    }

    await _supabase.rpc(
      'complete_face_verification',
      params: {
        'p_verification_id':
            verificationId,
      },
    );

    return getProgress();
  }

  // ==========================================================
  // MIGRATION STATUS
  // ==========================================================

  Future<MigrationStatus>
      getMigrationStatus() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return MigrationStatus.initial();
    }

    final dynamic response =
        await _supabase.rpc(
      'get_migration_status',
    );

    if (response == null) {
      return MigrationStatus.initial();
    }

    Map<String, dynamic>? data;

    if (response
        is Map<String, dynamic>) {
      data = response;
    } else if (response is Map) {
      data =
          Map<String, dynamic>.from(
        response,
      );
    } else if (response is List &&
        response.isNotEmpty) {
      final first =
          response.first;

      if (first
          is Map<String, dynamic>) {
        data = first;
      } else if (first is Map) {
        data =
            Map<String, dynamic>.from(
          first,
        );
      }
    }

    if (data == null) {
      return MigrationStatus.initial();
    }

    return MigrationStatus.fromMap(
      data,
    );
  }

  // ==========================================================
  // FAN → AFAM
  // ==========================================================

  Future<Map<String, dynamic>>
      migrateFanToAfam() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Authentication required.',
      );
    }

    final dynamic response =
        await _supabase.rpc(
      'migrate_fan_to_afam',
    );

    if (response
        is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(
        response,
      );
    }

    throw Exception(
      'Invalid response from migrate_fan_to_afam.',
    );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  Future<bool>
      areRequirementsComplete() async {
    final status =
        await getProgress();

    return status.requirementsComplete;
  }

  Future<bool> isVerified() async {
    final status =
        await getProgress();

    return status.faceVerified;
  }

  Future<bool> checkedInToday() async {
    final status =
        await getProgress();

    return status.checkedInToday;
  }

  Future<bool> boostedToday() async {
    final status =
        await getProgress();

    return status.boostedToday;
  }

  Future<int> getCheckInDays() async {
    final status =
        await getProgress();

    return status.checkInDays;
  }

  Future<int> getBoostDays() async {
    final status =
        await getProgress();

    return status.boostDays;
  }
}
