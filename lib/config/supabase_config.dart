// ============================================================
// POWER FAN NETWORK - SUPABASE CONFIGURATION
// ============================================================
// Backend: Supabase
// Authentication: Supabase Auth
// Database: Supabase PostgreSQL
// Firebase: NOT USED
// Custom Express Backend: NOT USED
// ============================================================

class SupabaseConfig {
  SupabaseConfig._();

  // ==========================================================
  // SUPABASE PROJECT
  // ==========================================================

  static const String url =
      'https://fihtqejqpycuvebufjhc.supabase.co';

  // ==========================================================
  // SUPABASE PUBLISHABLE KEY
  // ==========================================================

  static const String publishableKey =
      'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

  // ==========================================================
  // APP
  // ==========================================================

  static const String appName =
      'POWER FAN NETWORK';

  static const String miningCoin =
      'FAN';

  static const String originalCoin =
      'AFAM';

  // ==========================================================
  // MINING RULES
  // ==========================================================

  static const double baseMiningRate =
      0.2;

  static const double adBoostPerAd =
      0.1;

  static const int maxDailyAds =
      7;

  static const double maxAdBoost =
      0.7;

  static const int miningSessionHours =
      24;

  // ==========================================================
  // REFERRAL RULES
  // ==========================================================

  static const double newUserReferralReward =
      20.0;

  static const double inviterReferralReward =
      5.0;

  static const double referralMiningBoost =
      0.02;

  // ==========================================================
  // SOCIAL TASK
  // ==========================================================

  static const double dailySocialReward =
      10.0;

  // ==========================================================
  // KYC RULES
  // ==========================================================

  static const int kyc1CheckInDays =
      14;

  static const int kyc2CheckInDays =
      30;

  static const int kyc2RequiredReferrals =
      3;

  // ==========================================================
  // WALLET
  // ==========================================================

  static const String walletStatus =
      'COMING SOON';

  // ==========================================================
  // SECURITY
  // ==========================================================

  static const bool oneAccountPerDevice =
      true;

  // ==========================================================
  // VALIDATION
  // ==========================================================

  static bool get isConfigured {
    return url.isNotEmpty &&
        publishableKey.isNotEmpty &&
        !url.contains('YOUR_') &&
        !publishableKey.contains('YOUR_');
  }
}
