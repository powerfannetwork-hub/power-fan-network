class AppConstants {
  // ============================================================
  // APP INFORMATION
  // ============================================================

  static const String appName = 'POWER FAN NETWORK';
  static const String brandPrefix = 'AFAM';

  // ============================================================
  // MINING
  // ============================================================

  /// Base FAN earned per hour.
  static const double baseMiningRate = 0.20;

  /// Extra mining rate for every active referral.
  static const double activeReferralMiningBoost = 0.02;

  /// Optional reward rate related to advertisements.
  static const double adBoostRate = 0.10;

  /// Maximum rewarded ads a user can complete per day.
  static const int maxDailyAds = 7;

  /// One mining session lasts 24 hours.
  static const int miningSessionHours = 24;

  /// Milliseconds in one hour.
  static const int millisecondsPerHour = 60 * 60 * 1000;

  /// Complete mining session duration in milliseconds.
  static const int miningSessionMilliseconds =
      miningSessionHours * millisecondsPerHour;

  // ============================================================
  // MINING STATUS
  // ============================================================

  static const String miningStatusReady = 'ready';

  static const String miningStatusMining = 'mining';

  static const String miningStatusCompleted = 'completed';

  // ============================================================
  // REWARDS
  // ============================================================

  static const double newUserReward = 20.0;

  static const double referralReward = 5.0;

  static const double dailySocialTaskReward = 10.0;

  static const double dailyCheckInReward = 0.5;

  // ============================================================
  // DAILY CHECK-IN
  // ============================================================

  static const int checkInRewardDays = 1;

  // ============================================================
  // KYC
  // ============================================================

  static const int kyc1CheckInDays = 14;

  static const int kyc2CheckInDays = 30;

  static const int kyc2RequiredReferrals = 3;

  static const bool kyc3Locked = true;

  // KYC statuses
  static const String kycStatusLocked = 'locked';

  static const String kycStatusAvailable = 'available';

  static const String kycStatusPending = 'pending';

  static const String kycStatusVerified = 'verified';

  static const String kycStatusRejected = 'rejected';

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  static const bool miningCompletionNotification = true;

  static const bool allowReferralReminderNotification = true;

  // ============================================================
  // OFFICIAL SOCIAL MEDIA
  // ============================================================

  static const String facebookUrl =
      'https://www.facebook.com/share/1BiQPKyCV/';

  static const String youtubeUrl =
      'https://youtube.com/@powerfannetwork?si=YHiAaOUxzNTHB4Sfn';

  static const String tiktokUrl =
      'https://www.tiktok.com/@power.fan.network?_r=1&_t=ZS-9BwsX6qxjV0';

  static const String xTwitterUrl =
      'https://x.com/Powerfannetwork';

  static const String telegramUrl =
      'https://t.me/Powerfannetwork';

  static const String instagramUrl =
      'https://www.instagram.com/powerfannetwork/';

  // ============================================================
  // WEBSITE
  // ============================================================

  static const String websiteUrl =
      'https://imaginative-meerkat-7727ed.netlify.app';

  // ============================================================
  // WALLET
  // ============================================================

  /// Wallet is disabled until the real wallet/backend system
  /// is connected.
  static const bool walletEnabled = false;

  // ============================================================
  // MIGRATION
  // ============================================================

  /// Migration is disabled until the migration system is ready.
  static const bool migrationEnabled = false;

  // ============================================================
  // APP FEATURES
  // ============================================================

  static const bool referralsEnabled = true;

  static const bool dailyCheckInEnabled = true;

  static const bool socialTaskEnabled = true;

  static const bool rewardedAdsEnabled = true;

  static const bool kycEnabled = true;

  // ============================================================
  // SECURITY / DEVICE
  // ============================================================

  static const bool deviceWarningEnabled = true;

  // ============================================================
  // DISPLAY
  // ============================================================

  static const String tokenSymbol = 'FAN';

  static const String tokenName = 'FAN';

  static const String currencyName = 'FAN';

  // ============================================================
  // PRIVATE CONSTRUCTOR
  // ============================================================

  AppConstants._();
}
