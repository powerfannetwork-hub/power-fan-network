class AppConstants {
  // ============================================================
  // APP INFORMATION
  // ============================================================

  static const String appName = 'POWER FAN NETWORK';
  static const String appBrand = 'POWER FAN NETWORK';
  static const String tokenName = 'FAN';
  static const String futureTokenName = 'AFAM';
  static const String brandPrefix = 'AFAM';

  // ============================================================
  // MINING SYSTEM
  // ============================================================

  /// Base mining speed for every user.
  static const double baseMiningRate = 0.20;

  /// Mining session duration.
  static const int miningSessionHours = 24;

  /// Number of milliseconds in one hour.
  static const int millisecondsPerHour = 3600000;

  /// Number of milliseconds in one mining session.
  static const int miningSessionMilliseconds =
      miningSessionHours * millisecondsPerHour;

  // ============================================================
  // ACTIVE REFERRAL MINING BOOST
  // ============================================================

  /// Every active referral adds +0.02 FAN/H.
  ///
  /// Example:
  /// 0 active referrals = 0.20 FAN/H
  /// 1 active referral  = 0.22 FAN/H
  /// 2 active referrals = 0.24 FAN/H
  /// 3 active referrals = 0.26 FAN/H
  static const double activeReferralMiningBoost = 0.02;

  /// There is intentionally no hard limit here.
  /// Every verified active referral can increase the mining rate.
  static const bool unlimitedActiveReferralBoost = true;

  // ============================================================
  // REWARDED ADS / MINING BOOST
  // ============================================================

  /// One successfully completed rewarded ad adds +0.10 FAN/H.
  static const double adBoostRate = 0.10;

  /// Maximum rewarded ads per day.
  static const int maxDailyAds = 7;

  /// User does NOT have to watch all 7 ads.
  static const bool adsAreOptional = true;

  /// Ad reward is granted only after the ad is successfully completed
  /// and verified.
  static const bool requireCompletedRewardedAd = true;

  // ============================================================
  // NEW USER BONUS
  // ============================================================

  /// Every successfully created new account receives 20 FAN.
  static const double newUserWelcomeBonus = 20.0;

  // ============================================================
  // REFERRAL SYSTEM
  // ============================================================

  /// Reward for the person who successfully invites a new user.
  static const double successfulReferralReward = 5.0;

  /// A referral must be a real/verified account before rewards
  /// are considered successful.
  static const bool referralMustBeVerified = true;

  /// Referral reward must be processed server-side.
  static const bool referralRewardServerVerified = true;

  /// Active referral means the referred user is currently mining.
  static const bool activeReferralMeansMining = true;

  /// User can send a reminder notification to an inactive referral.
  static const bool allowReferralMiningReminder = true;

  // ============================================================
  // DAILY SOCIAL MEDIA TASK
  // ============================================================

  /// Reward for successfully completing the daily social task.
  static const double dailySocialTaskReward = 10.0;

  /// The social task can only be claimed once per day.
  static const bool socialTaskOncePerDay = true;

  /// User must complete the required actions before claiming.
  static const bool requireSocialTaskVerification = true;

  /// Required social actions.
  static const bool requireSocialFollow = true;
  static const bool requireSocialLike = true;
  static const bool requireSocialComment = true;

  /// Claim must not be available if required actions are not completed.
  static const bool blockInvalidSocialClaim = true;

  // ============================================================
  // DAILY CHECK-IN
  // ============================================================

  /// Daily check-in reward.
  static const double dailyCheckInReward = 0.5;

  /// KYC 1 eligibility requires a 14-day check-in streak.
  static const int kyc1CheckInDays = 14;

  /// KYC 2 requires a 30-day check-in streak.
  static const int kyc2CheckInDays = 30;

  // ============================================================
  // KYC SYSTEM
  // ============================================================

  /// KYC 1 uses face verification after eligibility requirements.
  static const String kyc1Name = 'KYC 1';
  static const String kyc1Method = 'FACE_VERIFICATION';

  /// KYC 2 requires referrals, check-in and government ID.
  static const String kyc2Name = 'KYC 2';
  static const String kyc2Method = 'GOVERNMENT_ID';

  /// Number of successful referrals required for KYC 2.
  static const int kyc2RequiredReferrals = 3;

  /// KYC 3 is locked for now.
  static const String kyc3Name = 'KYC 3';
  static const String kyc3Method = 'BIOMETRIC';
  static const bool kyc3Locked = true;

  /// KYC 3 can only be enabled by the admin/server.
  static const bool kyc3AdminControlled = true;

  // ============================================================
  // MIGRATION
  // ============================================================

  /// Current mining coin.
  static const String currentCoin = 'FAN';

  /// Future migrated coin.
  static const String migrationCoin = 'AFAM';

  /// Migration is controlled by the server/admin.
  static const bool migrationServerControlled = true;

  /// Migration is not available until officially enabled.
  static const bool migrationEnabled = false;

  // ============================================================
  // WALLET
  // ============================================================

  /// Wallet is currently displayed as Coming Soon.
  static const bool walletEnabled = false;

  /// Withdrawal is currently disabled.
  static const bool withdrawalEnabled = false;

  static const String walletComingSoonText = 'COMING SOON';

  // ============================================================
  // SECURITY
  // ============================================================

  /// One account is allowed per device.
  static const bool oneAccountPerDevice = true;

  /// Multiple-account attempts should trigger a warning.
  static const bool multipleAccountWarningEnabled = true;

  /// Suspicious device activity can be flagged.
  static const bool suspiciousDeviceDetectionEnabled = true;

  /// Server-side validation is required for important rewards.
  static const bool serverSideRewardValidation = true;

  /// Referral rewards must not depend only on local Flutter state.
  static const bool secureReferralRewards = true;

  /// Mining balance should not be trusted from the client alone.
  static const bool secureMiningBalance = true;

  /// KYC status must be controlled by backend/admin.
  static const bool secureKycStatus = true;

  /// Migration must be controlled by backend/admin.
  static const bool secureMigration = true;

  /// Ad rewards must be verified.
  static const bool secureAdRewards = true;

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  /// Notify user when mining session finishes.
  static const bool miningCompletionNotification = true;

  /// Notify user when a referral becomes inactive.
  static const bool referralInactiveNotification = true;

  /// Allow reminders to inactive referrals.
  static const bool referralReminderNotification = true;

  /// Push notifications can work even when app is closed.
  static const bool pushNotificationsEnabled = true;

  // ============================================================
  // SUPPORTED LANGUAGES
  // ============================================================

  static const List<String> supportedLanguageCodes = [
    'en',
    'zh',
    'hi',
    'es',
    'ru',
    'tr',
    'id',
    'ko',
    'vi',
    'pt',
  ];

  static const List<String> supportedLanguageNames = [
    'English',
    'Chinese',
    'Hindi',
    'Spanish',
    'Russian',
    'Turkish',
    'Indonesian',
    'Korean',
    'Vietnamese',
    'Portuguese',
  ];

  // ============================================================
  // SOCIAL MEDIA
  // ============================================================

  static const String facebookUrl =
      'https://www.facebook.com/share/18ipQKYcCV/';

  static const String youtubeUrl =
      'https://youtube.com/@powerfannetwork?si=yHAa0uXznTHB4SfN';

  static const String tiktokUrl =
      'https://www.tiktok.com/@power.fan.network?_r=1&_t=ZP-98wsX6qxjV0';

  static const String xTwitterUrl =
      'https://x.com/Powerfannetwork';

  static const String telegramUrl =
      'https://t.me/PowerFannetwork';

  static const String instagramUrl =
      'https://www.instagram.com/powerfannetwok/';

  static const String officialWebsite =
      'https://powerfan.network';

  // ============================================================
  // SOCIAL TASK CONFIGURATION
  // ============================================================

  /// Official platforms used by the daily task.
  static const List<String> socialPlatforms = [
    'X',
    'Telegram',
    'Instagram',
    'YouTube',
  ];

  /// Text shown to users.
  static const String socialTaskTitle =
      'Follow us on social media';

  static const String socialTaskDescription =
      'Follow, like and comment to earn FAN';

  static const String socialTaskClaimText =
      'CLAIM 10 FAN';

  // ============================================================
  // MINING STATUS
  // ============================================================

  static const String miningStatusReady = 'READY';
  static const String miningStatusMining = 'MINING';
  static const String miningStatusCompleted = 'COMPLETED';

  // ============================================================
  // KYC STATUS
  // ============================================================

  static const String kycStatusLocked = 'LOCKED';
  static const String kycStatusAvailable = 'AVAILABLE';
  static const String kycStatusPending = 'PENDING';
  static const String kycStatusVerified = 'VERIFIED';
  static const String kycStatusRejected = 'REJECTED';

  // ============================================================
  // APP UI TEXT
  // ============================================================

  static const String homeTitle = 'POWER FAN NETWORK';
  static const String homeSubtitle = 'Mine FAN. Earn More';

  static const String balanceTitle = 'BALANCE';

  static const String startMiningText = 'START MINING';
  static const String miningRateText = 'MINING RATE';
  static const String sessionTimeText = 'SESSION TIME';

  static const String boostAdsTitle =
      'BOOST BY WATCHING ADS';

  static const String watchAdText = 'WATCH AD';

  static const String dailyTaskTitle = 'DAILY TASK';

  static const String kycTitle = 'KYC VERIFICATION';

  static const String referralTitle = 'REFERRAL';

  static const String walletTitle = 'WALLET';

  static const String settingsTitle = 'SETTINGS';

  // ============================================================
  // CURRENCY DISPLAY
  // ============================================================

  /// FAN currently has no official USD value.
  static const double usdPerFan = 0.00;

  static const String currencyApproximation = '≈';

  // ============================================================
  // DEVELOPMENT / TESTING
  // ============================================================

  /// Keep this true during development.
  /// Change only when preparing production release.
  static const bool isDevelopment = true;

  /// AdMob test ads should be used during development.
  static const bool useAdMobTestAds = true;

  /// Never give ad rewards without successful ad completion.
  static const bool neverRewardIncompleteAd = true;

  // ============================================================
  // FIREBASE / BACKEND SECURITY
  // ============================================================

  static const bool firebaseAuthenticationEnabled = true;
  static const bool firestoreEnabled = true;
  static const bool firebaseStorageEnabled = true;
  static const bool firebaseAnalyticsEnabled = true;
  static const bool firebaseCrashlyticsEnabled = true;
  static const bool firebaseMessagingEnabled = true;
  static const bool firebaseAppCheckEnabled = true;

  // ============================================================
  // ACCOUNT LINKING
  // ============================================================

  /// Google, Facebook and Phone can belong to one account.
  static const bool accountLinkingEnabled = true;

  /// Prevent creating duplicate accounts when the user links
  /// another authentication method.
  static const bool preventDuplicateLinkedAccounts = true;

  // ============================================================
  // ADMIN
  // ============================================================

  /// Admin controls important server-side operations.
  static const bool adminSystemEnabled = true;

  static const bool adminCanManageUsers = true;
  static const bool adminCanReviewKyc = true;
  static const bool adminCanReviewReferrals = true;
  static const bool adminCanReviewMining = true;
  static const bool adminCanManageTasks = true;
  static const bool adminCanSendNotifications = true;
  static const bool adminCanFlagAccounts = true;
  static const bool adminCanSuspendAccounts = true;
  static const bool adminCanEnableKyc3 = true;
  static const bool adminCanControlMigration = true;
}
