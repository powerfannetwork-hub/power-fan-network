import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileData {
  final String id;
  final String name;
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

  final bool kyc1Eligible;
  final bool kyc1Verified;
  final bool kyc2Eligible;
  final bool kyc2Verified;
  final bool kyc3Verified;

  final DateTime? lastSocialClaimDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileData({
    required this.id,
    required this.name,
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
    required this.kyc1Eligible,
    required this.kyc1Verified,
    required this.kyc2Eligible,
    required this.kyc2Verified,
    required this.kyc3Verified,
    required this.lastSocialClaimDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileData.fromMap(Map<String, dynamic> map) {
    return ProfileData(
      id: _stringValue(map['id']),
      name: _stringValue(map['name']),
      email: _stringValue(map['email']),
      referralCode: _stringValue(map['referral_code']),
      referredBy: _nullableString(map['referred_by']),
      fanBalance: _doubleValue(map['fan_balance']),
      afamBalance: _doubleValue(map['afam_balance']),
      miningRate: _doubleValue(map['mining_rate']),
      activeReferrals: _intValue(map['active_referrals']),
      dailyAdsWatched: _intValue(map['daily_ads_watched']),
      adBoost: _doubleValue(map['ad_boost']),
      miningActive: _boolValue(map['mining_active']),
      miningStartedAt: _dateTimeValue(map['mining_started_at']),
      miningEndsAt: _dateTimeValue(map['mining_ends_at']),
      consecutiveCheckIns: _intValue(
        map['consecutive_check_ins'],
      ),
      kyc1Eligible: _boolValue(map['kyc1_eligible']),
      kyc1Verified: _boolValue(map['kyc1_verified']),
      kyc2Eligible: _boolValue(map['kyc2_eligible']),
      kyc2Verified: _boolValue(map['kyc2_verified']),
      kyc3Verified: _boolValue(map['kyc3_verified']),
      lastSocialClaimDate: _dateTimeValue(
        map['last_social_claim_date'],
      ),
      createdAt: _dateTimeValue(map['created_at']),
      updatedAt: _dateTimeValue(map['updated_at']),
    );
  }

  ProfileData copyWith({
    String? name,
    String? email,
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
    bool? kyc1Eligible,
    bool? kyc1Verified,
    bool? kyc2Eligible,
    bool? kyc2Verified,
    bool? kyc3Verified,
    DateTime? lastSocialClaimDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileData(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      referralCode: referralCode,
      referredBy: referredBy,
      fanBalance: fanBalance ?? this.fanBalance,
      afamBalance: afamBalance ?? this.afamBalance,
      miningRate: miningRate ?? this.miningRate,
      activeReferrals: activeReferrals ?? this.activeReferrals,
      dailyAdsWatched: dailyAdsWatched ?? this.dailyAdsWatched,
      adBoost: adBoost ?? this.adBoost,
      miningActive: miningActive ?? this.miningActive,
      miningStartedAt: miningStartedAt ?? this.miningStartedAt,
      miningEndsAt: miningEndsAt ?? this.miningEndsAt,
      consecutiveCheckIns:
          consecutiveCheckIns ?? this.consecutiveCheckIns,
      kyc1Eligible: kyc1Eligible ?? this.kyc1Eligible,
      kyc1Verified: kyc1Verified ?? this.kyc1Verified,
      kyc2Eligible: kyc2Eligible ?? this.kyc2Eligible,
      kyc2Verified: kyc2Verified ?? this.kyc2Verified,
      kyc3Verified: kyc3Verified ?? this.kyc3Verified,
      lastSocialClaimDate:
          lastSocialClaimDate ?? this.lastSocialClaimDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  static double _doubleValue(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _intValue(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
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

    return value.toString().trim().toLowerCase() == 'true';
  }

  static DateTime? _dateTimeValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }
}

class ProfileService {
  ProfileService();

  ProfileService._internal();

  static final ProfileService instance =
      ProfileService._internal();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  User? get currentUser =>
      _supabase.auth.currentUser;

  String? get currentUserId =>
      _supabase.auth.currentUser?.id;

  Future<ProfileData?> getProfile() async {
    final userId = currentUserId;

    if (userId == null) {
      return null;
    }

    final response = await _supabase
        .from('profiles')
        .select('''
          id,
          name,
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
          kyc1_eligible,
          kyc1_verified,
          kyc2_eligible,
          kyc2_verified,
          kyc3_verified,
          last_social_claim_date,
          created_at,
          updated_at
        ''')
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

    if (userId == null) {
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
        .select('''
          id,
          name,
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
          kyc1_eligible,
          kyc1_verified,
          kyc2_eligible,
          kyc2_verified,
          kyc3_verified,
          last_social_claim_date,
          created_at,
          updated_at
        ''')
        .single();

    return ProfileData.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  Future<Map<String, double>> getBalances() async {
    final profile = await requireProfile();

    return {
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

    if (profile.name.trim().isEmpty) {
      return 'POWER FAN User';
    }

    return profile.name.trim();
  }

  Future<String> getEmail() async {
    final profile = await requireProfile();

    final profileEmail = profile.email.trim();

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
