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

    final referralRows = List<Map<String, dynamic>>.from(
      referrals as List,
    );

    final rewardRows = List<Map<String, dynamic>>.from(
      rewards as List,
    );

    final totalReferrals = referralRows.length;

    int activeReferrals = 0;

    for (final referral in referralRows) {
      final status =
          referral['status']?.toString().toLowerCase();

      if (status == 'active') {
        activeReferrals++;
      }
    }

    final profileActive =
        _toInt(profile['active_referrals']);

    if (profileActive > activeReferrals) {
      activeReferrals = profileActive;
    }

    final miningBonusPerReferral =
        _toDouble(profile['referral_boost_rate']) > 0
            ? _toDouble(profile['referral_boost_rate'])
            : 0.02;

    final miningBonus =
        activeReferrals * miningBonusPerReferral;

    double totalInviterRewards = 0;

    for (final reward in rewardRows) {
      totalInviterRewards +=
          _toDouble(reward['inviter_reward']);
    }

    return ReferralInfo(
      referralCode:
          profile['referral_code']?.toString() ?? '',
      totalReferrals: totalReferrals,
      activeReferrals: activeReferrals,
      miningBonus: miningBonus,
      miningBonusPerActiveReferral:
          miningBonusPerReferral,
      totalInviterRewards: totalInviterRewards,
    );
  }

  Future<ReferralResult> applyReferralCode(
    String code,
  ) async {
    final userId = _userId;
    final referralCode = code.trim().toUpperCase();

    if (referralCode.isEmpty) {
      return const ReferralResult(
        success: false,
        message: 'Referral code is required.',
      );
    }

    try {
      final currentProfile = await _client
          .from('profiles')
          .select('id, referral_code, referred_by')
          .eq('id', userId)
          .single();

      final ownCode =
          currentProfile['referral_code']
              ?.toString()
              .trim()
              .toUpperCase();

      if (ownCode == referralCode) {
        return const ReferralResult(
          success: false,
          message: 'You cannot use your own referral code.',
        );
      }

      final existingReferrer =
          currentProfile['referred_by'];

      if (existingReferrer != null &&
          existingReferrer.toString().trim().isNotEmpty) {
        return const ReferralResult(
          success: false,
          message: 'A referral code has already been applied.',
        );
      }

      final inviter = await _client
          .from('profiles')
          .select('id, referral_code')
          .eq('referral_code', referralCode)
          .maybeSingle();

      if (inviter == null) {
        return const ReferralResult(
          success: false,
          message: 'Invalid referral code.',
        );
      }

      final inviterId =
          inviter['id']?.toString();

      if (inviterId == null ||
          inviterId.isEmpty) {
        return const ReferralResult(
          success: false,
          message: 'Invalid referral account.',
        );
      }

      if (inviterId == userId) {
        return const ReferralResult(
          success: false,
          message: 'You cannot use your own referral code.',
        );
      }

      final existingReferral = await _client
          .from('referrals')
          .select('id')
          .eq('referred_id', userId)
          .maybeSingle();

      if (existingReferral != null) {
        return const ReferralResult(
          success: false,
          message: 'This account already has a referral.',
        );
      }

      await _client
          .from('profiles')
          .update({
            'referred_by': inviterId,
          })
          .eq('id', userId);

      await _client.from('referrals').insert({
        'referrer_id': inviterId,
        'referred_id': userId,
        'status': 'active',
        'new_user_reward': 20,
        'referrer_reward': 5,
        'mining_rate_bonus': 0.02,
      });

      return const ReferralResult(
        success: true,
        message: 'Referral code applied successfully.',
      );
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();

      if (message.contains('duplicate') ||
          message.contains('unique')) {
        return const ReferralResult(
          success: false,
          message: 'This referral has already been applied.',
        );
      }

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
    final userId = _userId;

    try {
      final result = await _client.rpc(
        'calculate_active_referrals',
        params: {
          'p_user_id': userId,
        },
      );

      return _toDouble(result);
    } catch (_) {
      final info = await getReferralInfo();
      return info.miningBonus;
    }
  }

  Future<int> getActiveReferrals() async {
    final userId = _userId;

    final result = await _client.rpc(
      'calculate_active_referrals',
      params: {
        'p_user_id': userId,
      },
    );

    final value = _toInt(result);

    if (value >= 0) {
      return value;
    }

    final profile = await _client
        .from('profiles')
        .select('active_referrals')
        .eq('id', userId)
        .single();

    return _toInt(profile['active_referrals']);
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

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

    if (value is double) return value;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
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
