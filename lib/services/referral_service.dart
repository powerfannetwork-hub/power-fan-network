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

      if (referredUsers is List) {
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

        if (rewards is List) {
          for (final row in rewards) {
            if (row is Map) {
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
        miningBonusPerActiveReferral:
            bonusPerReferral,
      );
    });
  }

  /// Applies another user's referral code.
  ///
  /// The database/RPC is responsible for validating
  /// the code and preventing duplicate referral rewards.
  Future<ReferralResult> applyReferralCode(
    String code,
  ) async {
    final cleanCode = code.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      return const ReferralResult.failure(
        'Please enter a referral code.',
      );
    }

    try {
      final dynamic response =
          await _client.rpc(
        'apply_referral_code',
        params: {
          'p_referral_code': cleanCode,
        },
      );

      if (response is Map) {
        final map =
            Map<String, dynamic>.from(response);

        final success =
            _toBool(map['success']);

        final message =
            map['message']?.toString() ??
                (success
                    ? 'Referral code applied successfully.'
                    : 'Unable to apply referral code.');

        return success
            ? ReferralResult.success(message)
            : ReferralResult.failure(message);
      }

      if (response is List &&
          response.isNotEmpty &&
          response.first is Map) {
        final map =
            Map<String, dynamic>.from(
          response.first as Map,
        );

        final success =
            _toBool(map['success']);

        final message =
            map['message']?.toString() ??
                (success
                    ? 'Referral code applied successfully.'
                    : 'Unable to apply referral code.');

        return success
            ? ReferralResult.success(message)
            : ReferralResult.failure(message);
      }

      return const ReferralResult.success(
        'Referral code applied successfully.',
      );
    } on PostgrestException catch (error) {
      return ReferralResult.failure(
        _cleanPostgrestError(error),
      );
    } catch (error) {
      return ReferralResult.failure(
        _cleanError(error),
      );
    }
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
          value.toString(),
        ) ??
        0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
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

    final text =
        value.toString().toLowerCase().trim();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'success';
  }

  static String _cleanPostgrestError(
    PostgrestException error,
  ) {
    final message = error.message.trim();

    if (message.isNotEmpty) {
      return message;
    }

    return 'Unable to apply referral code.';
  }

  static String _cleanError(Object error) {
    var text = error.toString().trim();

    if (text.startsWith('Exception: ')) {
      text = text.substring(11).trim();
    }

    return text.isEmpty
        ? 'Unable to apply referral code.'
        : text;
  }
}
