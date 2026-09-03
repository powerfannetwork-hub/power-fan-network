import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals/app_constants.dart';

class ReferralInfo {
  final String referralCode;
  final String? referredBy;
  final int totalReferrals;
  final int activeReferrals;
  final double miningBonusPerActiveReferral;
  final double miningBonus;
  final double totalInviterRewards;

  const ReferralInfo({
    required this.referralCode,
    required this.referredBy,
    required this.totalReferrals,
    required this.activeReferrals,
    required this.miningBonusPerActiveReferral,
    required this.miningBonus,
    required this.totalInviterRewards,
  });

  factory ReferralInfo.fromMap(Map<String, dynamic> data) {
    final bonusPerReferral =
        _toDouble(data['mining_bonus_per_active_referral']);

    return ReferralInfo(
      referralCode: data['referral_code']?.toString() ?? '',
      referredBy: data['referred_by']?.toString(),
      totalReferrals: _toInt(data['total_referrals']),
      activeReferrals: _toInt(data['active_referrals']),
      miningBonusPerActiveReferral: bonusPerReferral > 0
          ? bonusPerReferral
          : AppConfig.referralMiningBoost,
      miningBonus: _toDouble(data['mining_bonus']),
      totalInviterRewards: _toDouble(
        data['total_inviter_rewards'],
      ),
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

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }
}

class ReferralResult {
  final bool success;
  final bool applied;
  final bool alreadyApplied;
  final String message;
  final double newUserReward;
  final double inviterReward;
  final double activeReferralBonus;
  final String? inviterId;
  final String? referredUserId;

  const ReferralResult({
    required this.success,
    required this.applied,
    required this.alreadyApplied,
    required this.message,
    required this.newUserReward,
    required this.inviterReward,
    required this.activeReferralBonus,
    required this.inviterId,
    required this.referredUserId,
  });

  factory ReferralResult.fromMap(
    Map<String, dynamic> data,
  ) {
    return ReferralResult(
      success: _toBool(data['success']),
      applied: _toBool(data['applied']),
      alreadyApplied: _toBool(
        data['already_applied'],
      ),
      message: data['message']?.toString() ??
          'Referral request completed.',
      newUserReward: _toDouble(
        data['new_user_reward'],
      ),
      inviterReward: _toDouble(
        data['inviter_reward'],
      ),
      activeReferralBonus: _toDouble(
        data['active_referral_bonus'],
      ),
      inviterId: data['inviter_id']?.toString(),
      referredUserId:
          data['referred_user_id']?.toString(),
    );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }
}

class ReferralService {
  ReferralService({
    SupabaseClient? client,
  }) : _supabase =
            client ?? Supabase.instance.client;

  ReferralService._internal()
      : _supabase = Supabase.instance.client;

  static final ReferralService instance =
      ReferralService._internal();

  final SupabaseClient _supabase;

  Future<void> _requireUser() async {
    final session = _supabase.auth.currentSession;
    final user = _supabase.auth.currentUser;

    if (session == null || user == null) {
      throw const AuthException(
        'Your session has expired. Please log in again.',
      );
    }
  }

  Map<String, dynamic> _mapResponse(
    dynamic response,
  ) {
    if (response == null) {
      return <String, dynamic>{};
    }

    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(
        response,
      );
    }

    if (response is List &&
        response.isNotEmpty) {
      final first = response.first;

      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(
          first,
        );
      }
    }

    throw Exception(
      'Unexpected referral response.',
    );
  }

  Exception _formatError(
    Object error,
    String action,
  ) {
    if (error is PostgrestException) {
      final message = error.message.trim();

      if (message.isNotEmpty) {
        return Exception(message);
      }

      return Exception(
        'Unable to $action.',
      );
    }

    if (error is AuthException) {
      return Exception(error.message);
    }

    return Exception(
      'Unable to $action.',
    );
  }

  Future<ReferralInfo> getReferralInfo() async {
    try {
      await _requireUser();

      final response = await _supabase.rpc(
        'get_referral_info',
      );

      final data = _mapResponse(response);

      return ReferralInfo.fromMap(data);
    } catch (error) {
      throw _formatError(
        error,
        'load referral information',
      );
    }
  }

  Future<ReferralResult> applyReferralCode(
    String referralCode,
  ) async {
    try {
      await _requireUser();

      final code = referralCode.trim();

      if (code.isEmpty) {
        return const ReferralResult(
          success: false,
          applied: false,
          alreadyApplied: false,
          message: 'Please enter a referral code.',
          newUserReward: 0,
          inviterReward: 0,
          activeReferralBonus: 0,
          inviterId: null,
          referredUserId: null,
        );
      }

      final response = await _supabase.rpc(
        'apply_referral_code',
        params: <String, dynamic>{
          'p_referral_code': code,
        },
      );

      final data = _mapResponse(response);

      return ReferralResult.fromMap(data);
    } catch (error) {
      throw _formatError(
        error,
        'apply referral code',
      );
    }
  }

  Future<double> getReferralMiningBonus() async {
    try {
      await _requireUser();

      final user = _supabase.auth.currentUser!;

      final response = await _supabase.rpc(
        'get_referral_mining_bonus',
        params: <String, dynamic>{
          'p_user_id': user.id,
        },
      );

      if (response is num) {
        return response.toDouble();
      }

      final data = _mapResponse(response);

      final value =
          data['mining_bonus'] ??
          data['bonus'] ??
          data['rate'] ??
          data['value'];

      if (value is num) {
        return value.toDouble();
      }

      return 0.0;
    } catch (error) {
      throw _formatError(
        error,
        'load referral mining bonus',
      );
    }
  }

  Future<int> getActiveReferralCount() async {
    final info = await getReferralInfo();
    return info.activeReferrals;
  }

  Future<int> getTotalReferralCount() async {
    final info = await getReferralInfo();
    return info.totalReferrals;
  }

  Future<String> getMyReferralCode() async {
    final info = await getReferralInfo();
    return info.referralCode;
  }

  Future<double> calculateReferralMiningBonus() async {
    final info = await getReferralInfo();

    return info.activeReferrals *
        AppConfig.referralMiningBoost;
  }

  Future<bool> hasReferrer() async {
    final info = await getReferralInfo();

    return info.referredBy != null &&
        info.referredBy!.isNotEmpty;
  }

  Future<Map<String, dynamic>> getSummary() async {
    final info = await getReferralInfo();

    return <String, dynamic>{
      'referral_code': info.referralCode,
      'referred_by': info.referredBy,
      'total_referrals': info.totalReferrals,
      'active_referrals': info.activeReferrals,
      'mining_bonus_per_referral':
          AppConfig.referralMiningBoost,
      'mining_bonus': info.activeReferrals *
          AppConfig.referralMiningBoost,
      'new_user_reward':
          AppConfig.newUserReferralReward,
      'inviter_reward':
          AppConfig.inviterReferralReward,
      'total_inviter_rewards':
          info.totalInviterRewards,
    };
  }
}
