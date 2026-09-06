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

  factory KycStatus.fromMap(Map<String, dynamic> map) {
    final int checkInDays =
        _toInt(map['kyc_checkin_days'] ?? map['checkin_days']);

    final int boostDays =
        _toInt(map['kyc_boost_days'] ?? map['boost_days']);

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
        checkInDays >= 30 && boostDays >= 30;

    return KycStatus(
      available: requirementsComplete || faceUnlocked || faceVerified,
      comingSoon: _toBool(map['coming_soon']),
      migrationAvailable: _toBool(
        map['migration_available'] ?? map['migrationAvailable'],
      ),
      checkInDays: checkInDays.clamp(0, 30),
      boostDays: boostDays.clamp(0, 30),
      checkedInToday: _toBool(
        map['checked_in_today'] ?? map['checkedInToday'],
      ),
      boostedToday: _toBool(
        map['boosted_today'] ?? map['boostedToday'],
      ),
      faceVerificationUnlocked:
          requirementsComplete || faceUnlocked || faceVerified,
      faceVerified: faceVerified,
      faceVerificationStarted: faceStarted,
    );
  }

  bool get requirementsComplete {
    return checkInDays >= 30 && boostDays >= 30;
  }

  bool get canStartFaceVerification {
    return requirementsComplete &&
        faceVerificationUnlocked &&
        !faceVerified &&
        !faceVerificationStarted;
  }

  bool get isVerified => faceVerified;

  double get checkInProgress {
    return (checkInDays / 30).clamp(0.0, 1.0);
  }

  double get boostProgress {
    return (boostDays / 30).clamp(0.0, 1.0);
  }

  String get statusLabel {
    if (faceVerified) {
      return 'KYC VERIFIED';
    }

    if (requirementsComplete && faceVerificationUnlocked) {
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
      available: available ?? this.available,
      comingSoon: comingSoon ?? this.comingSoon,
      migrationAvailable:
          migrationAvailable ?? this.migrationAvailable,
      checkInDays: checkInDays ?? this.checkInDays,
      boostDays: boostDays ?? this.boostDays,
      checkedInToday: checkedInToday ?? this.checkedInToday,
      boostedToday: boostedToday ?? this.boostedToday,
      faceVerificationUnlocked:
          faceVerificationUnlocked ?? this.faceVerificationUnlocked,
      faceVerified: faceVerified ?? this.faceVerified,
      faceVerificationStarted:
          faceVerificationStarted ?? this.faceVerificationStarted,
    );
  }

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
        text == 'yes' ||
        text == 'verified';
  }
}

class KycService {
  KycService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Gets the current KYC progress for the signed-in user.
  ///
  /// Server is the source of truth.
  Future<KycStatus> getProgress() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return KycStatus.initial();
    }

    try {
      final dynamic response =
          await _supabase.rpc('get_kyc_progress');

      if (response == null) {
        return KycStatus.initial();
      }

      Map<String, dynamic>? data;

      if (response is Map<String, dynamic>) {
        data = response;
      } else if (response is List && response.isNotEmpty) {
        final first = response.first;

        if (first is Map<String, dynamic>) {
          data = first;
        } else if (first is Map) {
          data = Map<String, dynamic>.from(first);
        }
      } else if (response is Map) {
        data = Map<String, dynamic>.from(response);
      }

      if (data == null) {
        return KycStatus.initial();
      }

      return KycStatus.fromMap(data);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Claims today's daily check-in.
  ///
  /// The database prevents double claims for the same day.
  Future<KycStatus> claimDailyCheckIn() async {
    await _supabase.rpc('claim_daily_checkin');

    return getProgress();
  }

  /// Records today's KYC boost.
  ///
  /// The database prevents duplicate boost-day records.
  Future<KycStatus> recordDailyBoost() async {
    await _supabase.rpc('record_daily_boost');

    return getProgress();
  }

  /// Starts the server-side face verification session.
  ///
  /// IMPORTANT:
  /// This does NOT itself verify the user's identity.
  /// The real biometric/KYC provider will be integrated later.
  Future<String?> startFaceVerification() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not signed in.');
    }

    final status = await getProgress();

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
        await _supabase.rpc('start_face_verification');

    if (response == null) {
      return null;
    }

    if (response is String) {
      return response;
    }

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);

      final value = map['id'] ??
          map['session_id'] ??
          map['verification_id'];

      return value?.toString();
    }

    if (response is List && response.isNotEmpty) {
      final first = response.first;

      if (first is String) {
        return first;
      }

      if (first is Map) {
        final map = Map<String, dynamic>.from(first);

        final value = map['id'] ??
            map['session_id'] ??
            map['verification_id'];

        return value?.toString();
      }
    }

    return null;
  }

  /// Completes the server-side verification session.
  ///
  /// This function should only be called after a real biometric/KYC
  /// provider confirms the user's identity.
  ///
  /// Until that provider is integrated, the app must NOT pretend that
  /// opening the camera alone means the user is verified.
  Future<KycStatus> completeFaceVerification({
    required String verificationId,
  }) async {
    if (verificationId.trim().isEmpty) {
      throw Exception('Invalid verification session.');
    }

    await _supabase.rpc(
      'complete_face_verification',
      params: {
        'p_verification_id': verificationId,
      },
    );

    return getProgress();
  }

  /// Convenience method for checking whether the user has completed
  /// the 30-day requirements.
  Future<bool> areRequirementsComplete() async {
    final status = await getProgress();
    return status.requirementsComplete;
  }

  /// Convenience method for checking whether face verification
  /// has already been completed.
  Future<bool> isVerified() async {
    final status = await getProgress();
    return status.faceVerified;
  }

  /// Returns today's check-in state.
  Future<bool> checkedInToday() async {
    final status = await getProgress();
    return status.checkedInToday;
  }

  /// Returns today's boost state.
  Future<bool> boostedToday() async {
    final status = await getProgress();
    return status.boostedToday;
  }

  /// Returns the number of completed check-in days.
  Future<int> getCheckInDays() async {
    final status = await getProgress();
    return status.checkInDays;
  }

  /// Returns the number of completed boost days.
  Future<int> getBoostDays() async {
    final status = await getProgress();
    return status.boostDays;
  }
}
