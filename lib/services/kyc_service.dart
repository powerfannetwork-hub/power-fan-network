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
          map['checkin_days'] ??
          map['consecutive_check_ins'],
    ).clamp(0, 30);

    final int boostDays = _toInt(
      map['kyc_boost_days'] ??
          map['boost_days'] ??
          map['consecutive_boost_days'],
    ).clamp(0, 30);

    final bool faceUnlockedFromServer = _toBool(
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

    /*
     * KYC requirements are the primary unlock condition.
     *
     * The server flag is still accepted for compatibility
     * with the existing database/RPC response.
     */
    final bool faceUnlocked =
        requirementsComplete ||
        faceUnlockedFromServer ||
        faceVerified;

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
      checkInDays: checkInDays,
      boostDays: boostDays,
      checkedInToday: _toBool(
        map['checked_in_today'] ??
            map['checkedInToday'],
      ),
      boostedToday: _toBool(
        map['boosted_today'] ??
            map['boostedToday'],
      ),
      faceVerificationUnlocked:
          faceUnlocked,
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

  bool get isVerified {
    return faceVerified;
  }

  double get checkInProgress {
    return (checkInDays / 30)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get boostProgress {
    return (boostDays / 30)
        .clamp(0.0, 1.0)
        .toDouble();
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
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  static bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

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
    final double rate =
        _toDouble(map['fan_per_afam']);

    return MigrationStatus(
      success: _toBool(
        map['success'],
      ),
      migrationOpen: _toBool(
        map['migration_open'],
      ),
      migrationAvailable: _toBool(
        map['migration_available'],
      ),
      faceVerified: _toBool(
        map['face_verified'] ??
            map['kyc_face_verified'],
      ),
      migrationCompleted: _toBool(
        map['migration_completed'],
      ),
      fanBalance: _toDouble(
        map['fan_balance'],
      ),
      afamBalance: _toDouble(
        map['afam_balance'],
      ),
      fanPerAfam:
          rate <= 0 ? 100 : rate,
      message:
          map['message']?.toString() ??
              'Migration is Coming Soon.',
    );
  }

  static bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

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

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString().trim(),
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

  /*
   * Expose the Supabase client only through this service.
   *
   * This is used by the KYC page to confirm that an
   * authenticated user exists before starting Didit.
   */
  SupabaseClient get client => _supabase;

  User? get currentUser =>
      _supabase.auth.currentUser;

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

      final Map<String, dynamic>? data =
          _mapFromResponse(response);

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
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not signed in.',
      );
    }

    final dynamic response =
        await _supabase.rpc(
      'claim_daily_checkin',
    );

    _validateActionResponse(
      response,
      actionName: 'Daily check-in',
    );

    return getProgress();
  }

  // ==========================================================
  // DAILY BOOST
  // ==========================================================

  Future<KycStatus>
      recordDailyBoost() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not signed in.',
      );
    }

    final dynamic response =
        await _supabase.rpc(
      'record_daily_boost',
    );

    _validateActionResponse(
      response,
      actionName: 'Daily boost',
    );

    return getProgress();
  }

  // ==========================================================
  // VALIDATE KYC RPC RESPONSE
  // ==========================================================

  void _validateActionResponse(
    dynamic response, {
    required String actionName,
  }) {
    if (response == null) {
      throw Exception(
        '$actionName failed: empty server response.',
      );
    }

    final Map<String, dynamic>? data =
        _mapFromResponse(response);

    if (data == null) {
      return;
    }

    final dynamic success =
        data['success'];

    if (success is bool &&
        !success) {
      final String message =
          data['message']?.toString() ??
              '$actionName failed.';

      throw Exception(message);
    }
  }

  // ==========================================================
  // RESPONSE → MAP
  // ==========================================================

  Map<String, dynamic>? _mapFromResponse(
    dynamic response,
  ) {
    if (response
        is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(
        response,
      );
    }

    if (response is List &&
        response.isNotEmpty) {
      final dynamic first =
          response.first;

      if (first
          is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(
          first,
        );
      }
    }

    return null;
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
        'Complete 30 days of Daily Check-in and 30 days of Daily Boost first.',
      );
    }

    if (status.faceVerified) {
      return null;
    }

    /*
     * This RPC records that the authenticated user
     * has entered the face-verification stage.
     *
     * IMPORTANT:
     *
     * It does NOT verify the user's identity.
     * The secure backend/Didit result must remain
     * the source of truth for KYC verification.
     */
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
      final Map<String, dynamic> map =
          Map<String, dynamic>.from(
        response,
      );

      final dynamic value =
          map['verification_id'] ??
              map['id'] ??
              map['session_id'];

      return value?.toString();
    }

    if (response is List &&
        response.isNotEmpty) {
      final dynamic first =
          response.first;

      if (first is String) {
        return first;
      }

      if (first is Map) {
        final Map<String, dynamic> map =
            Map<String, dynamic>.from(
          first,
        );

        final dynamic value =
            map['verification_id'] ??
                map['id'] ??
                map['session_id'];

        return value?.toString();
      }
    }

    return null;
  }

  // ==========================================================
  // FACE VERIFICATION STATUS
  // ==========================================================

  Future<bool>
      isFaceVerificationStarted() async {
    final status =
        await getProgress();

    return status.faceVerificationStarted;
  }

  // ==========================================================
  // FACE VERIFICATION COMPLETION
  // ==========================================================

  /*
   * IMPORTANT:
   *
   * The app must NOT use this method as a way to mark
   * a user as KYC verified after simply opening/completing
   * the camera screen.
   *
   * Didit verifies the session and the secure backend/
   * webhook should update the user's actual KYC status.
   *
   * This method remains for compatibility with existing
   * code. It does not automatically mark the user verified.
   */
  Future<KycStatus>
      completeFaceVerification({
    required String verificationId,
  }) async {
    if (verificationId.trim().isEmpty) {
      throw Exception(
        'Invalid verification session.',
      );
    }

    /*
     * Do not call complete_face_verification()
     * from the client as proof of identity.
     *
     * Refresh the backend status instead.
     */
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

    try {
      final dynamic response =
          await _supabase.rpc(
        'get_migration_status',
      );

      if (response == null) {
        return MigrationStatus.initial();
      }

      final Map<String, dynamic>? data =
          _mapFromResponse(response);

      if (data == null) {
        return MigrationStatus.initial();
      }

      return MigrationStatus.fromMap(
        data,
      );
    } on PostgrestException {
      rethrow;
    }
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

    if (response is List &&
        response.isNotEmpty &&
        response.first is Map) {
      return Map<String, dynamic>.from(
        response.first,
      );
    }

    throw Exception(
      'Invalid response from migrate_fan_to_afam.',
    );
  }

  // ==========================================================
  // KYC HELPERS
  // ==========================================================

  Future<bool>
      areRequirementsComplete() async {
    final KycStatus status =
        await getProgress();

    return status.requirementsComplete;
  }

  Future<bool> isVerified() async {
    final KycStatus status =
        await getProgress();

    return status.faceVerified;
  }

  Future<bool>
      checkedInToday() async {
    final KycStatus status =
        await getProgress();

    return status.checkedInToday;
  }

  Future<bool> boostedToday() async {
    final KycStatus status =
        await getProgress();

    return status.boostedToday;
  }

  Future<int> getCheckInDays() async {
    final KycStatus status =
        await getProgress();

    return status.checkInDays;
  }

  Future<int> getBoostDays() async {
    final KycStatus status =
        await getProgress();

    return status.boostDays;
  }
}
