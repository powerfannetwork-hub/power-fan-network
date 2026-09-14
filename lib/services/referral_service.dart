import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class ReferralInfo {
  final String referralCode;
  final int activeReferrals;
  final int totalReferrals;
  final double totalInviterRewards;
  final double miningBonus;
  final double miningBonusPerActiveReferral;
  final bool hasAppliedReferral;

  const ReferralInfo({
    required this.referralCode,
    required this.activeReferrals,
    required this.totalReferrals,
    required this.totalInviterRewards,
    required this.miningBonus,
    required this.miningBonusPerActiveReferral,
    required this.hasAppliedReferral,
  });

  factory ReferralInfo.empty() {
    return const ReferralInfo(
      referralCode: '',
      activeReferrals: 0,
      totalReferrals: 0,
      totalInviterRewards: 0.0,
      miningBonus: 0.02,
      miningBonusPerActiveReferral: 0.02,
      hasAppliedReferral: false,
    );
  }

  ReferralInfo copyWith({
    String? referralCode,
    int? activeReferrals,
    int? totalReferrals,
    double? totalInviterRewards,
    double? miningBonus,
    double? miningBonusPerActiveReferral,
    bool? hasAppliedReferral,
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
      hasAppliedReferral:
          hasAppliedReferral ??
              this.hasAppliedReferral,
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
          data['referral_code']
                  ?.toString()
                  .trim()
                  .toUpperCase() ??
              '';

      final totalReferrals =
          _toInt(data['total_referrals']);

      final activeReferrals =
          _toInt(data['active_referrals']);

      final totalInviterRewards =
          _toDouble(
        data['total_inviter_rewards'],
      );

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

      final hasAppliedReferral =
          _readReferralAppliedStatus(data);

      return ReferralInfo(
        referralCode: referralCode,
        activeReferrals: activeReferrals,
        totalReferrals: totalReferrals,
        totalInviterRewards:
            totalInviterRewards,
        miningBonus: miningBonus,
        miningBonusPerActiveReferral:
            miningBonusPerActiveReferral,
        hasAppliedReferral:
            hasAppliedReferral,
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
        params: <String, dynamic>{
          'p_referral_code': cleanCode,
        },
      );

      final data = _mapFromRpcResult(result);

      final success =
          data['success'] == true;

      final message =
          data['message']?.toString().trim() ??
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
        params: <String, dynamic>{
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
        params: <String, dynamic>{
          'p_user_id': userId,
        },
      );

      return _toDouble(result);
    });
  }

  bool _readReferralAppliedStatus(
    Map<String, dynamic> data,
  ) {
    const boolKeys = [
      'has_applied_referral',
      'referral_applied',
      'has_referral',
      'referral_used',
      'has_used_referral',
    ];

    for (final key in boolKeys) {
      if (data.containsKey(key)) {
        return _toBool(data[key]);
      }
    }

    const idKeys = [
      'referred_by',
      'referred_by_id',
      'referrer_id',
      'invited_by',
      'inviter_id',
    ];

    for (final key in idKeys) {
      final value = data[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  bool _toBool(dynamic value) {
    if (value == null) {
      return false;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value.toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  Map<String, dynamic> _mapFromRpcResult(
    dynamic result,
  ) {
    if (result == null) {
      return <String, dynamic>{};
    }

    if (result is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result);
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;

      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(first);
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw Exception(
      'Unexpected referral RPC response.',
    );
  }

  int _toInt(dynamic value) {
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

  double _toDouble(
    dynamic value, {
    double fallback = 0.0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString().trim(),
        ) ??
        fallback;
  }
}
