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

  const ReferralResult.success(String message)
      : this(
          success: true,
          message: message,
        );

  const ReferralResult.failure(String message)
      : this(
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

  Future<ReferralInfo> getReferralInfo() async {
    return SupabaseService.safeCall(() async {
      final result =
          await _client.rpc('get_referral_info');

      final data = _mapFromRpcResult(result);

      if (data['success'] == false) {
        throw Exception(
          data['message']?.toString() ??
              'Unable to load referral information.',
        );
      }

      final referralCode =
          data['referral_code']?.toString() ?? '';

      final totalReferrals =
          _toInt(data['total_referrals']);

      final activeReferrals =
          _toInt(data['active_referrals']);

      final totalInviterRewards =
          _toDouble(data['total_inviter_rewards']);

      final miningBonusPerActiveReferral =
          _toDouble(
        data['mining_bonus_per_active_referral'],
        fallback: 0.02,
      );

      final miningBonus =
          _toDouble(
        data['mining_bonus'],
        fallback:
            activeReferrals *
                miningBonusPerActiveReferral,
      );

      return ReferralInfo(
        referralCode: referralCode,
        activeReferrals: activeReferrals,
        totalReferrals: totalReferrals,
        totalInviterRewards:
            totalInviterRewards,
        miningBonus: miningBonus,
        miningBonusPerActiveReferral:
            miningBonusPerActiveReferral,
      );
    });
  }

  Future<ReferralResult> applyReferralCode(
    String code,
  ) async {
    final cleanCode =
        code.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      return const ReferralResult.failure(
        'Referral code is required.',
      );
    }

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'apply_referral_code',
        params: {
          'p_referral_code': cleanCode,
        },
      );

      final data = _mapFromRpcResult(result);

      final success =
          data['success'] == true;

      final message =
          data['message']?.toString() ??
              (success
                  ? 'Referral code applied successfully.'
                  : 'Unable to apply referral code.');

      return ReferralResult(
        success: success,
        message: message,
      );
    });
  }

  Future<int> getActiveReferrals() async {
    final userId = _userId;

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'calculate_active_referrals',
        params: {
          'p_user_id': userId,
        },
      );

      return _toInt(result);
    });
  }

  Future<double> getMiningBonus() async {
    final userId = _userId;

    return SupabaseService.safeCall(() async {
      final result = await _client.rpc(
        'get_referral_mining_bonus',
        params: {
          'p_user_id': userId,
        },
      );

      return _toDouble(result);
    });
  }

  Map<String, dynamic> _mapFromRpcResult(
    dynamic result,
  ) {
    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result);
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw Exception(
      'Unexpected referral RPC response.',
    );
  }

  int _toInt(dynamic value) {
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

  double _toDouble(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }
}
