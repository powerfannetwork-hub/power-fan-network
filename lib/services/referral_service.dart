import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class ReferralInfo {
  final String referralCode;
  final int activeReferrals;
  final int totalReferrals;
  final double totalInviterRewards;
  final double miningBonus;
  final double miningBonusPerActiveReferral;

  const ReferralInfo({
    required this.referralCode,
    required this.activeReferrals,
    required this.totalReferrals,
    required this.totalInviterRewards,
    required this.miningBonus,
    required this.miningBonusPerActiveReferral,
  });

  factory ReferralInfo.empty() {
    return const ReferralInfo(
      referralCode: '',
      activeReferrals: 0,
      totalReferrals: 0,
      totalInviterRewards: 0,
      miningBonus: 0,
      miningBonusPerActiveReferral: 0.02,
    );
  }

  ReferralInfo copyWith({
    String? referralCode,
    int? activeReferrals,
    int? totalReferrals,
    double? totalInviterRewards,
    double? miningBonus,
    double? miningBonusPerActiveReferral,
  }) {
    return ReferralInfo(
      referralCode: referralCode ?? this.referralCode,
      activeReferrals:
          activeReferrals ?? this.activeReferrals,
      totalReferrals:
          totalReferrals ?? this.totalReferrals,
      totalInviterRewards:
          totalInviterRewards ?? this.totalInviterRewards,
      miningBonus:
          miningBonus ?? this.miningBonus,
      miningBonusPerActiveReferral:
          miningBonusPerActiveReferral ??
              this.miningBonusPerActiveReferral,
    );
  }
}

class ReferralResult {
  final bool success;
  final String message;

  const ReferralResult({
    required this.success,
    required this.message,
  });

  const ReferralResult.success(
    String message,
  ) : this(
          success: true,
          message: message,
        );

  const ReferralResult.failure(
    String message,
  ) : this(
          success: false,
          message: message,
        );
}

class ReferralService {
  ReferralService._();

  static final ReferralService instance =
      ReferralService._();

  SupabaseClient get _client =>
      SupabaseService.client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.id;
  }

  /// Loads referral information for the signed-in user.
  ///
  /// Server-side data is used as the source of truth.
  Future<ReferralInfo> getReferralInfo() async {
    final userId = _userId;

    return SupabaseService.safeCall(() async {
      final profile = await _client
          .from('profiles')
          .select(
            'referral_code, active_referrals',
          )
          .eq('id', userId)
          .single();

      final profileMap =
          Map<String, dynamic>.from(profile);

      final referralCode =
          profileMap['referral_code']?.toString() ?? '';

      int totalReferrals = 0;

      final referredUsers = await _client
          .from('profiles')
          .select('id')
          .eq('referred_by', userId);

      if (referredUsers != null) {  // <-- AN GYARA NAN: an cire `is List`
        totalReferrals = referredUsers.length;
      }

      int activeReferrals = 0;

      try {
        final dynamic activeResult =
            await _client.rpc(
          'calculate_active_referrals',
          params: {
            'p_user_id': userId,
          },
        );

        activeReferrals =
            _toInt(activeResult);
      } catch (_) {
        activeReferrals = _toInt(
          profileMap['active_referrals'],
        );
      }

      double totalInviterRewards = 0;

      try {
        final rewards = await _client
            .from('referral_rewards')
            .select('inviter_reward')
            .eq('inviter_id', userId);

        if (rewards != null) {  // <-- AN GYARA NAN: an cire `is List`
          for (final row in rewards) {
            if (row != null) {  // <-- AN GYARA NAN: an cire `is Map`
              totalInviterRewards += _toDouble(
                row['inviter_reward'],
              );
            }
          }
        }
      } catch (_) {
        totalInviterRewards = 0;
      }

      const double bonusPerReferral = 0.02;

      final double miningBonus =
          activeReferrals * bonusPerReferral;

      return ReferralInfo(
        referralCode: referralCode,
        activeReferrals: activeReferrals,
        totalReferrals: totalReferrals,
        totalInviterRewards:
            totalInviterRewards,
        miningBonus: miningBonus,
       
