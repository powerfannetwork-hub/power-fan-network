import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralInfo {
  final String referralCode;
  final int totalReferrals;
  final int activeReferrals;
  final double miningBonus;
  final double miningBonusPerActiveReferral;
  final double totalInviterRewards;

  const ReferralInfo({
    required this.referralCode,
    required this.totalReferrals,
    required this.activeReferrals,
    required this.miningBonus,
    required this.miningBonusPerActiveReferral,
    required this.totalInviterRewards,
  });
}

class ReferralResult {
  final bool success;
  final String message;

  const ReferralResult({
    required this.success,
    required this.message,
  });
}

class ReferralService {
  ReferralService._();

  static final ReferralService instance = ReferralService._();

  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.id;
  }

  Future<ReferralInfo> getReferralInfo() async {
    final userId = _userId;

    final profile = await _client
        .from('profiles')
        .select(
          'referral_code, active_referrals, referral_boost_rate',
        )
        .eq('id', userId)
        .single();

    final referrals = await _client
        .from('referrals')
        .select('id, status')
        .eq('referrer_id', userId);

    final rewards = await _client
        .from('referral_rewards')
        .select('inviter_reward')
        .eq('inviter_id', userId);

    final referralRows = referrals is List
        ? referrals
            .whereType<Map>()
            .map(
              (row) => Map<String, dynamic>.from(row),
            )
            .toList()
        : <Map<String, dynamic>>[];

    final rewardRows = rewards is List
        ? rewards
            .whereType<Map>()
            .map(
              (row) => Map<String, dynamic>.from(row),
            )
            .toList()
        : <Map<String, dynamic>>[];

    int activeReferrals = 0;

    for (final referral in referralRows) {
      final status =
          referral['status']?.toString().toLowerCase().trim();

      if (status == 'active') {
        activeReferrals++;
      }
    }

    final profileActive =
        _toInt(profile['active_referrals']);

    if (profileActive > activeReferrals) {
      activeReferrals = profileActive;
    }

    final storedBonus =
        _toDouble(profile['referral_boost_rate']);

    final bonusPerReferral =
        storedBonus > 0 ? storedBonus : 0.02;

    final miningBonus =
        activeReferrals * bonusPerReferral;

    double totalRewards = 0;

    for (final reward in rewardRows) {
      totalRewards +=
          _toDouble(reward['inviter_reward']);
    }

    return ReferralInfo(
      referralCode:
          profile['referral_code']?.toString() ?? '',
      totalReferrals: referralRows.length,
      activeReferrals: activeReferrals,
      miningBonus: miningBonus,
      miningBonusPerActiveReferral:
          bonusPerReferral,
      totalInviterRewards: totalRewards,
    );
  }

  Future<ReferralResult> applyReferralCode(
    String code,
  ) async {
    _userId;

    final referralCode =
        code.trim().toUpperCase();

    if (referralCode.isEmpty) {
      return const ReferralResult(
        success: false,
        message: 'Referral code is required.',
      );
    }

    try {
      final response = await _client.rpc(
        'apply_referral_code',
        params: {
          'p_referral_code': referralCode,
        },
      );

      Map<String, dynamic>? result;

      if (response is Map) {
        result = Map<String, dynamic>.from(response);
      } else if (response is List &&
          response.isNotEmpty &&
          response.first is Map) {
        result = Map<String, dynamic>.from(
          response.first as Map,
        );
      }

      if (result == null) {
        return const ReferralResult(
          success: false,
          message: 'Invalid server response.',
        );
      }

      final success =
          _toBool(result['success']);

      final message =
          result['message']?.toString().trim();

      return ReferralResult(
        success: success,
        message: message == null || message.isEmpty
            ? success
                ? 'Referral code applied successfully.'
                : 'Unable to apply referral code.'
            : message,
      );
    } on PostgrestException catch (error) {
      return ReferralResult(
        success: false,
        message: error.message,
      );
    } catch (error) {
      return ReferralResult(
        success: false,
        message: _cleanError(error),
      );
    }
  }

  Future<double> getMiningBonus() async {
    try {
      final result = await _client.rpc(
        'calculate_active_referrals',
        params: {
          'p_user_id': _userId,
        },
      );

      return _toDouble(result);
    } catch (_) {
      final info = await getReferralInfo();
      return info.miningBonus;
    }
  }

  Future<int> getActiveReferrals() async {
    try {
      final result = await _client.rpc(
        'calculate_active_referrals',
        params: {
          'p_user_id': _userId,
        },
      );

      return _toInt(result);
    } catch (_) {
      final info = await getReferralInfo();
      return info.activeReferrals;
    }
  }

  int _toInt(dynamic value) {
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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'success';
  }

  String _cleanError(Object error) {
    var text = error.toString();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11);
    }

    if (text.startsWith('PostgrestException: ')) {
      text = text.substring(19);
    }

    return text.trim().isEmpty
        ? 'Something went wrong. Please try again.'
        : text.trim();
  }
}
