// lib/services/profile_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileData {
  final String id;
  final String name;
  final String username;
  final String email;
  final String referralCode;
  final String? referredBy;

  final double fanBalance;
  final double afamBalance;
  final double miningRate;

  final int activeReferrals;
  final int dailyAdsWatched;
  final double adBoost;

  final bool miningActive;
  final DateTime? miningStartedAt;
  final DateTime? miningEndsAt;

  final int consecutiveCheckIns;

  final int kycCheckinStreak;
  final int kycBoostStreak;
  final DateTime? kycLastCheckinDate;
  final DateTime? kycLastBoostDate;

  final bool kyc1Eligible;
  final bool kyc1Verified;
  final bool kyc2Eligible;
  final bool kyc2Verified;
  final bool kyc3Verified;

  final bool kycFaceVerificationUnlocked;
  final bool kycFaceVerified;
  final DateTime? faceVerificationStartedAt;

  final bool migrationAvailable;
  final bool migrationCompleted;
  final DateTime? migrationCompletedAt;

  final bool registrationNoticeAccepted;
  final DateTime? registrationNoticeAcceptedAt;

  final int deviceWarningCount;
  final DateTime? lastDeviceWarningAt;
  final DateTime? suspendedUntil;
  final String? suspensionReason;

  final DateTime? lastSocialClaimDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileData({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.referralCode,
    required this.referredBy,
    required this.fanBalance,
    required this.afamBalance,
    required this.miningRate,
    required this.activeReferrals,
    required this.dailyAdsWatched,
    required this.adBoost,
    required this.miningActive,
    required this.miningStartedAt,
    required this.miningEndsAt,
    required this.consecutiveCheckIns,
    required this.kycCheckinStreak,
    required this.kycBoostStreak,
    required this.kycLastCheckinDate,
    required this.kycLastBoostDate,
    required this.kyc1Eligible,
    required this.kyc1Verified,
    required this.kyc2Eligible,
    required this.kyc2Verified,
    required this.kyc3Verified,
    required this.kycFaceVerificationUnlocked,
    required this.kycFaceVerified,
    required this.faceVerificationStartedAt,
    required this.migrationAvailable,
    required this.migrationCompleted,
    required this.migrationCompletedAt,
    required this.registrationNoticeAccepted,
    required this.registrationNoticeAcceptedAt,
    required this.deviceWarningCount,
    required this.lastDeviceWarningAt,
    required this.suspendedUntil,
    required this.suspensionReason,
    required this.lastSocialClaimDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileData.fromMap(
    Map<String, dynamic> map,
  ) {
    return ProfileData(
      id: _stringValue(map['id']),
      name: _stringValue(map['name']),
      username: _stringValue(map['username']),
      email: _stringValue(map['email']),
      referralCode: _stringValue(
        map['referral_code'],
      ),
      referredBy: _nullableString(
        map['referred_by'],
      ),
      fanBalance: _doubleValue(
        map['fan_balance'],
      ),
      afamBalance: _doubleValue(
        map['afam_balance'],
      ),
      miningRate: _doubleValue(
        map['mining_rate'],
      ),
      activeReferrals: _intValue(
        map['active_referrals'],
      ),
      dailyAdsWatched: _intValue(
        map['daily_ads_watched'],
      ),
      adBoost: _doubleValue(
        map['ad_boost'],
      ),
      miningActive: _boolValue(
        map['mining_active'],
      ),
      miningStartedAt: _dateTimeValue(
        map['mining_started_at'],
      ),
      miningEndsAt: _dateTimeValue(
        map['mining_ends_at'],
      ),
      consecutiveCheckIns: _intValue(
        map['consecutive_check_ins'],
      ),
      kycCheckinStreak: _intValue(
        map['kyc_checkin_streak'],
      ),
      kycBoostStreak: _intValue(
        map['kyc_boost_streak'],
      ),
      kycLastCheckinDate: _dateTimeValue(
        map['kyc_last_checkin_date'],
      ),
      kycLastBoostDate: _dateTimeValue(
        map['kyc_last_boost_date'],
      ),
      kyc1Eligible: _boolValue(
        map['kyc1_eligible'],
      ),
      kyc1Verified: _boolValue(
        map['kyc1_verified'],
      ),
      kyc2Eligible: _boolValue(
        map['kyc2_eligible'],
      ),
      kyc2Verified: _boolValue(
        map['kyc2_verified'],
      ),
      kyc3Verified: _boolValue(
        map['kyc3_verified'],
      ),
      kycFaceVerificationUnlocked: _boolValue(
        map['kyc_face_verification_unlocked'],
      ),
      kycFaceVerified: _boolValue(
        map['kyc_face_verified'],
      ),
      faceVerificationStartedAt: _dateTimeValue(
        map['face_verification_started_at'],
      ),
      migrationAvailable: _boolValue(
        map['migration_available'],
      ),
      migrationCompleted: _boolValue(
        map['migration_completed'],
      ),
      migrationCompletedAt: _dateTimeValue(
        map['migration_completed_at'],
      ),
      registrationNoticeAccepted: _boolValue(
        map['registration_notice_accepted'],
      ),
      registrationNoticeAcceptedAt: _dateTimeValue(
        map['registration_notice_accepted_at'],
      ),
      deviceWarningCount: _intValue(
        map['device_warning_count'],
      ),
      lastDeviceWarningAt: _dateTimeValue(
        map['last_device_warning_at'],
      ),
      suspendedUntil: _dateTimeValue(
        map['suspended_until'],
      ),
      suspensionReason: _nullableString(
        map['suspension_reason'],
      ),
      lastSocialClaimDate: _dateTimeValue(
        map['last_social_claim_date'],
      ),
      createdAt: _dateTimeValue(
        map['created_at'],
      ),
      updatedAt: _dateTimeValue(
        map['updated_at'],
      ),
    );
  }

  bool get isSuspended {
    if (suspendedUntil == null) {
      return false;
    }

    return suspendedUntil!.isAfter(
      DateTime.now().toUtc(),
    );
  }

  bool get kyc30DayRequirementComplete {
    return kycCheckinStreak >= 30 &&
        kycBoostStreak >= 30;
  }

  bool get canStartFaceVerification {
    return kyc30DayRequirementComplete &&
        kycFaceVerificationUnlocked &&
        !kycFaceVerified;
  }

  bool get canMigrate {
    return migrationAvailable &&
        kycFaceVerified &&
        !migrationCompleted;
  }

  ProfileData copyWith({
    String? name,
    String? username,
    String? email,
    String? referralCode,
    String? referredBy,
    double? fanBalance,
    double? afamBalance,
    double? miningRate,
    int? activeReferrals,
    int? dailyAdsWatched,
    double? adBoost,
    bool? miningActive,
    DateTime? miningStartedAt,
    DateTime? miningEndsAt,
    int? consecutiveCheckIns,
    int? kycCheckinStreak,
    int? kycBoostStreak,
    DateTime? kycLastCheckinDate,
    DateTime? kycLastBoostDate,
    bool? kyc1Eligible,
    bool? kyc1Verified,
    bool? kyc2Eligible,
    bool? kyc2Verified,
    bool? kyc3Verified,
    bool? kycFaceVerificationUnlocked,
    bool? kycFaceVerified,
    DateTime? faceVerificationStartedAt,
    bool? migrationAvailable,
    bool? migrationCompleted,
    DateTime? migrationCompletedAt,
    bool? registrationNoticeAccepted,
    DateTime? registrationNoticeAcceptedAt,
    int? deviceWarningCount,
    DateTime? lastDeviceWarningAt,
    DateTime? suspendedUntil,
    String? suspensionReason,
    DateTime? lastSocialClaimDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileData(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      referralCode:
          referralCode ?? this.referralCode,
      referredBy:
          referredBy ?? this.referredBy,
      fanBalance:
          fanBalance ?? this.fanBalance,
      afamBalance:
          afamBalance ?? this.afamBalance,
      miningRate:
          miningRate ?? this.miningRate,
      activeReferrals:
          activeReferrals ?? this.activeReferrals,
      dailyAdsWatched:
          dailyAdsWatched ?? this.dailyAdsWatched,
      adBoost:
          adBoost ?? this.adBoost,
      miningActive:
          miningActive ?? this.miningActive,
      miningStartedAt:
          miningStartedAt ?? this.miningStartedAt,
      miningEndsAt:
          miningEndsAt ?? this.miningEndsAt,
      consecutiveCheckIns:
          consecutiveCheckIns ??
              this.consecutiveCheckIns,
      kycCheckinStreak:
          kycCheckinStreak ??
              this.kycCheckinStreak,
      kycBoostStreak:
          kycBoostStreak ??
              this.kycBoostStreak,
      kycLastCheckinDate:
          kycLastCheckinDate ??
              this.kycLastCheckinDate,
      kycLastBoostDate:
          kycLastBoostDate ??
              this.kycLastBoostDate,
      kyc1Eligible:
          kyc1Eligible ?? this.kyc1Eligible,
      kyc1Verified:
          kyc1Verified ?? this.kyc1Verified,
      kyc2Eligible:
          kyc2Eligible ?? this.kyc2Eligible,
      kyc2Verified:
          kyc2Verified ?? this.kyc2Verified,
      kyc3Verified:
          kyc3Verified ?? this.kyc3Verified,
      kycFaceVerificationUnlocked:
          kycFaceVerificationUnlocked ??
              this.kycFaceVerificationUnlocked,
      kycFaceVerified:
          kycFaceVerified ??
              this.kycFaceVerified,
      faceVerificationStartedAt:
          faceVerificationStartedAt ??
              this.faceVerificationStartedAt,
      migrationAvailable:
          migrationAvailable ??
              this.migrationAvailable,
      migrationCompleted:
          migrationCompleted ??
              this.migrationCompleted,
      migrationCompletedAt:
          migrationCompletedAt ??
              this.migrationCompletedAt,
      registrationNoticeAccepted:
          registrationNoticeAccepted ??
              this.registrationNoticeAccepted,
      registrationNoticeAcceptedAt:
          registrationNoticeAcceptedAt ??
              this.registrationNoticeAcceptedAt,
      deviceWarningCount:
          deviceWarningCount ??
              this.deviceWarningCount,
      lastDeviceWarningAt:
          lastDeviceWarningAt ??
              this.lastDeviceWarningAt,
      suspendedUntil:
          suspendedUntil ??
              this.suspendedUntil,
      suspensionReason:
          suspensionReason ??
              this.suspensionReason,
      lastSocialClaimDate:
          lastSocialClaimDate ??
              this.lastSocialClaimDate,
      createdAt:
          createdAt ?? this.createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
    );
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final result =
        value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static double _doubleValue(
    dynamic value,
  ) {
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

  static int _intValue(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value == null) {
      return false;
    }

    return value
            .toString()
            .trim()
            .toLowerCase() ==
        'true';
  }

  static DateTime? _dateTimeValue(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    final parsed = DateTime.tryParse(
      value.toString().trim(),
    );

    return parsed?.toUtc();
  }
}

class ProfileService {
  ProfileService._internal();

  static final ProfileService instance =
      ProfileService._internal();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  User? get currentUser =>
      _supabase.auth.currentUser;

  String? get currentUserId =>
      _supabase.auth.currentUser?.id;

  static const String _profileColumns = '''
    id,
    name,
    username,
    email,
    referral_code,
    referred_by,
    fan_balance,
    afam_balance,
    mining_rate,
    active_referrals,
    daily_ads_watched,
    ad_boost,
    mining_active,
    mining_started_at,
    mining_ends_at,
    consecutive_check_ins,
    kyc_checkin_streak,
    kyc_boost_streak,
    kyc_last_checkin_date,
    kyc_last_boost_date,
    kyc1_eligible,
    kyc1_verified,
    kyc2_eligible,
    kyc2_verified,
    kyc3_verified,
    kyc_face_verification_unlocked,
    kyc_face_verified,
    face_verification_started_at,
    migration_available,
    migration_completed,
    migration_completed_at,
    registration_notice_accepted,
    registration_notice_accepted_at,
    device_warning_count,
    last_device_warning_at,
    suspended_until,
    suspension_reason,
    last_social_claim_date,
    created_at,
    updated_at
  ''';

  Future<ProfileData?> getProfile() async {
    final userId = currentUserId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    final response = await _supabase
        .from('profiles')
        .select(_profileColumns)
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProfileData.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<ProfileData> requireProfile() async {
    final profile = await getProfile();

    if (profile == null) {
      throw const AuthException(
        'Profile could not be loaded.',
      );
    }

    return profile;
  }

  Future<ProfileData?> refreshProfile() async {
    return getProfile();
  }

  Future<ProfileData> updateName(
    String name,
  ) async {
    final userId = currentUserId;

    if (userId == null || userId.isEmpty) {
      throw const AuthException(
        'You must be logged in.',
      );
    }

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw const AuthException(
        'Name is required.',
      );
    }

    if (cleanName.length > 50) {
      throw const AuthException(
        'Name must not exceed 50 characters.',
      );
    }

    final response = await _supabase
        .from('profiles')
        .update({
          'name': cleanName,
        })
        .eq('id', userId)
        .select(_profileColumns)
        .single();

    return ProfileData.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<Map<String, double>> getBalances() async {
    final profile = await requireProfile();

    return <String, double>{
      'fan': profile.fanBalance,
      'afam': profile.afamBalance,
    };
  }

  Future<double> getFanBalance() async {
    final profile = await requireProfile();

    return profile.fanBalance;
  }

  Future<double> getAfamBalance() async {
    final profile = await requireProfile();

    return profile.afamBalance;
  }

  Future<String> getDisplayName() async {
    final profile = await requireProfile();

    final username =
        profile.username.trim();

    if (username.isNotEmpty) {
      return username;
    }

    final name = profile.name.trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'POWER FAN User';
  }

  Future<String> getUsername() async {
    final profile = await requireProfile();

    return profile.username;
  }

  Future<String> getEmail() async {
    final profile = await requireProfile();

    final profileEmail =
        profile.email.trim();

    if (profileEmail.isNotEmpty) {
      return profileEmail;
    }

    return currentUser?.email ?? '';
  }

  Future<String> getReferralCode() async {
    final profile = await requireProfile();

    return profile.referralCode;
  }

  Future<int> getActiveReferralCount() async {
    final profile = await requireProfile();

    return profile.activeReferrals;
  }

  Future<double> getMiningRate() async {
    final profile = await requireProfile();

    return profile.miningRate;
  }

  Future<bool> isMiningActive() async {
    final profile = await requireProfile();

    return profile.miningActive;
  }

  Future<int> getKycCheckinStreak() async {
    final profile = await requireProfile();

    return profile.kycCheckinStreak;
  }

  Future<int> getKycBoostStreak() async {
    final profile = await requireProfile();

    return profile.kycBoostStreak;
  }

  Future<bool> isKyc30DayComplete() async {
    final profile = await requireProfile();

    return profile.kyc30DayRequirementComplete;
  }

  Future<bool> isFaceVerificationUnlocked() async {
    final profile = await requireProfile();

    return profile.kycFaceVerificationUnlocked;
  }

  Future<bool> isFaceVerified() async {
    final profile = await requireProfile();

    return profile.kycFaceVerified;
  }

  Future<bool> isMigrationAvailable() async {
    final profile = await requireProfile();

    return profile.canMigrate;
  }

  Future<bool> isMigrationCompleted() async {
    final profile = await requireProfile();

    return profile.migrationCompleted;
  }

  Future<bool> isSuspended() async {
    final profile = await requireProfile();

    return profile.isSuspended;
  }

  Future<int> getDeviceWarningCount() async {
    final profile = await requireProfile();

    return profile.deviceWarningCount;
  }

  Future<ProfileData> getSecurityProfile() async {
    return requireProfile();
  }

  Future<void> ensureProfileExists() async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) {
      return;
    }

    throw const AuthException(
      'Profile is not ready yet. Please try again.',
    );
  }
}
