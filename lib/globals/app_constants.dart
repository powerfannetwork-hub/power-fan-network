import 'package:flutter/material.dart';

class AppConfig {
  AppConfig._();

  // ============================================================
  // APP IDENTITY
  // ============================================================

  static const String appName = 'POWER FAN NETWORK';
  static const String brandName = 'POWER FAN';

  static const String miningCoinName = 'FAN';
  static const String originalCoinName = 'AFAM';

  // ============================================================
  // SUPABASE
  // ============================================================

  static const String supabaseUrl =
      'https://fihtqejqpycuvebufjhc.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_KVf397QgYsgFi_D33mCcjw_5lV1ycCr';

  // ============================================================
  // MINING
  // ============================================================

  /// Base mining rate before any bonuses.
  static const double baseMiningRate = 0.2;

  /// Mining session duration.
  static const int miningHours = 24;
  static const int miningDurationHours = 24;

  /// Duration in minutes.
  static const int miningDurationMinutes = 24 * 60;

  /// Duration in seconds.
  static const int miningDurationSeconds = 24 * 60 * 60;

  // ============================================================
  // REWARDED ADS
  // ============================================================

  /// Every successfully completed rewarded ad adds +0.1 FAN/H.
  static const double adBoostPerAd = 0.1;

  /// Maximum rewarded ads during ONE 24-hour mining session.
  static const int maxAdsPerSession = 7;

  /// Maximum possible ad boost during ONE mining session.
  static const double maxAdBoost = 0.7;

  /// Backward-compatible name for code that still references it.
  static const int maxDailyAds = maxAdsPerSession;

  /// Backward-compatible maximum boost name.
  static const double maximumAdBoost = maxAdBoost;

  // ============================================================
  // REFERRALS
  // ============================================================

  /// Reward given to a new user who joins with a valid referral.
  static const double newUserReferralReward = 20.0;

  /// Reward given to the inviter for each successful referral.
  static const double inviterReferralReward = 5.0;

  /// Mining-rate bonus for every active referral.
  static const double referralMiningBoost = 0.02;

  /// Backward-compatible name.
  static const double miningBonusPerReferral = referralMiningBoost;

  // ============================================================
  // DAILY SOCIAL TASK
  // ============================================================

  /// Daily social-media reward.
  static const double dailySocialReward = 10.0;

  // ============================================================
  // KYC
  // ============================================================

  /// KYC 1 requires 14 consecutive daily check-ins.
  static const int kyc1Days = 14;

  /// KYC 2 requires 60 consecutive daily check-ins.
  static const int kyc2Days = 60;

  /// KYC 2 requires 5 active referrals.
  static const int kyc2Referrals = 5;

  /// KYC 1 verification method.
  static const String kyc1VerificationMethod = 'Face Verification';

  /// KYC 2 verification method.
  static const String kyc2VerificationMethod = 'Face Verification';

  /// Migration status.
  static const String migrationStatus = 'COMING SOON';

  /// Planned migration period.
  static const String migrationPeriod = '2027 Q1';

  // ============================================================
  // WALLET
  // ============================================================

  static const String walletStatus = 'COMING SOON';

  // ============================================================
  // SUPPORTED LANGUAGES
  // ============================================================

  static const List<String> supportedLanguages = <String>[
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
  // STORAGE KEYS
  // ============================================================

  static const String storageUserId = 'power_fan_user_id';
  static const String storageReferralCode = 'power_fan_referral_code';
  static const String storageSelectedLanguage =
      'power_fan_selected_language';
  static const String storageNotificationsEnabled =
      'power_fan_notifications_enabled';

  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const Color primaryColor = Color(0xFF3B159B);
  static const Color deepPurple = Color(0xFF241064);
  static const Color lightBackground = Color(0xFFF8F8FC);
  static const Color green = Color(0xFF159B61);

  // ============================================================
  // AUTHENTICATION ARCHITECTURE
  // ============================================================

  /// Firebase Authentication is NOT used.
  static const bool firebaseAuthenticationEnabled = false;

  /// Authentication is handled through the current account system.
  static const bool supabaseAuthenticationEnabled = true;

  /// Custom JWT authentication is not used directly by the Flutter client.
  static const bool customJwt = false;

  // ============================================================
  // SECURITY
  // ============================================================

  /// One account should be associated with one trusted device.
  static const bool oneAccountOneDevice = true;

  // ============================================================
  // GENERAL APP STATUS
  // ============================================================

  static const String comingSoon = 'COMING SOON';

  static const String activeStatus = 'ACTIVE';
  static const String inactiveStatus = 'INACTIVE';

  static const String miningStatusActive = 'MINING';
  static const String miningStatusStopped = 'STOPPED';
  static const String miningStatusReady = 'READY';

  // ============================================================
  // SOCIAL MEDIA
  // ============================================================

  static const String facebookUrl =
      'https://www.facebook.com/share/18ipQKYcCV/';

  static const String youtubeUrl =
      'https://youtube.com/@powerfannetwork?si=yHAa0uXznTHB4SfN';

  static const String tiktokUrl =
      'https://www.tiktok.com/@power.fan.network?_r=1&_t=ZP-98wsX6qxjV0';

  static const String xUrl =
      'https://x.com/Powerfannetwork';

  static const String telegramUrl =
      'https://t.me/PowerFannetwork';

  static const String instagramUrl =
      'https://www.instagram.com/powerfannetwok/';

  // ============================================================
  // APP LOVIN
  // ============================================================

  /// AppLovin SDK key.
  ///
  /// Keep this value empty until the real production SDK key is available.
  static const String appLovinSdkKey = '';

  /// Rewarded ad unit ID.
  ///
  /// Keep this value empty until the real Android rewarded ad unit is available.
  static const String appLovinRewardedAdUnitId = '';

  // ============================================================
  // API / RPC NAMES
  // ============================================================

  static const String rpcGetUserMiningRate = 'get_user_mining_rate';
  static const String rpcStartMining = 'start_mining';
  static const String rpcGetActiveMining = 'get_active_mining';
  static const String rpcClaimMining = 'claim_mining';
  static const String rpcRecordRewardedAd = 'record_rewarded_ad';
  static const String rpcVerifyRewardedAd = 'verify_rewarded_ad';
  static const String rpcDailyCheckin = 'daily_checkin';
  static const String rpcCompleteDailySocialTask =
      'complete_daily_social_task';
  static const String rpcGetDashboard = 'get_dashboard';

  // ============================================================
  // UI LABELS
  // ============================================================

  static const String fanBalanceLabel = 'FAN Balance';
  static const String afamBalanceLabel = 'AFAM Balance';

  static const String startMiningLabel = 'START MINING';
  static const String claimMiningLabel = 'CLAIM MINING';

  static const String watchAdLabel = 'WATCH AD';
  static const String adsWatchedSessionLabel =
      'Ads watched this session';

  static const String dailyCheckinLabel = 'DAILY CHECK-IN';
  static const String dailySocialTaskLabel = 'DAILY SOCIAL TASK';

  static const String referralLabel = 'REFERRALS';
  static const String activeReferralsLabel = 'Active Referrals';

  static const String kycLabel = 'KYC';
  static const String faceVerificationLabel = 'Face Verification';

  static const String walletLabel = 'WALLET';
  static const String migrationLabel = 'MIGRATION';

  // ============================================================
  // DEFAULT VALUES
  // ============================================================

  static const double defaultFanBalance = 0.0;
  static const double defaultAfamBalance = 0.0;

  static const int defaultAdsWatched = 0;
  static const int defaultActiveReferrals = 0;
  static const int defaultCheckInDays = 0;

  static const bool defaultMiningActive = false;
  static const bool defaultFaceVerified = false;
  static const bool defaultKyc1Verified = false;
  static const bool defaultKyc2Eligible = false;
}
