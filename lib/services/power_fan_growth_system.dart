/// POWER FAN NETWORK
/// Growth & Engagement System
///
/// Standalone configuration/logic for:
/// - Daily Spin
/// - Starter rewards
/// - Daily streaks
/// - Temporary mining boosts
/// - Daily challenges
/// - Referral milestones
/// - Miner milestones
///
/// IMPORTANT:
/// This file is intentionally independent from the existing
/// mining engine, Supabase services, ad services, referral
/// services, and UI.
///
/// It does NOT save anything to a database.
/// Persistence/integration can be added later without changing
/// the reward definitions in this file.

class PowerFanGrowthSystem {
  PowerFanGrowthSystem._();

  static const String version = '1.0.0';

  // ============================================================
  // STARTER REWARDS
  // ============================================================

  static const double registrationReward = 20.0;

  static const double firstMiningBonus = 3.0;

  static const double profileCompletionReward = 5.0;

  // ============================================================
  // DAILY SPIN
  // ============================================================

  static const int freeSpinsPerDay = 1;

  static const int maximumSpinResults = 8;

  static const List<DailySpinReward> dailySpinRewards = [
    DailySpinReward(
      id: 'fan_1',
      title: '+1 FAN',
      type: DailySpinRewardType.fan,
      fanAmount: 1.0,
      weight: 24,
    ),
    DailySpinReward(
      id: 'fan_2',
      title: '+2 FAN',
      type: DailySpinRewardType.fan,
      fanAmount: 2.0,
      weight: 20,
    ),
    DailySpinReward(
      id: 'fan_3',
      title: '+3 FAN',
      type: DailySpinRewardType.fan,
      fanAmount: 3.0,
      weight: 14,
    ),
    DailySpinReward(
      id: 'boost_1h',
      title: '+0.10 FAN/H',
      type: DailySpinRewardType.miningBoost,
      boostRatePerHour: 0.10,
      boostDurationMinutes: 60,
      weight: 12,
    ),
    DailySpinReward(
      id: 'boost_2h',
      title: '+0.10 FAN/H',
      type: DailySpinRewardType.miningBoost,
      boostRatePerHour: 0.10,
      boostDurationMinutes: 120,
      weight: 7,
    ),
    DailySpinReward(
      id: 'streak',
      title: 'STREAK BOOST',
      type: DailySpinRewardType.streakBoost,
      boostDurationMinutes: 60,
      weight: 8,
    ),
    DailySpinReward(
      id: 'task_bonus',
      title: 'TASK BONUS',
      type: DailySpinRewardType.taskBonus,
      fanAmount: 2.0,
      weight: 8,
    ),
    DailySpinReward(
      id: 'try_again',
      title: 'TRY AGAIN',
      type: DailySpinRewardType.tryAgain,
      weight: 7,
    ),
  ];

  // ============================================================
  // DAILY STREAK
  // ============================================================

  static const List<DailyStreakReward> dailyStreakRewards = [
    DailyStreakReward(
      day: 1,
      fanReward: 1.0,
      miningBoost: 0.0,
      boostDurationMinutes: 0,
    ),
    DailyStreakReward(
      day: 2,
      fanReward: 1.0,
      miningBoost: 0.02,
      boostDurationMinutes: 60,
    ),
    DailyStreakReward(
      day: 3,
      fanReward: 2.0,
      miningBoost: 0.03,
      boostDurationMinutes: 60,
    ),
    DailyStreakReward(
      day: 4,
      fanReward: 2.0,
      miningBoost: 0.03,
      boostDurationMinutes: 60,
    ),
    DailyStreakReward(
      day: 5,
      fanReward: 3.0,
      miningBoost: 0.05,
      boostDurationMinutes: 60,
    ),
    DailyStreakReward(
      day: 6,
      fanReward: 3.0,
      miningBoost: 0.05,
      boostDurationMinutes: 60,
    ),
    DailyStreakReward(
      day: 7,
      fanReward: 5.0,
      miningBoost: 0.05,
      boostDurationMinutes: 120,
    ),
    DailyStreakReward(
      day: 14,
      fanReward: 10.0,
      miningBoost: 0.10,
      boostDurationMinutes: 120,
    ),
    DailyStreakReward(
      day: 30,
      fanReward: 25.0,
      miningBoost: 0.10,
      boostDurationMinutes: 120,
    ),
  ];

  // ============================================================
  // TEMPORARY BOOSTS
  // ============================================================

  static const List<PowerFanBoost> availableBoosts = [
    PowerFanBoost(
      id: 'power_hour',
      title: 'Power Hour',
      description: '+0.10 FAN/H for 1 hour',
      ratePerHour: 0.10,
      durationMinutes: 60,
    ),
    PowerFanBoost(
      id: 'double_mining',
      title: 'Double Mining',
      description: '2x mining rate for 30 minutes',
      rateMultiplier: 2.0,
      durationMinutes: 30,
    ),
    PowerFanBoost(
      id: 'double_mining_60',
      title: 'Double Mining',
      description: '2x mining rate for 1 hour',
      rateMultiplier: 2.0,
      durationMinutes: 60,
    ),
  ];

  // ============================================================
  // DAILY CHALLENGES
  // ============================================================

  static const List<DailyChallenge> dailyChallenges = [
    DailyChallenge(
      id: 'start_mining',
      title: 'Start Mining',
      description: 'Start one mining session.',
      target: 1,
      rewardFan: 1.0,
    ),
    DailyChallenge(
      id: 'watch_ad',
      title: 'Watch Boost Ad',
      description: 'Complete one rewarded ad.',
      target: 1,
      rewardFan: 1.0,
    ),
    DailyChallenge(
      id: 'complete_tasks',
      title: 'Complete Tasks',
      description: 'Complete 2 social tasks.',
      target: 2,
      rewardFan: 2.0,
    ),
    DailyChallenge(
      id: 'daily_checkin',
      title: 'Daily Check-in',
      description: 'Complete today check-in.',
      target: 1,
      rewardFan: 1.0,
    ),
    DailyChallenge(
      id: 'invite_friend',
      title: 'Invite a Friend',
      description: 'Invite one new user.',
      target: 1,
      rewardFan: 5.0,
    ),
  ];

  // ============================================================
  // REFERRAL MILESTONES
  // ============================================================

  static const List<ReferralMilestone> referralMilestones = [
    ReferralMilestone(
      referrals: 1,
      rewardFan: 5.0,
      title: 'First Referral',
    ),
    ReferralMilestone(
      referrals: 5,
      rewardFan: 10.0,
      title: 'Growing Network',
    ),
    ReferralMilestone(
      referrals: 10,
      rewardFan: 20.0,
      title: 'Network Builder',
    ),
    ReferralMilestone(
      referrals: 25,
      rewardFan: 50.0,
      title: 'Community Builder',
    ),
    ReferralMilestone(
      referrals: 50,
      rewardFan: 100.0,
      title: 'Power Builder',
    ),
    ReferralMilestone(
      referrals: 100,
      rewardFan: 250.0,
      title: 'Network Leader',
    ),
  ];

  // ============================================================
  // MINER MILESTONES
  // ============================================================

  static const List<MinerMilestone> minerMilestones = [
    MinerMilestone(
      id: 'bronze',
      title: 'Bronze Miner',
      requiredFan: 100.0,
      rewardFan: 5.0,
    ),
    MinerMilestone(
      id: 'silver',
      title: 'Silver Miner',
      requiredFan: 500.0,
      rewardFan: 15.0,
    ),
    MinerMilestone(
      id: 'gold',
      title: 'Gold Miner',
      requiredFan: 1000.0,
      rewardFan: 30.0,
    ),
    MinerMilestone(
      id: 'platinum',
      title: 'Platinum Miner',
      requiredFan: 5000.0,
      rewardFan: 75.0,
    ),
    MinerMilestone(
      id: 'diamond',
      title: 'Diamond Miner',
      requiredFan: 10000.0,
      rewardFan: 150.0,
    ),
  ];

  // ============================================================
  // HELPER METHODS
  // ============================================================

  static DailyStreakReward? getStreakReward(
    int streakDay,
  ) {
    for (final reward in dailyStreakRewards) {
      if (reward.day == streakDay) {
        return reward;
      }
    }

    return null;
  }

  static DailyStreakReward getNearestStreakReward(
    int streakDay,
  ) {
    DailyStreakReward selected =
        dailyStreakRewards.first;

    for (final reward in dailyStreakRewards) {
      if (reward.day <= streakDay &&
          reward.day >= selected.day) {
        selected = reward;
      }
    }

    return selected;
  }

  static ReferralMilestone? getReferralMilestone(
    int referralCount,
  ) {
    ReferralMilestone? result;

    for (final milestone in referralMilestones) {
      if (referralCount >= milestone.referrals) {
        result = milestone;
      }
    }

    return result;
  }

  static MinerMilestone? getMinerMilestone(
    double totalFan,
  ) {
    MinerMilestone? result;

    for (final milestone in minerMilestones) {
      if (totalFan >= milestone.requiredFan) {
        result = milestone;
      }
    }

    return result;
  }

  static MinerMilestone? getNextMinerMilestone(
    double totalFan,
  ) {
    for (final milestone in minerMilestones) {
      if (totalFan < milestone.requiredFan) {
        return milestone;
      }
    }

    return null;
  }

  static double calculateWeightedSpinTotal() {
    double total = 0;

    for (final reward in dailySpinRewards) {
      total += reward.weight;
    }

    return total;
  }

  static bool canUseDailySpin({
    required DateTime? lastSpinAt,
    required DateTime now,
  }) {
    if (lastSpinAt == null) {
      return true;
    }

    return !_isSameCalendarDay(
      lastSpinAt,
      now,
    );
  }

  static bool isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return _isSameCalendarDay(
      first,
      second,
    );
  }

  static bool _isSameCalendarDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

// ================================================================
// DAILY SPIN REWARD
// ================================================================

enum DailySpinRewardType {
  fan,
  miningBoost,
  streakBoost,
  taskBonus,
  tryAgain,
}

class DailySpinReward {
  const DailySpinReward({
    required this.id,
    required this.title,
    required this.type,
    this.fanAmount = 0.0,
    this.boostRatePerHour = 0.0,
    this.boostDurationMinutes = 0,
    required this.weight,
  });

  final String id;
  final String title;
  final DailySpinRewardType type;

  final double fanAmount;

  final double boostRatePerHour;

  final int boostDurationMinutes;

  /// Higher weight means a higher chance of appearing.
  final int weight;

  bool get givesFan =>
      type == DailySpinRewardType.fan ||
      type == DailySpinRewardType.taskBonus;

  bool get givesMiningBoost =>
      type == DailySpinRewardType.miningBoost;

  bool get isTryAgain =>
      type == DailySpinRewardType.tryAgain;
}

// ================================================================
// DAILY STREAK
// ================================================================

class DailyStreakReward {
  const DailyStreakReward({
    required this.day,
    required this.fanReward,
    required this.miningBoost,
    required this.boostDurationMinutes,
  });

  final int day;

  final double fanReward;

  final double miningBoost;

  final int boostDurationMinutes;

  bool get hasBoost =>
      miningBoost > 0 &&
      boostDurationMinutes > 0;
}

// ================================================================
// TEMPORARY BOOST
// ================================================================

class PowerFanBoost {
  const PowerFanBoost({
    required this.id,
    required this.title,
    required this.description,
    this.ratePerHour = 0.0,
    this.rateMultiplier = 1.0,
    required this.durationMinutes,
  });

  final String id;

  final String title;

  final String description;

  /// Adds directly to the mining rate.
  final double ratePerHour;

  /// Multiplies the active mining rate.
  final double rateMultiplier;

  final int durationMinutes;

  bool get hasFlatRateBoost =>
      ratePerHour > 0;

  bool get hasMultiplier =>
      rateMultiplier > 1.0;
}

// ================================================================
// DAILY CHALLENGE
// ================================================================

class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.rewardFan,
  });

  final String id;

  final String title;

  final String description;

  final int target;

  final double rewardFan;
}

// ================================================================
// REFERRAL MILESTONE
// ================================================================

class ReferralMilestone {
  const ReferralMilestone({
    required this.referrals,
    required this.rewardFan,
    required this.title,
  });

  final int referrals;

  final double rewardFan;

  final String title;
}

// ================================================================
// MINER MILESTONE
// ================================================================

class MinerMilestone {
  const MinerMilestone({
    required this.id,
    required this.title,
    required this.requiredFan,
    required this.rewardFan,
  });

  final String id;

  final String title;

  final double requiredFan;

  final double rewardFan;
}
