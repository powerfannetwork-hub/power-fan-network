// lib/globals/app_constants.dart

class AppConstants {
  AppConstants._();

  // ============================================================
  // POWER FAN NETWORK
  // ============================================================

  static const String appName = 'POWER FAN NETWORK';
  static const String brandName = 'POWER FAN';
  static const String originalCoinName = 'AFAM';
  static const String miningCoinName = 'FAN';

  // ============================================================
  // SUPABASE
  // ============================================================

  static const String supabaseUrl =
      'https://fihtqejqpycuvebufjhc.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

  static const String apiBaseUrl =
      'https://fihtqejqpycuvebufjhc.supabase.co/functions/v1/api';

  // ============================================================
  // MINING
  // ============================================================

  static const double baseMiningRate = 0.2;

  static const double referralMiningBoost = 0.02;

  static const double adBoostPerAd = 0.1;

  static const int maxDailyAds = 7;

  static const double maxAdBoost = 0.7;

  static const int miningHours = 24;

  static const int miningDurationHours = 24;

  // ============================================================
  // REFERRAL
  // ============================================================

  static const double newUserReferralReward = 20.0;

  static const double inviterReferralReward = 5.0;

  // ============================================================
  // DAILY SOCIAL REWARD
  // ============================================================

  static const double dailySocialReward = 10.0;

  // ============================================================
  // KYC
  // ============================================================

  static const int kyc1Days = 14;

  static const int kyc2Days = 30;

  static const int kyc2Referrals = 3;

  // ============================================================
  // WALLET
  // ============================================================

  static const String walletStatus = 'COMING SOON';

  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String accessTokenKey =
      'power_fan_access_token';

  static const String userIdKey =
      'power_fan_user_id';

  static const String userDataKey =
      'power_fan_user_data';

  // ============================================================
  // API ENDPOINTS
  // ============================================================

  static const String healthEndpoint =
      '/health';

  static const String dashboardEndpoint =
      '/dashboard';

  static const String referralsEndpoint =
      '/referrals';

  static const String applyReferralEndpoint =
      '/referral/apply';

  static const String miningStartEndpoint =
      '/mining/start';

  static const String miningClaimEndpoint =
      '/mining/claim';

  static const String miningAdEndpoint =
      '/mining/ad';

  static const String socialClaimEndpoint =
      '/social/claim';

  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const int primaryColorValue =
      0xFF3B159B;

  static const int deepPurpleColorValue =
      0xFF241064;

  static const int greenColorValue =
      0xFF159B61;

  static const int lightBackgroundColorValue =
      0xFFF8F8FC;

  // ============================================================
  // APP SETTINGS
  // ============================================================

  static const String appVersion =
      '1.0.0';

  static const bool firebaseAuthenticationEnabled =
      false;

  static const bool supabaseAuthenticationEnabled =
      true;

  static const bool customJwtAuthenticationEnabled =
      false;

  // ============================================================
  // SUPPORTED LANGUAGES
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
}
