// lib/globals/app_constants.dart

class AppConstants {
  // ============================================================
  // APP
  // ============================================================

  static const String appName = 'POWER FAN NETWORK';
  static const String brandName = 'POWER FAN';
  static const String miningCoinName = 'FAN';
  static const String originalCoinName = 'AFAM';

  // ============================================================
  // MINING
  // ============================================================

  static const double baseMiningRate = 0.2;

  static const double adBoostPerAd = 0.1;

  static const int maxDailyAds = 7;

  static const double maxAdBoost = 0.7;

  static const int miningHours = 24;

  // ============================================================
  // REFERRAL
  // ============================================================

  static const double newUserReferralReward = 20.0;

  static const double inviterReferralReward = 5.0;

  static const double referralMiningBoost = 0.02;

  // ============================================================
  // DAILY SOCIAL TASK
  // ============================================================

  static const double dailySocialReward = 10.0;

  // ============================================================
  // KYC
  // ============================================================

  static const int kyc1RequiredDays = 14;

  static const int kyc2RequiredDays = 30;

  static const int kyc2RequiredReferrals = 3;

  // ============================================================
  // WALLET
  // ============================================================

  static const String walletStatus = 'COMING SOON';

  // ============================================================
  // STORAGE
  // ============================================================

  static const String authTokenKey =
      'power_fan_auth_token';

  static const String userKey =
      'power_fan_user';

  // ============================================================
  // SUPABASE TABLES
  // ============================================================

  static const String usersTable = 'users';

  static const String miningSessionsTable =
      'mining_sessions';

  static const String referralsTable =
      'referrals';

  static const String dailyTasksTable =
      'daily_tasks';

  static const String adRewardsTable =
      'ad_rewards';

  static const String notificationsTable =
      'notifications';

  static const String kycTable = 'kyc_verifications';

  // ============================================================
  // API
  // ============================================================

  static const String apiVersion = 'v1';

  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const int purpleColor = 0xFF3B159B;

  static const int deepPurpleColor = 0xFF241064;

  static const int lightBackgroundColor = 0xFFF8F8FC;

  static const int greenColor = 0xFF159B61;

  // ============================================================
  // LANGUAGE
  // ============================================================

  static const List<String> supportedLanguages = [
    'English',
    'Hindi',
    'Urdu',
    'Chinese',
    'Bahasa Indonesia',
    'Vietnamese',
    'Bengali',
    'Russian',
    'Spanish',
    'Turkish',
  ];

  // ============================================================
  // DEFAULTS
  // ============================================================

  static const double defaultFanBalance = 0.0;

  static const double defaultAfamBalance = 0.0;

  static const double defaultMiningRate = 0.2;

  static const int defaultActiveReferrals = 0;

  static const int defaultDailyAdsWatched = 0;

  static const double defaultAdBoost = 0.0;

  // ============================================================
  // CALCULATIONS
  // ============================================================

  static double miningRate({
    int activeReferrals = 0,
    int adsWatched = 0,
  }) {
    final safeReferrals =
        activeReferrals < 0 ? 0 : activeReferrals;

    final safeAds =
        adsWatched.clamp(0, maxDailyAds);

    return baseMiningRate +
        (safeReferrals * referralMiningBoost) +
        (safeAds * adBoostPerAd);
  }

  static double referralMiningRate(
    int activeReferrals,
  ) {
    final safeReferrals =
        activeReferrals < 0 ? 0 : activeReferrals;

    return baseMiningRate +
        (safeReferrals * referralMiningBoost);
  }

  static double adBoostFor(
    int adsWatched,
  ) {
    final safeAds =
        adsWatched.clamp(0, maxDailyAds);

    return safeAds * adBoostPerAd;
  }

  static double dailyMiningReward({
    required double miningRate,
  }) {
    return miningRate * miningHours;
  }
}
