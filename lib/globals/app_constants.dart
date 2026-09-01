// ============================================================
// POWER FAN NETWORK
// APP CONSTANTS
// ============================================================

class AppConstants {
  AppConstants._();

  // ==========================================================
  // APP
  // ==========================================================

  static const String appName = 'POWER FAN NETWORK';

  static const String appShortName = 'POWER FAN';

  static const String coinMiningName = 'FAN';

  static const String coinOriginalName = 'AFAM';

  // ==========================================================
  // MINING
  // ==========================================================

  static const double baseMiningRate = 0.2;

  static const double adBoostPerAd = 0.1;

  static const int maxDailyAds = 7;

  static const double maxAdBoost = 0.7;

  static const int miningHours = 24;

  static const int miningDurationHours = 24;

  // ==========================================================
  // REFERRAL
  // ==========================================================

  static const double newUserReferralReward = 20.0;

  static const double inviterReferralReward = 5.0;

  static const double referralMiningBoost = 0.02;

  // ==========================================================
  // SOCIAL
  // ==========================================================

  static const double dailySocialReward = 10.0;

  // ==========================================================
  // WELCOME
  // ==========================================================

  static const double welcomeReward = 0.0;

  // ==========================================================
  // KYC
  // ==========================================================

  static const int kyc1Days = 14;

  static const int kyc2Days = 30;

  static const int kyc2Referrals = 3;

  // ==========================================================
  // WALLET
  // ==========================================================

  static const String walletStatus = 'COMING SOON';

  // ==========================================================
  // COLORS
  // ==========================================================

  static const int primaryColorValue = 0xFF3B159B;

  static const int deepPurpleColorValue = 0xFF241064;

  static const int lightBackgroundColorValue = 0xFFF8F8FC;

  static const int greenColorValue = 0xFF159B61;

  // ==========================================================
  // STORAGE
  // ==========================================================

  static const String appLanguageKey =
      'power_fan_language';

  static const String onboardingKey =
      'power_fan_onboarding_completed';

  // ==========================================================
  // LANGUAGES
  // ==========================================================

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

  // ==========================================================
  // SOCIAL TASK
  // ==========================================================

  static const String officialFacebook =
      'https://www.facebook.com/';

  static const String officialTelegram =
      'https://t.me/';

  static const String officialX =
      'https://x.com/';

  static const String officialYouTube =
      'https://www.youtube.com/';

  // ==========================================================
  // API
  // ==========================================================

  static const String apiStatusEndpoint =
      '/api/status';

  static const String apiHealthEndpoint =
      '/health';

  static const String apiDashboardEndpoint =
      '/api/dashboard';

  // ==========================================================
  // SECURITY
  // ==========================================================

  static const bool oneAccountOneDevice = true;

  static const bool firebaseAuthenticationEnabled =
      false;

  static const bool customBackendAuthentication =
      true;

  // ==========================================================
  // MESSAGES
  // ==========================================================

  static const String miningStartedMessage =
      'Mining started successfully.';

  static const String miningClaimedMessage =
      'Mining reward claimed successfully.';

  static const String miningAlreadyActiveMessage =
      'Mining is already active.';

  static const String miningNotFinishedMessage =
      'Mining session has not ended yet.';

  static const String maxAdsMessage =
      'You have reached the maximum of 7 rewarded ads today.';
}
