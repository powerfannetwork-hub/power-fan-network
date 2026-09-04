import 'package:flutter/material.dart';

/// POWER FAN NETWORK
/// Central localization file for the whole application.
///
/// Supported languages:
/// English, Chinese, Spanish, French, Arabic, Hindi,
/// Bengali, Russian, Turkish, Indonesian.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale('es'),
    Locale('fr'),
    Locale('ar'),
    Locale('hi'),
    Locale('bn'),
    Locale('ru'),
    Locale('tr'),
    Locale('id'),
  ];

  static const List<LanguageOption> languages = [
    LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
    ),
    LanguageOption(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
    ),
    LanguageOption(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
    ),
    LanguageOption(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
    ),
    LanguageOption(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
    ),
    LanguageOption(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
    ),
    LanguageOption(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
    ),
    LanguageOption(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
    ),
    LanguageOption(
      code: 'tr',
      name: 'Turkish',
      nativeName: 'Türkçe',
    ),
    LanguageOption(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
    ),
  ];

  static AppLocalizations of(BuildContext context) {
    final result =
        Localizations.of<AppLocalizations>(context, AppLocalizations);

    return result ?? const AppLocalizations(Locale('en'));
  }

  String get languageCode => locale.languageCode;

  bool get isArabic => languageCode == 'ar';

  String _t(String key) {
    final language = _translations[languageCode] ?? _translations['en']!;
    return language[key] ?? _translations['en']![key] ?? key;
  }

  // ---------------------------------------------------------------------------
  // APP
  // ---------------------------------------------------------------------------

  String get appName => _t('appName');
  String get brandName => _t('brandName');
  String get mineFan => _t('mineFan');
  String get powerFanNetwork => _t('powerFanNetwork');
  String get fan => _t('fan');
  String get afam => _t('afam');

  // ---------------------------------------------------------------------------
  // LANGUAGE
  // ---------------------------------------------------------------------------

  String get language => _t('language');
  String get selectLanguage => _t('selectLanguage');
  String get chooseLanguage => _t('chooseLanguage');
  String get languageChanged => _t('languageChanged');

  // ---------------------------------------------------------------------------
  // LOGIN / REGISTER
  // ---------------------------------------------------------------------------

  String get login => _t('login');
  String get register => _t('register');
  String get signIn => _t('signIn');
  String get signUp => _t('signUp');
  String get welcomeBack => _t('welcomeBack');
  String get createAccount => _t('createAccount');
  String get loginToContinue => _t('loginToContinue');
  String get joinPowerFanNetwork => _t('joinPowerFanNetwork');

  String get username => _t('username');
  String get email => _t('email');
  String get password => _t('password');
  String get confirmPassword => _t('confirmPassword');
  String get referralCode => _t('referralCode');
  String get referralCodeOptional => _t('referralCodeOptional');

  String get enterUsername => _t('enterUsername');
  String get enterEmail => _t('enterEmail');
  String get enterPassword => _t('enterPassword');
  String get enterReferralCode => _t('enterReferralCode');

  String get forgotPassword => _t('forgotPassword');
  String get resetPassword => _t('resetPassword');
  String get dontHaveAccount => _t('dontHaveAccount');
  String get alreadyHaveAccount => _t('alreadyHaveAccount');

  String get passwordHidden => _t('passwordHidden');
  String get passwordVisible => _t('passwordVisible');

  // ---------------------------------------------------------------------------
  // HOME
  // ---------------------------------------------------------------------------

  String get home => _t('home');
  String get balance => _t('balance');
  String get fanBalance => _t('fanBalance');
  String get afamBalance => _t('afamBalance');
  String get miningBalance => _t('miningBalance');
  String get originalCoin => _t('originalCoin');

  String get mining => _t('mining');
  String get startMining => _t('startMining');
  String get miningNow => _t('miningNow');
  String get miningStopped => _t('miningStopped');
  String get claimMining => _t('claimMining');
  String get claim => _t('claim');
  String get claimed => _t('claimed');
  String get miningRate => _t('miningRate');
  String get fanPerHour => _t('fanPerHour');
  String get remainingTime => _t('remainingTime');
  String get miningSession => _t('miningSession');
  String get miningEndsIn => _t('miningEndsIn');
  String get miningStarted => _t('miningStarted');
  String get miningCompleted => _t('miningCompleted');

  // ---------------------------------------------------------------------------
  // BOOST / ADS
  // ---------------------------------------------------------------------------

  String get boostMining => _t('boostMining');
  String get boost => _t('boost');
  String get watchAd => _t('watchAd');
  String get adsWatched => _t('adsWatched');
  String get dailyAds => _t('dailyAds');
  String get maxAds => _t('maxAds');
  String get boostPerAd => _t('boostPerAd');
  String get maximumBoost => _t('maximumBoost');
  String get adReward => _t('adReward');
  String get rewardedAd => _t('rewardedAd');
  String get watchAdsToBoost => _t('watchAdsToBoost');
  String get adSystemComingSoon => _t('adSystemComingSoon');

  // ---------------------------------------------------------------------------
  // SOCIAL TASKS
  // ---------------------------------------------------------------------------

  String get dailySocialTask => _t('dailySocialTask');
  String get socialTasks => _t('socialTasks');
  String get dailyTasks => _t('dailyTasks');
  String get completeTask => _t('completeTask');
  String get openTask => _t('openTask');
  String get verifyTask => _t('verifyTask');
  String get claimReward => _t('claimReward');
  String get taskCompleted => _t('taskCompleted');
  String get taskClaimed => _t('taskClaimed');
  String get taskNotReady => _t('taskNotReady');
  String get follow => _t('follow');
  String get comment => _t('comment');
  String get share => _t('share');
  String get checkIn => _t('checkIn');
  String get dailyCheckIn => _t('dailyCheckIn');
  String get socialReward => _t('socialReward');
  String get fanReward => _t('fanReward');

  String get facebook => _t('facebook');
  String get instagram => _t('instagram');
  String get telegram => _t('telegram');
  String get tiktok => _t('tiktok');
  String get twitterX => _t('twitterX');
  String get youtube => _t('youtube');

  // ---------------------------------------------------------------------------
  // REFERRAL
  // ---------------------------------------------------------------------------

  String get referral => _t('referral');
  String get referrals => _t('referrals');
  String get inviteFriends => _t('inviteFriends');
  String get inviteAndEarn => _t('inviteAndEarn');
  String get myReferralCode => _t('myReferralCode');
  String get copyCode => _t('copyCode');
  String get shareCode => _t('shareCode');
  String get copied => _t('copied');

  String get totalReferrals => _t('totalReferrals');
  String get activeReferrals => _t('activeReferrals');
  String get referralEarnings => _t('referralEarnings');
  String get referralReward => _t('referralReward');
  String get newUserReward => _t('newUserReward');
  String get miningBonus => _t('miningBonus');
  String get perActiveReferral => _t('perActiveReferral');

  String get referralHowItWorks => _t('referralHowItWorks');
  String get referralStepOne => _t('referralStepOne');
  String get referralStepTwo => _t('referralStepTwo');
  String get referralStepThree => _t('referralStepThree');

  // ---------------------------------------------------------------------------
  // WALLET
  // ---------------------------------------------------------------------------

  String get wallet => _t('wallet');
  String get afamWallet => _t('afamWallet');
  String get fanMiningBalance => _t('fanMiningBalance');
  String get migration => _t('migration');
  String get migrate => _t('migrate');
  String get migrationComingSoon => _t('migrationComingSoon');
  String get migrationInfo => _t('migrationInfo');
  String get migrationRate => _t('migrationRate');

  String get oneHundredFanOneAfam => _t('oneHundredFanOneAfam');
  String get transactions => _t('transactions');
  String get noTransactions => _t('noTransactions');

  String get send => _t('send');
  String get receive => _t('receive');
  String get sendAfam => _t('sendAfam');
  String get receiveAfam => _t('receiveAfam');
  String get usernameTransactions => _t('usernameTransactions');

  String get walletSecurity => _t('walletSecurity');
  String get walletSecurityMessage => _t('walletSecurityMessage');

  // ---------------------------------------------------------------------------
  // KYC
  // ---------------------------------------------------------------------------

  String get kyc => _t('kyc');
  String get kycVerification => _t('kycVerification');
  String get faceVerification => _t('faceVerification');
  String get faceVerificationComingSoon => _t('faceVerificationComingSoon');
  String get kycComingSoon => _t('kycComingSoon');

  String get kycRequirements => _t('kycRequirements');
  String get kycRequirementOne => _t('kycRequirementOne');
  String get kycRequirementTwo => _t('kycRequirementTwo');
  String get kycRequirementThree => _t('kycRequirementThree');

  String get thirtyDayCheckIn => _t('thirtyDayCheckIn');
  String get thirtyDayBoost => _t('thirtyDayBoost');
  String get kycUnlocked => _t('kycUnlocked');
  String get kycLocked => _t('kycLocked');

  String get startFaceVerification => _t('startFaceVerification');
  String get verificationInProgress => _t('verificationInProgress');
  String get verificationComplete => _t('verificationComplete');
  String get keepFaceVisible => _t('keepFaceVisible');
  String get lookAtCamera => _t('lookAtCamera');
  String get verificationSeconds => _t('verificationSeconds');
  String get secondsRemaining => _t('secondsRemaining');

  String get cameraPermissionRequired => _t('cameraPermissionRequired');
  String get cameraPermissionMessage => _t('cameraPermissionMessage');

  String get oneDeviceOneAccount => _t('oneDeviceOneAccount');
  String get deviceSecurity => _t('deviceSecurity');
  String get livenessWarning => _t('livenessWarning');

  // ---------------------------------------------------------------------------
  // SETTINGS
  // ---------------------------------------------------------------------------

  String get settings => _t('settings');
  String get account => _t('account');
  String get profile => _t('profile');
  String get notifications => _t('notifications');
  String get security => _t('security');
  String get privacy => _t('privacy');
  String get about => _t('about');
  String get help => _t('help');
  String get logout => _t('logout');
  String get logoutConfirm => _t('logoutConfirm');

  // ---------------------------------------------------------------------------
  // COMMON
  // ---------------------------------------------------------------------------

  String get save => _t('save');
  String get cancel => _t('cancel');
  String get close => _t('close');
  String get continueText => _t('continue');
  String get done => _t('done');
  String get refresh => _t('refresh');
  String get retry => _t('retry');
  String get loading => _t('loading');
  String get error => _t('error');
  String get success => _t('success');
  String get failed => _t('failed');
  String get comingSoon => _t('comingSoon');
  String get enabled => _t('enabled');
  String get disabled => _t('disabled');
  String get yes => _t('yes');
  String get no => _t('no');
  String get today => _t('today');
  String get tomorrow => _t('tomorrow');

  // ---------------------------------------------------------------------------
  // MESSAGES
  // ---------------------------------------------------------------------------

  String get loginRequired => _t('loginRequired');
  String get invalidEmail => _t('invalidEmail');
  String get invalidPassword => _t('invalidPassword');
  String get invalidUsername => _t('invalidUsername');
  String get passwordsDoNotMatch => _t('passwordsDoNotMatch');
  String get somethingWentWrong => _t('somethingWentWrong');
  String get networkError => _t('networkError');
  String get noInternet => _t('noInternet');
  String get operationSuccessful => _t('operationSuccessful');

  // ---------------------------------------------------------------------------
  // MINING / SECURITY RULES
  // ---------------------------------------------------------------------------

  String get claimRequiresAd => _t('claimRequiresAd');
  String get claimAdMessage => _t('claimAdMessage');
  String get dailyBoostRequired => _t('dailyBoostRequired');
  String get dailyBoostReminder => _t('dailyBoostReminder');
  String get miningRules => _t('miningRules');
  String get miningRuleClaim24h => _t('miningRuleClaim24h');
  String get miningRuleRateIncrease => _t('miningRuleRateIncrease');
  String get miningRuleDailyBoost => _t('miningRuleDailyBoost');
  String get robotWarning => _t('robotWarning');
  String get unauthorizedActivity => _t('unauthorizedActivity');
  String get accountRestrictionWarning => _t('accountRestrictionWarning');
  String get deviceAlreadyRegistered => _t('deviceAlreadyRegistered');
  String get oneDeviceRuleMessage => _t('oneDeviceRuleMessage');
  String get boostCompleted => _t('boostCompleted');
  String get dailyBoostCompleted => _t('dailyBoostCompleted');

  // ---------------------------------------------------------------------------
  // TRANSLATIONS
  // ---------------------------------------------------------------------------

  static const Map<String, Map<String, String>> _translations = {
    // ========================================================================
    // ENGLISH
    // ========================================================================
    'en': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'Mine FAN',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',

      'language': 'Language',
      'selectLanguage': 'Select Language',
      'chooseLanguage': 'Choose your language',
      'languageChanged': 'Language changed successfully',

      'login': 'Login',
      'register': 'Register',
      'signIn': 'Sign In',
      'signUp': 'Sign Up',
      'welcomeBack': 'Welcome Back',
      'createAccount': 'Create Account',
      'loginToContinue': 'Login to continue',
      'joinPowerFanNetwork': 'Join POWER FAN NETWORK',

      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm Password',
      'referralCode': 'Referral Code',
      'referralCodeOptional': 'Referral Code (Optional)',
      'enterUsername': 'Enter username',
      'enterEmail': 'Enter email',
      'enterPassword': 'Enter password',
      'enterReferralCode': 'Enter referral code',

      'forgotPassword': 'Forgot Password?',
      'resetPassword': 'Reset Password',
      'dontHaveAccount': "Don't have an account?",
      'alreadyHaveAccount': 'Already have an account?',
      'passwordHidden': 'Password hidden',
      'passwordVisible': 'Password visible',

      'home': 'Home',
      'balance': 'Balance',
      'fanBalance': 'FAN Balance',
      'afamBalance': 'AFAM Balance',
      'miningBalance': 'Mining Balance',
      'originalCoin': 'Original Coin',

      'mining': 'Mining',
      'startMining': 'START MINING',
      'miningNow': 'MINING',
      'miningStopped': 'Mining Stopped',
      'claimMining': 'CLAIM MINING',
      'claim': 'Claim',
      'claimed': 'Claimed',
      'miningRate': 'Mining Rate',
      'fanPerHour': 'FAN / Hour',
      'remainingTime': 'Remaining Time',
      'miningSession': 'Mining Session',
      'miningEndsIn': 'Mining ends in',
      'miningStarted': 'Mining started successfully',
      'miningCompleted': 'Mining session completed',

      'boostMining': 'Boost Mining',
      'boost': 'Boost',
      'watchAd': 'WATCH AD',
      'adsWatched': 'Ads Watched',
      'dailyAds': 'Daily Ads',
      'maxAds': 'Max Ads',
      'boostPerAd': '+0.1 FAN/H per ad',
      'maximumBoost': 'Maximum Boost: +0.7 FAN/H',
      'adReward': 'Ad Reward',
      'rewardedAd': 'Rewarded Ad',
      'watchAdsToBoost': 'Watch ads to increase your mining rate',
      'adSystemComingSoon': 'Rewarded Ad system is coming soon',

      'dailySocialTask': 'Daily Social Task',
      'socialTasks': 'Social Tasks',
      'dailyTasks': 'Daily Tasks',
      'completeTask': 'Complete Task',
      'openTask': 'OPEN TASK',
      'verifyTask': 'VERIFY TASK',
      'claimReward': 'CLAIM REWARD',
      'taskCompleted': 'Task completed',
      'taskClaimed': 'Reward already claimed',
      'taskNotReady': 'Complete the required actions first',
      'follow': 'Follow',
      'comment': 'Comment',
      'share': 'Share',
      'checkIn': 'Check In',
      'dailyCheckIn': 'Daily Check-in',
      'socialReward': 'Social Reward',
      'fanReward': 'FAN Reward',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral': 'Referral',
      'referrals': 'Referrals',
      'inviteFriends': 'Invite Friends',
      'inviteAndEarn': 'Invite & Earn',
      'myReferralCode': 'My Referral Code',
      'copyCode': 'COPY CODE',
      'shareCode': 'SHARE CODE',
      'copied': 'Copied',

      'totalReferrals': 'Total Referrals',
      'activeReferrals': 'Active Referrals',
      'referralEarnings': 'Referral Earnings',
      'referralReward': 'Referral Reward',
      'newUserReward': 'New user receives 20 FAN',
      'miningBonus': 'Mining Bonus',
      'perActiveReferral': '+0.02 FAN/H per active referral',

      'referralHowItWorks': 'How Referral Works',
      'referralStepOne': 'Share your referral code with friends.',
      'referralStepTwo': 'Your friend joins using your code.',
      'referralStepThree': 'You receive 5 FAN and mining bonus.',

      'wallet': 'Wallet',
      'afamWallet': 'AFAM Wallet',
      'fanMiningBalance': 'FAN Mining Balance',
      'migration': 'Migration',
      'migrate': 'MIGRATE',
      'migrationComingSoon': 'Migration Coming Soon',
      'migrationInfo': 'Your FAN balance can later be migrated to AFAM.',
      'migrationRate': 'Migration Rate',
      'oneHundredFanOneAfam': '100 FAN = 1 AFAM',
      'transactions': 'Transactions',
      'noTransactions': 'No transactions yet',

      'send': 'SEND',
      'receive': 'RECEIVE',
      'sendAfam': 'Send AFAM',
      'receiveAfam': 'Receive AFAM',
      'usernameTransactions': 'Transactions are made using username.',
      'walletSecurity': 'Wallet Security',
      'walletSecurityMessage':
          'Keep your account secure. Never share your password or verification details.',

      'kyc': 'KYC',
      'kycVerification': 'KYC Verification',
      'faceVerification': 'Face Verification',
      'faceVerificationComingSoon': 'Face Verification Coming Soon',
      'kycComingSoon': 'KYC Coming Soon',
      'kycRequirements': 'KYC Requirements',
      'kycRequirementOne':
          'Complete 30 consecutive days of Daily Check-in.',
      'kycRequirementTwo':
          'Complete at least one boost every day for 30 days.',
      'kycRequirementThree': 'Then complete Face Verification.',
      'thirtyDayCheckIn': '30 Days Daily Check-in',
      'thirtyDayBoost': '30 Days Daily Boost',
      'kycUnlocked': 'KYC Unlocked',
      'kycLocked': 'KYC Locked',

      'startFaceVerification': 'START FACE VERIFICATION',
      'verificationInProgress': 'Verification in progress',
      'verificationComplete': 'Verification completed',
      'keepFaceVisible': 'Keep your face visible in the camera.',
      'lookAtCamera': 'Look directly at the camera.',
      'verificationSeconds': '30-second verification',
      'secondsRemaining': 'seconds remaining',
      'cameraPermissionRequired': 'Camera Permission Required',
      'cameraPermissionMessage':
          'Camera access is required for live face verification.',

      'oneDeviceOneAccount': 'One Device = One Account',
      'deviceSecurity': 'Device Security',
      'livenessWarning':
          'Live camera verification helps protect the network, but a 30-second timer alone is not full biometric liveness detection.',

      'settings': 'Settings',
      'account': 'Account',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'security': 'Security',
      'privacy': 'Privacy',
      'about': 'About',
      'help': 'Help',
      'logout': 'Logout',
      'logoutConfirm': 'Are you sure you want to logout?',

      'save': 'Save',
      'cancel': 'Cancel',
      'close': 'Close',
      'continue': 'Continue',
      'done': 'Done',
      'refresh': 'Refresh',
      'retry': 'Retry',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'failed': 'Failed',
      'comingSoon': 'Coming Soon',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'yes': 'Yes',
      'no': 'No',
      'today': 'Today',
      'tomorrow': 'Tomorrow',

      'loginRequired': 'Please login first.',
      'invalidEmail': 'Please enter a valid email address.',
      'invalidPassword': 'Password must be at least 6 characters.',
      'invalidUsername': 'Please enter a valid username.',
      'passwordsDoNotMatch': 'Passwords do not match.',
      'somethingWentWrong': 'Something went wrong.',
      'networkError': 'Network error. Please try again.',
      'noInternet': 'No internet connection.',
      'operationSuccessful': 'Operation successful.',

      'claimRequiresAd':
          'Watch the rewarded ad before claiming your 24-hour mining reward.',
      'claimAdMessage':
          'After the ad is completed, your mining reward will be claimed and a new 24-hour session will start automatically.',
      'dailyBoostRequired': 'Daily boost required',
      'dailyBoostReminder':
          'Watch at least one boost ad each day to remain active and progress toward KYC.',
      'miningRules': 'Mining Rules',
      'miningRuleClaim24h':
          'Claim your mining reward after each 24-hour session.',
      'miningRuleRateIncrease':
          'Mining rate can only increase through approved boosts and active referrals.',
      'miningRuleDailyBoost':
          'Complete at least one boost every day to remain active.',
      'robotWarning': 'Robot or automated activity is not allowed.',
      'unauthorizedActivity':
          'Unauthorized methods, bots, scripts, or other abusive activity may lead to account restrictions or suspension.',
      'accountRestrictionWarning':
          'We may review and restrict accounts that violate the network rules. Action will be based on the violation.',
      'deviceAlreadyRegistered':
          'This device is already linked to another account.',
      'oneDeviceRuleMessage':
          'One person may use one account on one device. Multiple accounts on the same device are not allowed.',
      'boostCompleted': 'Boost completed successfully.',
      'dailyBoostCompleted': 'Today’s boost is complete.',
    },

    // ========================================================================
    // CHINESE
    // ========================================================================
    'zh': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': '挖掘 FAN',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',

      'language': '语言',
      'selectLanguage': '选择语言',
      'chooseLanguage': '选择您的语言',
      'languageChanged': '语言更改成功',

      'login': '登录',
      'register': '注册',
      'signIn': '登录',
      'signUp': '注册',
      'welcomeBack': '欢迎回来',
      'createAccount': '创建账户',
      'loginToContinue': '登录以继续',
      'joinPowerFanNetwork': '加入 POWER FAN NETWORK',

      'username': '用户名',
      'email': '电子邮箱',
      'password': '密码',
      'confirmPassword': '确认密码',
      'referralCode': '推荐码',
      'referralCodeOptional': '推荐码（可选）',
      'enterUsername': '输入用户名',
      'enterEmail': '输入电子邮箱',
      'enterPassword': '输入密码',
      'enterReferralCode': '输入推荐码',

      'forgotPassword': '忘记密码？',
      'resetPassword': '重置密码',
      'dontHaveAccount': '还没有账户？',
      'alreadyHaveAccount': '已经有账户？',
      'passwordHidden': '密码已隐藏',
      'passwordVisible': '密码可见',

      'home': '首页',
      'balance': '余额',
      'fanBalance': 'FAN 余额',
      'afamBalance': 'AFAM 余额',
      'miningBalance': '挖矿余额',
      'originalCoin': '原始代币',

      'mining': '挖矿',
      'startMining': '开始挖矿',
      'miningNow': '正在挖矿',
      'miningStopped': '挖矿已停止',
      'claimMining': '领取挖矿奖励',
      'claim': '领取',
      'claimed': '已领取',
      'miningRate': '挖矿速度',
      'fanPerHour': 'FAN / 小时',
      'remainingTime': '剩余时间',
      'miningSession': '挖矿周期',
      'miningEndsIn': '挖矿结束时间',
      'miningStarted': '挖矿已成功开始',
      'miningCompleted': '挖矿周期已完成',

      'boostMining': '提升挖矿',
      'boost': '提升',
      'watchAd': '观看广告',
      'adsWatched': '已观看广告',
      'dailyAds': '每日广告',
      'maxAds': '最多广告',
      'boostPerAd': '每个广告 +0.1 FAN/H',
      'maximumBoost': '最高提升：+0.7 FAN/H',
      'adReward': '广告奖励',
      'rewardedAd': '激励广告',
      'watchAdsToBoost': '观看广告提高挖矿速度',
      'adSystemComingSoon': '激励广告系统即将上线',

      'dailySocialTask': '每日社交任务',
      'socialTasks': '社交任务',
      'dailyTasks': '每日任务',
      'completeTask': '完成任务',
      'openTask': '打开任务',
      'verifyTask': '验证任务',
      'claimReward': '领取奖励',
      'taskCompleted': '任务已完成',
      'taskClaimed': '奖励已领取',
      'taskNotReady': '请先完成所需操作',
      'follow': '关注',
      'comment': '评论',
      'share': '分享',
      'checkIn': '签到',
      'dailyCheckIn': '每日签到',
      'socialReward': '社交奖励',
      'fanReward': 'FAN 奖励',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral': '推荐',
      'referrals': '推荐人数',
      'inviteFriends': '邀请朋友',
      'inviteAndEarn': '邀请并赚取',
      'myReferralCode': '我的推荐码',
      'copyCode': '复制代码',
      'shareCode': '分享代码',
      'copied': '已复制',

      'totalReferrals': '总推荐人数',
      'activeReferrals': '活跃推荐人数',
      'referralEarnings': '推荐收益',
      'referralReward': '推荐奖励',
      'newUserReward': '新用户获得 20 FAN',
      'miningBonus': '挖矿加成',
      'perActiveReferral': '每个活跃推荐 +0.02 FAN/H',

      'referralHowItWorks': '推荐方式',
      'referralStepOne': '与朋友分享您的推荐码。',
      'referralStepTwo': '朋友使用您的代码加入。',
      'referralStepThree': '您获得 5 FAN 和挖矿加成。',

      'wallet': '钱包',
      'afamWallet': 'AFAM 钱包',
      'fanMiningBalance': 'FAN 挖矿余额',
      'migration': '迁移',
      'migrate': '迁移',
      'migrationComingSoon': '迁移即将上线',
      'migrationInfo': '您的 FAN 余额以后可以迁移到 AFAM。',
      'migrationRate': '迁移比例',
      'oneHundredFanOneAfam': '100 FAN = 1 AFAM',
      'transactions': '交易记录',
      'noTransactions': '暂无交易',

      'send': '发送',
      'receive': '接收',
      'sendAfam': '发送 AFAM',
      'receiveAfam': '接收 AFAM',
      'usernameTransactions': '交易使用用户名进行。',
      'walletSecurity': '钱包安全',
      'walletSecurityMessage': '请保护账户安全，不要分享密码或验证信息。',

      'kyc': 'KYC',
      'kycVerification': 'KYC 验证',
      'faceVerification': '人脸验证',
      'faceVerificationComingSoon': '人脸验证即将上线',
      'kycComingSoon': 'KYC 即将上线',
      'kycRequirements': 'KYC 要求',
      'kycRequirementOne': '连续完成 30 天每日签到。',
      'kycRequirementTwo': '连续 30 天每天至少完成一次提升。',
      'kycRequirementThree': '然后完成 Face Verification。',
      'thirtyDayCheckIn': '30 天每日签到',
      'thirtyDayBoost': '30 天每日提升',
      'kycUnlocked': 'KYC 已解锁',
      'kycLocked': 'KYC 已锁定',

      'startFaceVerification': '开始人脸验证',
      'verificationInProgress': '验证进行中',
      'verificationComplete': '验证完成',
      'keepFaceVisible': '请让您的脸保持在摄像头中。',
      'lookAtCamera': '请直视摄像头。',
      'verificationSeconds': '30 秒验证',
      'secondsRemaining': '秒剩余',
      'cameraPermissionRequired': '需要摄像头权限',
      'cameraPermissionMessage': '实时人脸验证需要摄像头权限。',

      'oneDeviceOneAccount': '一台设备 = 一个账户',
      'deviceSecurity': '设备安全',
      'livenessWarning':
          '实时摄像头验证有助于保护网络，但仅计时 30 秒并不等于完整的生物识别活体检测。',

      'settings': '设置',
      'account': '账户',
      'profile': '个人资料',
      'notifications': '通知',
      'security': '安全',
      'privacy': '隐私',
      'about': '关于',
      'help': '帮助',
      'logout': '退出登录',
      'logoutConfirm': '确定要退出登录吗？',

      'save': '保存',
      'cancel': '取消',
      'close': '关闭',
      'continue': '继续',
      'done': '完成',
      'refresh': '刷新',
      'retry': '重试',
      'loading': '加载中...',
      'error': '错误',
      'success': '成功',
      'failed': '失败',
      'comingSoon': '即将上线',
      'enabled': '已启用',
      'disabled': '已禁用',
      'yes': '是',
      'no': '否',
      'today': '今天',
      'tomorrow': '明天',

      'loginRequired': '请先登录。',
      'invalidEmail': '请输入有效的电子邮箱。',
      'invalidPassword': '密码至少需要 6 个字符。',
      'invalidUsername': '请输入有效的用户名。',
      'passwordsDoNotMatch': '密码不匹配。',
      'somethingWentWrong': '发生错误。',
      'networkError': '网络错误，请重试。',
      'noInternet': '没有网络连接。',
      'operationSuccessful': '操作成功。',

      'claimRequiresAd': '领取24小时挖矿奖励前，请先观看激励广告。',
      'claimAdMessage':
          '广告完成后，您的挖矿奖励将被领取，并自动开始新的24小时挖矿周期。',
      'dailyBoostRequired': '需要每日提升',
      'dailyBoostReminder':
          '每天至少完成一次广告提升，以保持活跃并推进KYC进度。',
      'miningRules': '挖矿规则',
      'miningRuleClaim24h': '每个24小时挖矿周期结束后领取奖励。',
      'miningRuleRateIncrease':
          '挖矿速度只能通过批准的提升和活跃推荐增加。',
      'miningRuleDailyBoost': '每天至少完成一次提升以保持活跃。',
      'robotWarning': '禁止使用机器人或自动化活动。',
      'unauthorizedActivity':
          '禁止使用未经授权的方法、机器人、脚本或其他滥用行为，否则可能限制或暂停账户。',
      'accountRestrictionWarning':
          '我们可能审核并限制违反网络规则的账户，处理措施将根据违规情况决定。',
      'deviceAlreadyRegistered': '此设备已绑定到其他账户。',
      'oneDeviceRuleMessage':
          '一个人只能在一台设备上使用一个账户。不允许在同一设备上使用多个账户。',
      'boostCompleted': '提升完成。',
      'dailyBoostCompleted': '今天的提升已完成。',
    },

    // ========================================================================
    // SPANISH
    // ========================================================================
    'es': {
    // ========================================================================
    // SPANISH
    // ========================================================================
    'es': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'Minar FAN',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',
      'language': 'Idioma',
      'selectLanguage': 'Seleccionar idioma',
      'chooseLanguage': 'Elige tu idioma',
      'languageChanged': 'Idioma cambiado correctamente',
      'login': 'Iniciar sesión',
      'register': 'Registrarse',
      'signIn': 'Iniciar sesión',
      'signUp': 'Registrarse',
      'welcomeBack': 'Bienvenido de nuevo',
      'createAccount': 'Crear cuenta',
      'loginToContinue': 'Inicia sesión para continuar',
      'joinPowerFanNetwork': 'Únete a POWER FAN NETWORK',
      'username': 'Nombre de usuario',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'confirmPassword': 'Confirmar contraseña',
      'referralCode': 'Código de referido',
      'referralCodeOptional': 'Código de referido (opcional)',
      'enterUsername': 'Introduce tu nombre de usuario',
      'enterEmail': 'Introduce tu correo',
      'enterPassword': 'Introduce tu contraseña',
      'enterReferralCode': 'Introduce el código de referido',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'resetPassword': 'Restablecer contraseña',
      'dontHaveAccount': '¿No tienes una cuenta?',
      'alreadyHaveAccount': '¿Ya tienes una cuenta?',
      'passwordHidden': 'Contraseña oculta',
      'passwordVisible': 'Contraseña visible',

      'home': 'Inicio',
      'balance': 'Saldo',
      'fanBalance': 'Saldo FAN',
      'afamBalance': 'Saldo AFAM',
      'miningBalance': 'Saldo de minería',
      'originalCoin': 'Moneda original',

      'mining': 'Minería',
      'startMining': 'INICIAR MINERÍA',
      'miningNow': 'MINANDO',
      'miningStopped': 'Minería detenida',
      'claimMining': 'RECLAMAR MINERÍA',
      'claim': 'Reclamar',
      'claimed': 'Reclamado',
      'miningRate': 'Tasa de minería',
      'fanPerHour': 'FAN / Hora',
      'remainingTime': 'Tiempo restante',
      'miningSession': 'Sesión de minería',
      'miningEndsIn': 'La minería termina en',
      'miningStarted': 'Minería iniciada correctamente',
      'miningCompleted': 'Sesión de minería completada',

      'boostMining': 'Aumentar minería',
      'boost': 'Aumentar',
      'watchAd': 'VER ANUNCIO',
      'adsWatched': 'Anuncios vistos',
      'dailyAds': 'Anuncios diarios',
      'maxAds': 'Máximo de anuncios',
      'boostPerAd': '+0.1 FAN/H por anuncio',
      'maximumBoost': 'Aumento máximo: +0.7 FAN/H',
      'adReward': 'Recompensa por anuncio',
      'rewardedAd': 'Anuncio recompensado',
      'watchAdsToBoost':
          'Mira anuncios para aumentar tu tasa de minería',
      'adSystemComingSoon':
          'El sistema de anuncios llegará pronto',

      'dailySocialTask': 'Tarea social diaria',
      'socialTasks': 'Tareas sociales',
      'dailyTasks': 'Tareas diarias',
      'completeTask': 'Completar tarea',
      'openTask': 'ABRIR TAREA',
      'verifyTask': 'VERIFICAR TAREA',
      'claimReward': 'RECLAMAR RECOMPENSA',
      'taskCompleted': 'Tarea completada',
      'taskClaimed': 'Recompensa ya reclamada',
      'taskNotReady':
          'Completa primero las acciones requeridas',
      'follow': 'Seguir',
      'comment': 'Comentar',
      'share': 'Compartir',
      'checkIn': 'Registrarse',
      'dailyCheckIn': 'Registro diario',
      'socialReward': 'Recompensa social',
      'fanReward': 'Recompensa FAN',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral': 'Referidos',
      'referrals': 'Referidos',
      'inviteFriends': 'Invitar amigos',
      'inviteAndEarn': 'Invita y gana',
      'myReferralCode': 'Mi código de referido',
      'copyCode': 'COPIAR CÓDIGO',
      'shareCode': 'COMPARTIR CÓDIGO',
      'copied': 'Copiado',
      'totalReferrals': 'Total de referidos',
      'activeReferrals': 'Referidos activos',
      'referralEarnings': 'Ganancias por referidos',
      'referralReward': 'Recompensa por referido',
      'newUserReward': 'El nuevo usuario recibe 20 FAN',
      'miningBonus': 'Bono de minería',
      'perActiveReferral':
          '+0.02 FAN/H por referido activo',

      'referralHowItWorks': 'Cómo funciona el referido',
      'referralStepOne':
          'Comparte tu código con amigos.',
      'referralStepTwo':
          'Tu amigo se une usando tu código.',
      'referralStepThree':
          'Recibes 5 FAN y un bono de minería.',

      'wallet': 'Billetera',
      'afamWallet': 'Billetera AFAM',
      'fanMiningBalance': 'Saldo de minería FAN',
      'migration': 'Migración',
      'migrate': 'MIGRAR',
      'migrationComingSoon': 'Migración próximamente',
      'migrationInfo':
          'Tu saldo FAN podrá migrarse a AFAM más adelante.',
      'migrationRate': 'Tasa de migración',
      'oneHundredFanOneAfam': '100 FAN = 1 AFAM',
      'transactions': 'Transacciones',
      'noTransactions': 'Aún no hay transacciones',

      'send': 'ENVIAR',
      'receive': 'RECIBIR',
      'sendAfam': 'Enviar AFAM',
      'receiveAfam': 'Recibir AFAM',
      'usernameTransactions':
          'Las transacciones se realizan mediante el nombre de usuario.',
      'walletSecurity': 'Seguridad de la billetera',
      'walletSecurityMessage':
          'Mantén tu cuenta segura. Nunca compartas tu contraseña ni tus datos de verificación.',

      'kyc': 'KYC',
      'kycVerification': 'Verificación KYC',
      'faceVerification': 'Verificación facial',
      'faceVerificationComingSoon':
          'Verificación facial próximamente',
      'kycComingSoon': 'KYC próximamente',
      'kycRequirements': 'Requisitos KYC',
      'kycRequirementOne':
          'Completa 30 días consecutivos de registro diario.',
      'kycRequirementTwo':
          'Completa al menos un aumento cada día durante 30 días.',
      'kycRequirementThree':
          'Después completa la verificación facial.',
      'thirtyDayCheckIn': '30 días de registro diario',
      'thirtyDayBoost': '30 días de aumento diario',
      'kycUnlocked': 'KYC desbloqueado',
      'kycLocked': 'KYC bloqueado',

      'startFaceVerification':
          'INICIAR VERIFICACIÓN FACIAL',
      'verificationInProgress': 'Verificación en progreso',
      'verificationComplete': 'Verificación completada',
      'keepFaceVisible':
          'Mantén tu rostro visible en la cámara.',
      'lookAtCamera':
          'Mira directamente a la cámara.',
      'verificationSeconds':
          'Verificación de 30 segundos',
      'secondsRemaining': 'segundos restantes',
      'cameraPermissionRequired':
          'Se requiere permiso de cámara',
      'cameraPermissionMessage':
          'Se necesita acceso a la cámara para la verificación facial en vivo.',
      'oneDeviceOneAccount':
          'Un dispositivo = Una cuenta',
      'deviceSecurity': 'Seguridad del dispositivo',
      'livenessWarning':
          'La verificación con cámara en vivo ayuda a proteger la red, pero un temporizador de 30 segundos por sí solo no es una detección biométrica completa.',

      'settings': 'Configuración',
      'account': 'Cuenta',
      'profile': 'Perfil',
      'notifications': 'Notificaciones',
      'security': 'Seguridad',
      'privacy': 'Privacidad',
      'about': 'Acerca de',
      'help': 'Ayuda',
      'logout': 'Cerrar sesión',
      'logoutConfirm':
          '¿Seguro que quieres cerrar sesión?',

      'save': 'Guardar',
      'cancel': 'Cancelar',
      'close': 'Cerrar',
      'continue': 'Continuar',
      'done': 'Listo',
      'refresh': 'Actualizar',
      'retry': 'Reintentar',
      'loading': 'Cargando...',
      'error': 'Error',
      'success': 'Éxito',
      'failed': 'Fallido',
      'comingSoon': 'Próximamente',
      'enabled': 'Activado',
      'disabled': 'Desactivado',
      'yes': 'Sí',
      'no': 'No',
      'today': 'Hoy',
      'tomorrow': 'Mañana',

      'loginRequired': 'Inicia sesión primero.',
      'invalidEmail':
          'Introduce un correo electrónico válido.',
      'invalidPassword':
          'La contraseña debe tener al menos 6 caracteres.',
      'invalidUsername':
          'Introduce un nombre de usuario válido.',
      'passwordsDoNotMatch':
          'Las contraseñas no coinciden.',
      'somethingWentWrong': 'Algo salió mal.',
      'networkError':
          'Error de red. Inténtalo de nuevo.',
      'noInternet':
          'No hay conexión a Internet.',
      'operationSuccessful':
          'Operación exitosa.',

      'claimRequiresAd':
          'Mira el anuncio recompensado antes de reclamar tu recompensa de minería de 24 horas.',
      'claimAdMessage':
          'Después de completar el anuncio, se reclamará tu recompensa y comenzará automáticamente una nueva sesión de 24 horas.',
      'dailyBoostRequired':
          'Se requiere un boost diario',
      'dailyBoostReminder':
          'Mira al menos un anuncio de boost cada día para mantenerte activo y avanzar hacia KYC.',
      'miningRules':
          'Reglas de minería',
      'miningRuleClaim24h':
          'Reclama tu recompensa después de cada sesión de 24 horas.',
      'miningRuleRateIncrease':
          'La tasa de minería solo puede aumentar mediante boosts aprobados y referidos activos.',
      'miningRuleDailyBoost':
          'Completa al menos un boost cada día para mantenerte activo.',
      'robotWarning':
          'No se permite la actividad de robots o automatizada.',
      'unauthorizedActivity':
          'Los métodos no autorizados, bots, scripts u otras actividades abusivas pueden causar restricciones o suspensión de la cuenta.',
      'accountRestrictionWarning':
          'Podemos revisar y restringir cuentas que infrinjan las reglas de la red. La acción dependerá de la infracción.',
      'deviceAlreadyRegistered':
          'Este dispositivo ya está vinculado a otra cuenta.',
      'oneDeviceRuleMessage':
          'Una persona puede usar una cuenta en un dispositivo. No se permiten varias cuentas en el mismo dispositivo.',
      'boostCompleted':
          'Boost completado correctamente.',
      'dailyBoostCompleted':
          'El boost de hoy está completo.',
    },

    // ========================================================================
    // FRENCH
    // ========================================================================
    'fr': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'Miner FAN',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',
      'language': 'Langue',
      'selectLanguage': 'Choisir la langue',
      'chooseLanguage': 'Choisissez votre langue',
      'languageChanged': 'Langue modifiée avec succès',
      'login': 'Connexion',
      'register': 'Inscription',
      'signIn': 'Se connecter',
      'signUp': "S'inscrire",
      'welcomeBack': 'Bon retour',
      'createAccount': 'Créer un compte',
      'loginToContinue':
          'Connectez-vous pour continuer',
      'joinPowerFanNetwork':
          'Rejoindre POWER FAN NETWORK',
      'username': "Nom d'utilisateur",
      'email': 'E-mail',
      'password': 'Mot de passe',
      'confirmPassword':
          'Confirmer le mot de passe',
      'referralCode': 'Code de parrainage',
      'referralCodeOptional':
          'Code de parrainage (facultatif)',
      'enterUsername':
          "Entrez votre nom d'utilisateur",
      'enterEmail': 'Entrez votre e-mail',
      'enterPassword':
          'Entrez votre mot de passe',
      'enterReferralCode':
          'Entrez le code de parrainage',
      'forgotPassword':
          'Mot de passe oublié ?',
      'resetPassword':
          'Réinitialiser le mot de passe',
      'dontHaveAccount':
          "Vous n'avez pas de compte ?",
      'alreadyHaveAccount':
          'Vous avez déjà un compte ?',
      'passwordHidden':
          'Mot de passe masqué',
      'passwordVisible':
          'Mot de passe visible',

      'home': 'Accueil',
      'balance': 'Solde',
      'fanBalance': 'Solde FAN',
      'afamBalance': 'Solde AFAM',
      'miningBalance': 'Solde de minage',
      'originalCoin': 'Monnaie originale',

      'mining': 'Minage',
      'startMining': 'DÉMARRER LE MINAGE',
      'miningNow': 'MINAGE EN COURS',
      'miningStopped': 'Minage arrêté',
      'claimMining': 'RÉCLAMER LE MINAGE',
      'claim': 'Réclamer',
      'claimed': 'Réclamé',
      'miningRate': 'Taux de minage',
      'fanPerHour': 'FAN / Heure',
      'remainingTime': 'Temps restant',
      'miningSession': 'Session de minage',
      'miningEndsIn':
          'Le minage se termine dans',
      'miningStarted':
          'Minage démarré avec succès',
      'miningCompleted':
          'Session de minage terminée',

      'boostMining': 'Booster le minage',
      'boost': 'Booster',
      'watchAd': 'REGARDER LA PUB',
      'adsWatched': 'Publicités regardées',
      'dailyAds': 'Publicités quotidiennes',
      'maxAds': 'Maximum de publicités',
      'boostPerAd':
          '+0.1 FAN/H par publicité',
      'maximumBoost':
          'Boost maximum : +0.7 FAN/H',
      'adReward':
          'Récompense publicitaire',
      'rewardedAd':
          'Publicité récompensée',
      'watchAdsToBoost':
          'Regardez des publicités pour augmenter votre taux de minage',
      'adSystemComingSoon':
          'Le système de publicités récompensées arrive bientôt',

      'dailySocialTask':
          'Tâche sociale quotidienne',
      'socialTasks': 'Tâches sociales',
      'dailyTasks': 'Tâches quotidiennes',
      'completeTask':
          'Terminer la tâche',
      'openTask': 'OUVRIR LA TÂCHE',
      'verifyTask':
          'VÉRIFIER LA TÂCHE',
      'claimReward':
          'RÉCLAMER LA RÉCOMPENSE',
      'taskCompleted':
          'Tâche terminée',
      'taskClaimed':
          'Récompense déjà réclamée',
      'taskNotReady':
          'Effectuez d’abord les actions requises',
      'follow': 'Suivre',
      'comment': 'Commenter',
      'share': 'Partager',
      'checkIn': 'Enregistrement',
      'dailyCheckIn':
          'Enregistrement quotidien',
      'socialReward':
          'Récompense sociale',
      'fanReward':
          'Récompense FAN',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral': 'Parrainage',
      'referrals': 'Parrainages',
      'inviteFriends':
          'Inviter des amis',
      'inviteAndEarn':
          'Inviter et gagner',
      'myReferralCode':
          'Mon code de parrainage',
      'copyCode': 'COPIER LE CODE',
      'shareCode':
          'PARTAGER LE CODE',
      'copied': 'Copié',
      'totalReferrals':
          'Total des parrainages',
      'activeReferrals':
          'Parrainages actifs',
      'referralEarnings':
          'Gains de parrainage',
      'referralReward':
          'Récompense de parrainage',
      'newUserReward':
          'Le nouvel utilisateur reçoit 20 FAN',
      'miningBonus':
          'Bonus de minage',
      'perActiveReferral':
          '+0.02 FAN/H par parrainage actif',

      'referralHowItWorks':
          'Comment fonctionne le parrainage',
      'referralStepOne':
          'Partagez votre code avec vos amis.',
      'referralStepTwo':
          'Votre ami rejoint avec votre code.',
      'referralStepThree':
          'Vous recevez 5 FAN et un bonus de minage.',

      'wallet': 'Portefeuille',
      'afamWallet':
          'Portefeuille AFAM',
      'fanMiningBalance':
          'Solde de minage FAN',
      'migration': 'Migration',
      'migrate': 'MIGRER',
      'migrationComingSoon':
          'Migration bientôt disponible',
      'migrationInfo':
          'Votre solde FAN pourra être migré vers AFAM plus tard.',
      'migrationRate':
          'Taux de migration',
      'oneHundredFanOneAfam':
          '100 FAN = 1 AFAM',
      'transactions':
          'Transactions',
      'noTransactions':
          'Aucune transaction',
      'send': 'ENVOYER',
      'receive': 'RECEVOIR',
      'sendAfam':
          'Envoyer AFAM',
      'receiveAfam':
          'Recevoir AFAM',
      'usernameTransactions':
          'Les transactions utilisent le nom d’utilisateur.',
      'walletSecurity':
          'Sécurité du portefeuille',
      'walletSecurityMessage':
          'Gardez votre compte sécurisé. Ne partagez jamais votre mot de passe ou vos informations de vérification.',

      'kyc': 'KYC',
      'kycVerification':
          'Vérification KYC',
      'faceVerification':
          'Vérification faciale',
      'faceVerificationComingSoon':
          'Vérification faciale bientôt disponible',
      'kycComingSoon':
          'KYC bientôt disponible',
      'kycRequirements':
          'Exigences KYC',
      'kycRequirementOne':
          'Effectuez 30 jours consécutifs d’enregistrement quotidien.',
      'kycRequirementTwo':
          'Effectuez au moins un boost chaque jour pendant 30 jours.',
      'kycRequirementThree':
          'Effectuez ensuite la vérification faciale.',
      'thirtyDayCheckIn':
          '30 jours d’enregistrement quotidien',
      'thirtyDayBoost':
          '30 jours de boost quotidien',
      'kycUnlocked':
          'KYC déverrouillé',
      'kycLocked':
          'KYC verrouillé',

      'startFaceVerification':
          'DÉMARRER LA VÉRIFICATION FACIALE',
      'verificationInProgress':
          'Vérification en cours',
      'verificationComplete':
          'Vérification terminée',
      'keepFaceVisible':
          'Gardez votre visage visible dans la caméra.',
      'lookAtCamera':
          'Regardez directement la caméra.',
      'verificationSeconds':
          'Vérification de 30 secondes',
      'secondsRemaining':
          'secondes restantes',
      'cameraPermissionRequired':
          'Autorisation de caméra requise',
      'cameraPermissionMessage':
          'L’accès à la caméra est nécessaire pour la vérification faciale en direct.',
      'oneDeviceOneAccount':
          'Un appareil = Un compte',
      'deviceSecurity':
          'Sécurité de l’appareil',
      'livenessWarning':
          'La vérification par caméra en direct aide à protéger le réseau, mais un minuteur de 30 secondes seul ne constitue pas une détection biométrique complète.',

      'settings': 'Paramètres',
      'account': 'Compte',
      'profile': 'Profil',
      'notifications': 'Notifications',
      'security': 'Sécurité',
      'privacy': 'Confidentialité',
      'about': 'À propos',
      'help': 'Aide',
      'logout': 'Déconnexion',
      'logoutConfirm':
          'Voulez-vous vraiment vous déconnecter ?',

      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'close': 'Fermer',
      'continue': 'Continuer',
      'done': 'Terminé',
      'refresh': 'Actualiser',
      'retry': 'Réessayer',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'failed': 'Échec',
      'comingSoon': 'Bientôt disponible',
      'enabled': 'Activé',
      'disabled': 'Désactivé',
      'yes': 'Oui',
      'no': 'Non',
      'today': "Aujourd'hui",
      'tomorrow': 'Demain',

      'loginRequired':
          "Veuillez d'abord vous connecter.",
      'invalidEmail':
          'Veuillez entrer une adresse e-mail valide.',
      'invalidPassword':
          'Le mot de passe doit contenir au moins 6 caractères.',
      'invalidUsername':
          "Veuillez entrer un nom d'utilisateur valide.",
      'passwordsDoNotMatch':
          'Les mots de passe ne correspondent pas.',
      'somethingWentWrong':
          "Une erreur s'est produite.",
      'networkError':
          'Erreur réseau. Veuillez réessayer.',
      'noInternet':
          'Aucune connexion Internet.',
      'operationSuccessful':
          'Opération réussie.',

      'claimRequiresAd':
          'Regardez la publicité récompensée avant de réclamer votre récompense de minage de 24 heures.',
      'claimAdMessage':
          'Après la publicité, votre récompense sera réclamée et une nouvelle session de 24 heures commencera automatiquement.',
      'dailyBoostRequired':
          'Boost quotidien requis',
      'dailyBoostReminder':
          'Regardez au moins une publicité de boost chaque jour pour rester actif et progresser vers le KYC.',
      'miningRules':
          'Règles de minage',
      'miningRuleClaim24h':
          'Réclamez votre récompense après chaque session de 24 heures.',
      'miningRuleRateIncrease':
          'Le taux de minage ne peut augmenter que grâce aux boosts approuvés et aux parrainages actifs.',
      'miningRuleDailyBoost':
          'Effectuez au moins un boost chaque jour pour rester actif.',
      'robotWarning':
          'Les robots et activités automatisées sont interdits.',
      'unauthorizedActivity':
          'Les méthodes non autorisées, bots, scripts ou autres abus peuvent entraîner des restrictions ou la suspension du compte.',
      'accountRestrictionWarning':
          'Nous pouvons examiner et restreindre les comptes qui enfreignent les règles du réseau. La mesure dépendra de l’infraction.',
      'deviceAlreadyRegistered':
          'Cet appareil est déjà lié à un autre compte.',
      'oneDeviceRuleMessage':
          'Une personne peut utiliser un compte sur un appareil. Plusieurs comptes sur le même appareil sont interdits.',
      'boostCompleted':
          'Boost terminé avec succès.',
      'dailyBoostCompleted':
          'Le boost du jour est terminé.',
    },

    // ========================================================================
    // ARABIC
    // ========================================================================
    'ar': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'تعدين FAN',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',
      'language': 'اللغة',
      'selectLanguage': 'اختيار اللغة',
      'chooseLanguage': 'اختر لغتك',
      'languageChanged': 'تم تغيير اللغة بنجاح',

      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب',
      'signIn': 'تسجيل الدخول',
      'signUp': 'إنشاء حساب',
      'welcomeBack': 'مرحباً بعودتك',
      'createAccount': 'إنشاء حساب',
      'loginToContinue': 'سجل الدخول للمتابعة',
      'joinPowerFanNetwork':
          'انضم إلى POWER FAN NETWORK',

      'username': 'اسم المستخدم',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirmPassword': 'تأكيد كلمة المرور',
      'referralCode': 'رمز الإحالة',
      'referralCodeOptional':
          'رمز الإحالة (اختياري)',
      'enterUsername': 'أدخل اسم المستخدم',
      'enterEmail': 'أدخل البريد الإلكتروني',
      'enterPassword': 'أدخل كلمة المرور',
      'enterReferralCode': 'أدخل رمز الإحالة',

      'forgotPassword':
          'هل نسيت كلمة المرور؟',
      'resetPassword':
          'إعادة تعيين كلمة المرور',
      'dontHaveAccount':
          'ليس لديك حساب؟',
      'alreadyHaveAccount':
          'لديك حساب بالفعل؟',
      'passwordHidden':
          'كلمة المرور مخفية',
      'passwordVisible':
          'كلمة المرور ظاهرة',

      'home': 'الرئيسية',
      'balance': 'الرصيد',
      'fanBalance': 'رصيد FAN',
      'afamBalance': 'رصيد AFAM',
      'miningBalance': 'رصيد التعدين',
      'originalCoin': 'العملة الأصلية',

      'mining': 'التعدين',
      'startMining': 'بدء التعدين',
      'miningNow': 'جاري التعدين',
      'miningStopped': 'توقف التعدين',
      'claimMining': 'استلام التعدين',
      'claim': 'استلام',
      'claimed': 'تم الاستلام',
      'miningRate': 'معدل التعدين',
      'fanPerHour': 'FAN / ساعة',
      'remainingTime': 'الوقت المتبقي',
      'miningSession': 'جلسة التعدين',
      'miningEndsIn':
          'ينتهي التعدين خلال',
      'miningStarted':
          'تم بدء التعدين بنجاح',
      'miningCompleted':
          'اكتملت جلسة التعدين',

      'boostMining': 'تعزيز التعدين',
      'boost': 'تعزيز',
      'watchAd': 'مشاهدة الإعلان',
      'adsWatched': 'الإعلانات المشاهدة',
      'dailyAds': 'الإعلانات اليومية',
      'maxAds': 'الحد الأقصى للإعلانات',
      'boostPerAd':
          '+0.1 FAN/H لكل إعلان',
      'maximumBoost':
          'الحد الأقصى للتعزيز: +0.7 FAN/H',
      'adReward': 'مكافأة الإعلان',
      'rewardedAd': 'إعلان بمكافأة',
      'watchAdsToBoost':
          'شاهد الإعلانات لزيادة معدل التعدين',
      'adSystemComingSoon':
          'نظام الإعلانات بمكافآت قريباً',

      'dailySocialTask':
          'المهمة الاجتماعية اليومية',
      'socialTasks': 'المهام الاجتماعية',
      'dailyTasks': 'المهام اليومية',
      'completeTask': 'إكمال المهمة',
      'openTask': 'فتح المهمة',
      'verifyTask': 'التحقق من المهمة',
      'claimReward': 'استلام المكافأة',
      'taskCompleted':
          'تم إكمال المهمة',
      'taskClaimed':
          'تم استلام المكافأة بالفعل',
      'taskNotReady':
          'أكمل الإجراءات المطلوبة أولاً',
      'follow': 'متابعة',
      'comment': 'تعليق',
      'share': 'مشاركة',
      'checkIn': 'تسجيل الحضور',
      'dailyCheckIn': 'الحضور اليومي',
      'socialReward':
          'المكافأة الاجتماعية',
      'fanReward': 'مكافأة FAN',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral': 'الإحالة',
      'referrals': 'الإحالات',
      'inviteFriends':
          'دعوة الأصدقاء',
      'inviteAndEarn':
          'ادعُ واربح',
      'myReferralCode':
          'رمز الإحالة الخاص بي',
      'copyCode': 'نسخ الرمز',
      'shareCode': 'مشاركة الرمز',
      'copied': 'تم النسخ',
      'totalReferrals':
          'إجمالي الإحالات',
      'activeReferrals':
          'الإحالات النشطة',
      'referralEarnings':
          'أرباح الإحالة',
      'referralReward':
          'مكافأة الإحالة',
      'newUserReward':
          'يحصل المستخدم الجديد على 20 FAN',
      'miningBonus':
          'مكافأة التعدين',
      'perActiveReferral':
          '+0.02 FAN/H لكل إحالة نشطة',

      'referralHowItWorks':
          'كيفية عمل الإحالة',
      'referralStepOne':
          'شارك رمز الإحالة مع أصدقائك.',
      'referralStepTwo':
          'ينضم صديقك باستخدام رمزك.',
      'referralStepThree':
          'تحصل على 5 FAN ومكافأة تعدين.',

      'wallet': 'المحفظة',
      'afamWallet': 'محفظة AFAM',
      'fanMiningBalance':
          'رصيد تعدين FAN',
      'migration': 'الترحيل',
      'migrate': 'ترحيل',
      'migrationComingSoon':
          'الترحيل قريباً',
      'migrationInfo':
          'يمكن ترحيل رصيد FAN إلى AFAM لاحقاً.',
      'migrationRate':
          'معدل الترحيل',
      'oneHundredFanOneAfam':
          '100 FAN = 1 AFAM',
      'transactions': 'المعاملات',
      'noTransactions':
          'لا توجد معاملات بعد',
      'send': 'إرسال',
      'receive': 'استلام',
      'sendAfam': 'إرسال AFAM',
      'receiveAfam': 'استلام AFAM',
      'usernameTransactions':
          'تتم المعاملات باستخدام اسم المستخدم.',
      'walletSecurity':
          'أمان المحفظة',
      'walletSecurityMessage':
          'حافظ على أمان حسابك. لا تشارك كلمة المرور أو معلومات التحقق.',

      'kyc': 'KYC',
      'kycVerification':
          'التحقق من KYC',
      'faceVerification':
          'التحقق من الوجه',
      'faceVerificationComingSoon':
          'التحقق من الوجه قريباً',
      'kycComingSoon': 'KYC قريباً',
      'kycRequirements':
          'متطلبات KYC',
      'kycRequirementOne':
          'إكمال تسجيل الحضور اليومي لمدة 30 يوماً متتالياً.',
      'kycRequirementTwo':
          'إكمال تعزيز واحد على الأقل يومياً لمدة 30 يوماً.',
      'kycRequirementThree':
          'ثم إكمال التحقق من الوجه.',
      'thirtyDayCheckIn':
          '30 يوماً من الحضور اليومي',
      'thirtyDayBoost':
          '30 يوماً من التعزيز اليومي',
      'kycUnlocked':
          'تم فتح KYC',
      'kycLocked':
          'KYC مقفل',

      'startFaceVerification':
          'بدء التحقق من الوجه',
      'verificationInProgress':
          'التحقق جارٍ',
      'verificationComplete':
          'اكتمل التحقق',
      'keepFaceVisible':
          'أبقِ وجهك ظاهراً أمام الكاميرا.',
      'lookAtCamera':
          'انظر مباشرة إلى الكاميرا.',
      'verificationSeconds':
          'تحقق لمدة 30 ثانية',
      'secondsRemaining':
          'ثوانٍ متبقية',
      'cameraPermissionRequired':
          'مطلوب إذن الكاميرا',
      'cameraPermissionMessage':
          'يلزم الوصول إلى الكاميرا للتحقق المباشر من الوجه.',
      'oneDeviceOneAccount':
          'جهاز واحد = حساب واحد',
      'deviceSecurity':
          'أمان الجهاز',
      'livenessWarning':
          'يساعد التحقق بالكاميرا المباشرة في حماية الشبكة، لكن مؤقت 30 ثانية وحده ليس نظاماً كاملاً لاكتشاف الحيوية البيومترية.',

      'settings': 'الإعدادات',
      'account': 'الحساب',
      'profile': 'الملف الشخصي',
      'notifications': 'الإشعارات',
      'security': 'الأمان',
      'privacy': 'الخصوصية',
      'about': 'حول',
      'help': 'المساعدة',
      'logout': 'تسجيل الخروج',
      'logoutConfirm':
          'هل أنت متأكد أنك تريد تسجيل الخروج؟',

      'save': 'حفظ',
      'cancel': 'إلغاء',
      'close': 'إغلاق',
      'continue': 'متابعة',
      'done': 'تم',
      'refresh': 'تحديث',
      'retry': 'إعادة المحاولة',
      'loading': 'جارٍ التحميل...',
      'error': 'خطأ',
      'success': 'نجاح',
      'failed': 'فشل',
      'comingSoon': 'قريباً',
      'enabled': 'مفعل',
      'disabled': 'معطل',
      'yes': 'نعم',
      'no': 'لا',
      'today': 'اليوم',
      'tomorrow': 'غداً',

      'loginRequired':
          'يرجى تسجيل الدخول أولاً.',
      'invalidEmail':
          'يرجى إدخال بريد إلكتروني صالح.',
      'invalidPassword':
          'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.',
      'invalidUsername':
          'يرجى إدخال اسم مستخدم صالح.',
      'passwordsDoNotMatch':
          'كلمات المرور غير متطابقة.',
      'somethingWentWrong':
          'حدث خطأ ما.',
      'networkError':
          'خطأ في الشبكة. حاول مرة أخرى.',
      'noInternet':
          'لا يوجد اتصال بالإنترنت.',
      'operationSuccessful':
          'تمت العملية بنجاح.',

      'claimRequiresAd':
          'شاهد الإعلان بمكافأة قبل استلام مكافأة التعدين لمدة 24 ساعة.',
      'claimAdMessage':
          'بعد إكمال الإعلان، سيتم استلام مكافأة التعدين وستبدأ جلسة جديدة لمدة 24 ساعة تلقائياً.',
      'dailyBoostRequired':
          'التعزيز اليومي مطلوب',
      'dailyBoostReminder':
          'شاهد إعلان تعزيز واحداً على الأقل كل يوم للبقاء نشطاً والتقدم نحو KYC.',
      'miningRules':
          'قواعد التعدين',
      'miningRuleClaim24h':
          'استلم مكافأة التعدين بعد كل جلسة مدتها 24 ساعة.',
      'miningRuleRateIncrease':
          'لا يمكن زيادة معدل التعدين إلا من خلال التعزيزات المعتمدة والإحالات النشطة.',
      'miningRuleDailyBoost':
          'أكمل تعزيزا واحداً على الأقل كل يوم للبقاء نشطاً.',
      'robotWarning':
          'الروبوتات والأنشطة الآلية غير مسموح بها.',
      'unauthorizedActivity':
          'قد تؤدي الطرق غير المصرح بها أو الروبوتات أو البرامج النصية أو أي إساءة استخدام أخرى إلى تقييد الحساب أو تعليقه.',
      'accountRestrictionWarning':
          'قد نراجع الحسابات التي تنتهك قواعد الشبكة ونقيّدها. وسيعتمد الإجراء على نوع المخالفة.',
      'deviceAlreadyRegistered':
          'هذا الجهاز مرتبط بالفعل بحساب آخر.',
      'oneDeviceRuleMessage':
          'يمكن لشخص واحد استخدام حساب واحد على جهاز واحد. لا يُسمح بإنشاء حسابات متعددة على الجهاز نفسه.',
      'boostCompleted':
          'تم إكمال التعزيز بنجاح.',
      'dailyBoostCompleted':
          'تم إكمال تعزيز اليوم.',
    },

    // ========================================================================
    // HINDI
    // ========================================================================
    'hi': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'FAN माइन करें',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',
      'language': 'भाषा',
      'selectLanguage': 'भाषा चुनें',
      'chooseLanguage': 'अपनी भाषा चुनें',
      'languageChanged':
          'भाषा सफलतापूर्वक बदल दी गई',

      'login': 'लॉगिन',
      'register': 'रजिस्टर',
      'signIn': 'साइन इन',
      'signUp': 'साइन अप',
      'welcomeBack': 'वापसी पर स्वागत है',
      'createAccount': 'खाता बनाएं',
      'loginToContinue':
          'जारी रखने के लिए लॉगिन करें',
      'joinPowerFanNetwork':
          'POWER FAN NETWORK से जुड़ें',

      'username': 'यूज़रनेम',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'confirmPassword':
          'पासवर्ड की पुष्टि करें',
      'referralCode': 'रेफरल कोड',
      'referralCodeOptional':
          'रेफरल कोड (वैकल्पिक)',
      'enterUsername':
          'यूज़रनेम दर्ज करें',
      'enterEmail': 'ईमेल दर्ज करें',
      'enterPassword':
          'पासवर्ड दर्ज करें',
      'enterReferralCode':
          'रेफरल कोड दर्ज करें',

      'forgotPassword':
          'पासवर्ड भूल गए?',
      'resetPassword':
          'पासवर्ड रीसेट करें',
      'dontHaveAccount':
          'खाता नहीं है?',
      'alreadyHaveAccount':
          'पहले से खाता है?',
      'passwordHidden':
          'पासवर्ड छिपा है',
      'passwordVisible':
          'पासवर्ड दिखाई दे रहा है',

      'home': 'होम',
      'balance': 'बैलेंस',
      'fanBalance': 'FAN बैलेंस',
      'afamBalance': 'AFAM बैलेंस',
      'miningBalance':
          'माइनिंग बैलेंस',
      'originalCoin':
          'मूल कॉइन',

      'mining': 'माइनिंग',
      'startMining':
          'माइनिंग शुरू करें',
      'miningNow':
          'माइनिंग चल रही है',
      'miningStopped':
          'माइनिंग बंद है',
      'claimMining':
          'माइनिंग क्लेम करें',
      'claim': 'क्लेम करें',
      'claimed':
          'क्लेम किया गया',
      'miningRate':
          'माइनिंग रेट',
      'fanPerHour':
          'FAN / घंटा',
      'remainingTime':
          'शेष समय',
      'miningSession':
          'माइनिंग सत्र',
      'miningEndsIn':
          'माइनिंग समाप्त होगी',
      'miningStarted':
          'माइनिंग सफलतापूर्वक शुरू हुई',
      'miningCompleted':
          'माइनिंग सत्र पूरा हुआ',

      'boostMining':
          'माइनिंग बढ़ाएं',
      'boost': 'बूस्ट',
      'watchAd':
          'विज्ञापन देखें',
      'adsWatched':
          'देखे गए विज्ञापन',
      'dailyAds':
          'दैनिक विज्ञापन',
      'maxAds':
          'अधिकतम विज्ञापन',
      'boostPerAd':
          'हर विज्ञापन पर +0.1 FAN/H',
      'maximumBoost':
          'अधिकतम बूस्ट: +0.7 FAN/H',
      'adReward':
          'विज्ञापन इनाम',
      'rewardedAd':
          'रिवॉर्डेड विज्ञापन',
      'watchAdsToBoost':
          'माइनिंग रेट बढ़ाने के लिए विज्ञापन देखें',
      'adSystemComingSoon':
          'रिवॉर्डेड विज्ञापन सिस्टम जल्द आएगा',

      'dailySocialTask':
          'दैनिक सोशल टास्क',
      'socialTasks':
          'सोशल टास्क',
      'dailyTasks':
          'दैनिक टास्क',
      'completeTask':
          'टास्क पूरा करें',
      'openTask':
          'टास्क खोलें',
      'verifyTask':
          'टास्क सत्यापित करें',
      'claimReward':
          'इनाम क्लेम करें',
      'taskCompleted':
          'टास्क पूरा हुआ',
      'taskClaimed':
          'इनाम पहले ही क्लेम किया जा चुका है',
      'taskNotReady':
          'पहले आवश्यक कार्य पूरे करें',
      'follow':
          'फॉलो करें',
      'comment':
          'कमेंट करें',
      'share':
          'शेयर करें',
      'checkIn':
          'चेक-इन',
      'dailyCheckIn':
          'दैनिक चेक-इन',
      'socialReward':
          'सोशल इनाम',
      'fanReward':
          'FAN इनाम',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral':
          'रेफरल',
      'referrals':
          'रेफरल',
      'inviteFriends':
          'दोस्तों को आमंत्रित करें',
      'inviteAndEarn':
          'आमंत्रित करें और कमाएं',
      'myReferralCode':
          'मेरा रेफरल कोड',
      'copyCode':
          'कोड कॉपी करें',
      'shareCode':
          'कोड शेयर करें',
      'copied':
          'कॉपी हो गया',
      'totalReferrals':
          'कुल रेफरल',
      'activeReferrals':
          'सक्रिय रेफरल',
      'referralEarnings':
          'रेफरल कमाई',
      'referralReward':
          'रेफरल इनाम',
      'newUserReward':
          'नए यूज़र को 20 FAN मिलेंगे',
      'miningBonus':
          'माइनिंग बोनस',
      'perActiveReferral':
          'हर सक्रिय रेफरल पर +0.02 FAN/H',

      'referralHowItWorks':
          'रेफरल कैसे काम करता है',
      'referralStepOne':
          'अपना रेफरल कोड दोस्तों के साथ शेयर करें।',
      'referralStepTwo':
          'आपका दोस्त आपके कोड से जुड़ता है।',
      'referralStepThree':
          'आपको 5 FAN और माइनिंग बोनस मिलता है।',

      'wallet':
          'वॉलेट',
      'afamWallet':
          'AFAM वॉलेट',
      'fanMiningBalance':
          'FAN माइनिंग बैलेंस',
      'migration':
          'माइग्रेशन',
      'migrate':
          'माइग्रेट करें',
      'migrationComingSoon':
          'माइग्रेशन जल्द आएगा',
      'migrationInfo':
          'आपका FAN बैलेंस बाद में AFAM में माइग्रेट किया जा सकेगा।',
      'migrationRate':
          'माइग्रेशन दर',
      'oneHundredFanOneAfam':
          '100 FAN = 1 AFAM',
      'transactions':
          'लेन-देन',
      'noTransactions':
          'अभी कोई लेन-देन नहीं',
      'send':
          'भेजें',
      'receive':
          'प्राप्त करें',
      'sendAfam':
          'AFAM भेजें',
      'receiveAfam':
          'AFAM प्राप्त करें',
      'usernameTransactions':
          'लेन-देन यूज़रनेम के माध्यम से किए जाते हैं।',
      'walletSecurity':
          'वॉलेट सुरक्षा',
      'walletSecurityMessage':
          'अपने खाते को सुरक्षित रखें। पासवर्ड या सत्यापन जानकारी साझा न करें।',

      'kyc':
          'KYC',
      'kycVerification':
          'KYC सत्यापन',
      'faceVerification':
          'चेहरा सत्यापन',
      'faceVerificationComingSoon':
          'चेहरा सत्यापन जल्द आएगा',
      'kycComingSoon':
          'KYC जल्द आएगा',
      'kycRequirements':
          'KYC आवश्यकताएं',
      'kycRequirementOne':
          'लगातार 30 दिनों तक दैनिक चेक-इन पूरा करें।',
      'kycRequirementTwo':
          '30 दिनों तक हर दिन कम से कम एक बूस्ट पूरा करें।',
      'kycRequirementThree':
          'इसके बाद चेहरा सत्यापन पूरा करें।',
      'thirtyDayCheckIn':
          '30 दिन दैनिक चेक-इन',
      'thirtyDayBoost':
          '30 दिन दैनिक बूस्ट',
      'kycUnlocked':
          'KYC अनलॉक है',
      'kycLocked':
          'KYC लॉक है',

      'startFaceVerification':
          'चेहरा सत्यापन शुरू करें',
      'verificationInProgress':
          'सत्यापन जारी है',
      'verificationComplete':
          'सत्यापन पूरा हुआ',
      'keepFaceVisible':
          'अपना चेहरा कैमरे में दिखाई देता रखें।',
      'lookAtCamera':
          'कैमरे की ओर सीधे देखें।',
      'verificationSeconds':
          '30 सेकंड सत्यापन',
      'secondsRemaining':
          'सेकंड शेष',
      'cameraPermissionRequired':
          'कैमरा अनुमति आवश्यक है',
      'cameraPermissionMessage':
          'लाइव चेहरा सत्यापन के लिए कैमरा एक्सेस आवश्यक है।',
      'oneDeviceOneAccount':
          'एक डिवाइस = एक खाता',
      'deviceSecurity':
          'डिवाइस सुरक्षा',
      'livenessWarning':
          'लाइव कैमरा सत्यापन नेटवर्क की सुरक्षा में मदद करता है, लेकिन केवल 30 सेकंड का टाइमर पूर्ण बायोमेट्रिक लाइवनेस डिटेक्शन नहीं है।',

      'settings':
          'सेटिंग्स',
      'account':
          'खाता',
      'profile':
          'प्रोफ़ाइल',
      'notifications':
          'सूचनाएं',
      'security':
          'सुरक्षा',
      'privacy':
          'गोपनीयता',
      'about':
          'जानकारी',
      'help':
          'मदद',
      'logout':
          'लॉगआउट',
      'logoutConfirm':
          'क्या आप वाकई लॉगआउट करना चाहते हैं?',

      'save':
          'सहेजें',
      'cancel':
          'रद्द करें',
      'close':
          'बंद करें',
      'continue':
          'जारी रखें',
      'done':
          'पूरा',
      'refresh':
          'रिफ्रेश',
      'retry':
          'फिर कोशिश करें',
      'loading':
          'लोड हो रहा है...',
      'error':
          'त्रुटि',
      'success':
          'सफल',
      'failed':
          'विफल',
      'comingSoon':
          'जल्द आ रहा है',
      'enabled':
          'सक्षम',
      'disabled':
          'अक्षम',
      'yes':
          'हाँ',
      'no':
          'नहीं',
      'today':
          'आज',
      'tomorrow':
          'कल',

      'loginRequired':
          'कृपया पहले लॉगिन करें।',
      'invalidEmail':
          'कृपया मान्य ईमेल दर्ज करें।',
      'invalidPassword':
          'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।',
      'invalidUsername':
          'कृपया मान्य यूज़रनेम दर्ज करें।',
      'passwordsDoNotMatch':
          'पासवर्ड मेल नहीं खाते।',
      'somethingWentWrong':
          'कुछ गलत हो गया।',
      'networkError':
          'नेटवर्क त्रुटि। फिर कोशिश करें।',
      'noInternet':
          'इंटरनेट कनेक्शन नहीं है।',
      'operationSuccessful':
          'ऑपरेशन सफल रहा।',

      'claimRequiresAd':
          '24 घंटे के माइनिंग रिवॉर्ड को क्लेम करने से पहले रिवॉर्डेड विज्ञापन देखें।',
      'claimAdMessage':
          'विज्ञापन पूरा होने के बाद आपका माइनिंग रिवॉर्ड क्लेम होगा और नया 24 घंटे का सत्र अपने आप शुरू होगा।',
      'dailyBoostRequired':
          'दैनिक बूस्ट आवश्यक है',
      'dailyBoostReminder':
          'सक्रिय रहने और KYC की प्रगति के लिए हर दिन कम से कम एक बूस्ट विज्ञापन देखें।',
      'miningRules':
          'माइनिंग नियम',
      'miningRuleClaim24h':
          'हर 24 घंटे के माइनिंग सत्र के बाद अपना रिवॉर्ड क्लेम करें।',
      'miningRuleRateIncrease':
          'माइनिंग रेट केवल स्वीकृत बूस्ट और सक्रिय रेफरल से बढ़ सकता है।',
      'miningRuleDailyBoost':
          'सक्रिय रहने के लिए हर दिन कम से कम एक बूस्ट पूरा करें।',
      'robotWarning':
          'रोबोट या स्वचालित गतिविधि की अनुमति नहीं है।',
      'unauthorizedActivity':
          'अनधिकृत तरीके, बॉट, स्क्रिप्ट या अन्य दुरुपयोग से अकाउंट पर प्रतिबंध या निलंबन हो सकता है।',
      'accountRestrictionWarning':
          'नेटवर्क नियमों का उल्लंघन करने वाले अकाउंट की समीक्षा और प्रतिबंध किया जा सकता है। कार्रवाई उल्लंघन के आधार पर होगी।',
      'deviceAlreadyRegistered':
          'यह डिवाइस पहले से किसी अन्य अकाउंट से जुड़ा है।',
      'oneDeviceRuleMessage':
          'एक व्यक्ति एक डिवाइस पर एक ही अकाउंट इस्तेमाल कर सकता है। एक ही डिवाइस पर कई अकाउंट की अनुमति नहीं है।',
      'boostCompleted':
          'बूस्ट सफलतापूर्वक पूरा हुआ।',
      'dailyBoostCompleted':
          'आज का बूस्ट पूरा हो गया है।',
    },

    // ========================================================================
    // BENGALI
    // ========================================================================
    'bn': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'FAN মাইন করুন',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',
      'language': 'ভাষা',
      'selectLanguage':
          'ভাষা নির্বাচন করুন',
      'chooseLanguage':
          'আপনার ভাষা নির্বাচন করুন',
      'languageChanged':
          'ভাষা সফলভাবে পরিবর্তন হয়েছে',

      'login': 'লগইন',
      'register': 'রেজিস্টার',
      'signIn': 'সাইন ইন',
      'signUp': 'সাইন আপ',
      'welcomeBack':
          'আবারও স্বাগতম',
      'createAccount':
          'অ্যাকাউন্ট তৈরি করুন',
      'loginToContinue':
          'চালিয়ে যেতে লগইন করুন',
      'joinPowerFanNetwork':
          'POWER FAN NETWORK-এ যোগ দিন',

      'username': 'ইউজারনেম',
      'email': 'ইমেইল',
      'password': 'পাসওয়ার্ড',
      'confirmPassword':
          'পাসওয়ার্ড নিশ্চিত করুন',
      'referralCode':
          'রেফারেল কোড',
      'referralCodeOptional':
          'রেফারেল কোড (ঐচ্ছিক)',
      'enterUsername':
          'ইউজারনেম লিখুন',
      'enterEmail':
          'ইমেইল লিখুন',
      'enterPassword':
          'পাসওয়ার্ড লিখুন',
      'enterReferralCode':
          'রেফারেল কোড লিখুন',

      'forgotPassword':
          'পাসওয়ার্ড ভুলে গেছেন?',
      'resetPassword':
          'পাসওয়ার্ড রিসেট করুন',
      'dontHaveAccount':
          'অ্যাকাউন্ট নেই?',
      'alreadyHaveAccount':
          'ইতিমধ্যে অ্যাকাউন্ট আছে?',
      'passwordHidden':
          'পাসওয়ার্ড লুকানো',
      'passwordVisible':
          'পাসওয়ার্ড দৃশ্যমান',

      'home': 'হোম',
      'balance': 'ব্যালেন্স',
      'fanBalance':
          'FAN ব্যালেন্স',
      'afamBalance':
          'AFAM ব্যালেন্স',
      'miningBalance':
          'মাইনিং ব্যালেন্স',
      'originalCoin':
          'মূল কয়েন',

      'mining': 'মাইনিং',
      'startMining':
          'মাইনিং শুরু করুন',
      'miningNow':
          'মাইনিং চলছে',
      'miningStopped':
          'মাইনিং বন্ধ',
      'claimMining':
          'মাইনিং ক্লেম করুন',
      'claim':
          'ক্লেম',
      'claimed':
          'ক্লেম করা হয়েছে',
      'miningRate':
          'মাইনিং রেট',
      'fanPerHour':
          'FAN / ঘণ্টা',
      'remainingTime':
          'অবশিষ্ট সময়',
      'miningSession':
          'মাইনিং সেশন',
      'miningEndsIn':
          'মাইনিং শেষ হবে',
      'miningStarted':
          'মাইনিং সফলভাবে শুরু হয়েছে',
      'miningCompleted':
          'মাইনিং সেশন সম্পন্ন হয়েছে',

      'boostMining':
          'মাইনিং বুস্ট',
      'boost':
          'বুস্ট',
      'watchAd':
          'বিজ্ঞাপন দেখুন',
      'adsWatched':
          'দেখা বিজ্ঞাপন',
      'dailyAds':
          'দৈনিক বিজ্ঞাপন',
      'maxAds':
          'সর্বোচ্চ বিজ্ঞাপন',
      'boostPerAd':
          'প্রতি বিজ্ঞাপনে +0.1 FAN/H',
      'maximumBoost':
          'সর্বোচ্চ বুস্ট: +0.7 FAN/H',
      'adReward':
          'বিজ্ঞাপন পুরস্কার',
      'rewardedAd':
          'রিওয়ার্ডেড বিজ্ঞাপন',
      'watchAdsToBoost':
          'মাইনিং রেট বাড়াতে বিজ্ঞাপন দেখুন',
      'adSystemComingSoon':
          'রিওয়ার্ডেড বিজ্ঞাপন সিস্টেম শীঘ্রই আসছে',

      'dailySocialTask':
          'দৈনিক সোশ্যাল টাস্ক',
      'socialTasks':
          'সোশ্যাল টাস্ক',
      'dailyTasks':
          'দৈনিক টাস্ক',
      'completeTask':
          'টাস্ক সম্পন্ন করুন',
      'openTask':
          'টাস্ক খুলুন',
      'verifyTask':
          'টাস্ক যাচাই করুন',
      'claimReward':
          'পুরস্কার ক্লেম করুন',
      'taskCompleted':
          'টাস্ক সম্পন্ন হয়েছে',
      'taskClaimed':
          'পুরস্কার ইতিমধ্যে নেওয়া হয়েছে',
      'taskNotReady':
          'প্রথমে প্রয়োজনীয় কাজ সম্পন্ন করুন',
      'follow':
          'ফলো',
      'comment':
          'কমেন্ট',
      'share':
          'শেয়ার',
      'checkIn':
          'চেক-ইন',
      'dailyCheckIn':
          'দৈনিক চেক-ইন',
      'socialReward':
          'সোশ্যাল পুরস্কার',
      'fanReward':
          'FAN পুরস্কার',

      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',

      'referral':
          'রেফারেল',
      'referrals':
          'রেফারেল',
      'inviteFriends':
          'বন্ধুদের আমন্ত্রণ করুন',
      'inviteAndEarn':
          'আমন্ত্রণ করুন ও আয় করুন',
      'myReferralCode':
          'আমার রেফারেল কোড',
      'copyCode':
          'কোড কপি করুন',
      'shareCode':
          'কোড শেয়ার করুন',
      'copied':
          'কপি হয়েছে',
      'totalReferrals':
          'মোট রেফারেল',
      'activeReferrals':
          'সক্রিয় রেফারেল',
      'referralEarnings':
          'রেফারেল আয়',
      'referralReward':
          'রেফারেল পুরস্কার',
      'newUserReward':
          'নতুন ব্যবহারকারী 20 FAN পাবেন',
      'miningBonus':
          'মাইনিং বোনাস',
      'perActiveReferral':
          'প্রতি সক্রিয় রেফারেলে +0.02 FAN/H',

      'referralHowItWorks':
          'রেফারেল কীভাবে কাজ করে',
      'referralStepOne':
          'আপনার রেফারেল কোড বন্ধুদের সাথে শেয়ার করুন।',
      'referralStepTwo':
          'আপনার বন্ধু আপনার কোড ব্যবহার করে যোগ দেবে।',
      'referralStepThree':
          'আপনি 5 FAN এবং মাইনিং বোনাস পাবেন।',

      'wallet':
          'ওয়ালেট',
      'afamWallet':
          'AFAM ওয়ালেট',
      'fanMiningBalance':
          'FAN মাইনিং ব্যালেন্স',
      'migration':
          'মাইগ্রেশন',
      'migrate':
          'মাইগ্রেট করুন',
      'migrationComingSoon':
          'মাইগ্রেশন শীঘ্রই আসছে',
      'migrationInfo':
          'আপনার FAN ব্যালেন্স পরে AFAM-এ মাইগ্রেট করা যাবে।',
      'migrationRate':
          'মাইগ্রেশন হার',
      'oneHundredFanOneAfam':
          '100 FAN = 1 AFAM',
      'transactions':
          'লেনদেন',
      'noTransactions':
          'এখনও কোনো লেনদেন নেই',
      'send':
          'পাঠান',
      'receive':
          'গ্রহণ করুন',
      'sendAfam':
          'AFAM পাঠান',
      'receiveAfam':
          'AFAM গ্রহণ করুন',
      'usernameTransactions':
          'ইউজারনেম ব্যবহার করে লেনদেন করা হয়।',
      'walletSecurity':
          'ওয়ালেট নিরাপত্তা',
      'walletSecurityMessage':
          'আপনার অ্যাকাউন্ট নিরাপদ রাখুন। পাসওয়ার্ড বা যাচাই তথ্য শেয়ার করবেন না।',

      'kyc':
          'KYC',
      'kycVerification':
          'KYC যাচাই',
      'faceVerification':
          'ফেস ভেরিফিকেশন',
      'faceVerificationComingSoon':
          'ফেস ভেরিফিকেশন শীঘ্রই আসছে',
      'kycComingSoon':
          'KYC শীঘ্রই আসছে',
      'kycRequirements':
          'KYC প্রয়োজনীয়তা',
      'kycRequirementOne':
          'টানা 30 দিন দৈনিক চেক-ইন সম্পন্ন করুন।',
      'kycRequirementTwo':
          '30 দিন প্রতিদিন অন্তত একটি বুস্ট সম্পন্ন করুন।',
      'kycRequirementThree':
          'তারপর ফেস ভেরিফিকেশন সম্পন্ন করুন।',
      'thirtyDayCheckIn':
          '30 দিনের দৈনিক চেক-ইন',
      'thirtyDayBoost':
          '30 দিনের দৈনিক বুস্ট',
      'kycUnlocked':
          'KYC আনলক হয়েছে',
      'kycLocked':
          'KYC লক করা আছে',

      'startFaceVerification':
          'ফেস ভেরিফিকেশন শুরু করুন',
      'verificationInProgress':
          'ভেরিফিকেশন চলছে',
      'verificationComplete':
          'ভেরিফিকেশন সম্পন্ন হয়েছে',
      'keepFaceVisible':
          'ক্যামেরায় আপনার মুখ দৃশ্যমান রাখুন।',
      'lookAtCamera':
          'সরাসরি ক্যামেরার দিকে তাকান।',
      'verificationSeconds':
          '30 সেকেন্ড ভেরিফিকেশন',
      'secondsRemaining':
          'সেকেন্ড বাকি',
      'cameraPermissionRequired':
          'ক্যামেরা অনুমতি প্রয়োজন',
      'cameraPermissionMessage':
          'লাইভ ফেস ভেরিফিকেশনের জন্য ক্যামেরা অ্যাক্সেস প্রয়োজন।',
      'oneDeviceOneAccount':
          'একটি ডিভাইস = একটি অ্যাকাউন্ট',
      'deviceSecurity':
          'ডিভাইস নিরাপত্তা',
      'livenessWarning':
          'লাইভ ক্যামেরা যাচাই নেটওয়ার্ক সুরক্ষায় সহায়তা করে, তবে শুধু 30 সেকেন্ডের টাইমার সম্পূর্ণ বায়োমেট্রিক লাইভনেস শনাক্তকরণ নয়।',

      'settings':
          'সেটিংস',
      'account':
          'অ্যাকাউন্ট',
      'profile':
          'প্রোফাইল',
      'notifications':
          'নোটিফিকেশন',
      'security':
          'নিরাপত্তা',
      'privacy':
          'গোপনীয়তা',
      'about':
          'সম্পর্কে',
      'help':
          'সহায়তা',
      'logout':
          'লগআউট',
      'logoutConfirm':
          'আপনি কি নিশ্চিত যে লগআউট করতে চান?',

      'save':
          'সংরক্ষণ',
      'cancel':
          'বাতিল',
      'close':
          'বন্ধ',
      'continue':
          'চালিয়ে যান',
      'done':
          'সম্পন্ন',
      'refresh':
          'রিফ্রেশ',
      'retry':
          'আবার চেষ্টা করুন',
      'loading':
          'লোড হচ্ছে...',
      'error':
          'ত্রুটি',
      'success':
          'সফল',
      'failed':
          'ব্যর্থ',
      'comingSoon':
          'শীঘ্রই আসছে',
      'enabled':
          'চালু',
      'disabled':
          'বন্ধ',
      'yes':
          'হ্যাঁ',
      'no':
          'না',
      'today':
          'আজ',
      'tomorrow':
          'আগামীকাল',

      'loginRequired':
          'অনুগ্রহ করে প্রথমে লগইন করুন।',
      'invalidEmail':
          'সঠিক ইমেইল ঠিকানা লিখুন।',
      'invalidPassword':
          'পাসওয়ার্ড কমপক্ষে 6 অক্ষরের হতে হবে।',
      'invalidUsername':
          'সঠিক ইউজারনেম লিখুন।',
      'passwordsDoNotMatch':
          'পাসওয়ার্ড মিলছে না।',
      'somethingWentWrong':
          'কিছু ভুল হয়েছে।',
      'networkError':
          'নেটওয়ার্ক সমস্যা। আবার চেষ্টা করুন।',
      'noInternet':
          'ইন্টারনেট সংযোগ নেই।',
      'operationSuccessful':
          'অপারেশন সফল হয়েছে।',

      'claimRequiresAd':
          '২৪ ঘণ্টার মাইনিং রিওয়ার্ড ক্লেম করার আগে রিওয়ার্ডেড বিজ্ঞাপন দেখুন।',
      'claimAdMessage':
          'বিজ্ঞাপন সম্পন্ন হলে আপনার মাইনিং রিওয়ার্ড ক্লেম হবে এবং নতুন ২৪ ঘণ্টার সেশন স্বয়ংক্রিয়ভাবে শুরু হবে।',
      'dailyBoostRequired':
          'দৈনিক বুস্ট প্রয়োজন',
      'dailyBoostReminder':
          'সক্রিয় থাকতে এবং KYC-এর দিকে এগোতে প্রতিদিন অন্তত একটি বুস্ট বিজ্ঞাপন দেখুন।',
      'miningRules':
          'মাইনিং নিয়ম',
      'miningRuleClaim24h':
          'প্রতিটি ২৪ ঘণ্টার মাইনিং সেশনের পর রিওয়ার্ড ক্লেম করুন।',
      'miningRuleRateIncrease':
          'মাইনিং রেট শুধুমাত্র অনুমোদিত বুস্ট এবং সক্রিয় রেফারেলের মাধ্যমে বাড়তে পারে।',
      'miningRuleDailyBoost':
          'সক্রিয় থাকতে প্রতিদিন অন্তত একটি বুস্ট সম্পন্ন করুন।',
      'robotWarning':
          'রোবট বা স্বয়ংক্রিয় কার্যকলাপ অনুমোদিত নয়।',
      'unauthorizedActivity':
          'অননুমোদিত পদ্ধতি, বট, স্ক্রিপ্ট বা অন্য কোনো অপব্যবহারের কারণে অ্যাকাউন্ট সীমাবদ্ধ বা স্থগিত হতে পারে।',
      'accountRestrictionWarning':
          'নেটওয়ার্কের নিয়ম ভঙ্গকারী অ্যাকাউন্ট পর্যালোচনা ও সীমাবদ্ধ করা হতে পারে। ব্যবস্থা লঙ্ঘনের ওপর নির্ভর করবে।',
      'deviceAlreadyRegistered':
          'এই ডিভাইসটি ইতিমধ্যে অন্য একটি অ্যাকাউন্টের সাথে যুক্ত।',
      'oneDeviceRuleMessage':
          'একজন ব্যক্তি একটি ডিভাইসে একটি অ্যাকাউন্ট ব্যবহার করতে পারবেন। একই ডিভাইসে একাধিক অ্যাকাউন্ট অনুমোদিত নয়।',
      'boostCompleted':
          'বুস্ট সফলভাবে সম্পন্ন হয়েছে।',
      'dailyBoostCompleted':
          'আজকের বুস্ট সম্পন্ন হয়েছে।',
    },
      'referralCodeOptional': 'রেফারেল কোড (ঐচ্ছিক)',
      'enterUsername': 'ইউজারনেম লিখুন',
      'enterEmail': 'ইমেইল লিখুন',
      'enterPassword': 'পাসওয়ার্ড লিখুন',
      'enterReferralCode': 'রেফারেল কোড লিখুন',
      'forgotPassword': 'পাসওয়ার্ড ভুলে গেছেন?',
      'resetPassword': 'পাসওয়ার্ড রিসেট করুন',
      'dontHaveAccount': 'অ্যাকাউন্ট নেই?',
      'alreadyHaveAccount': 'ইতিমধ্যে অ্যাকাউন্ট আছে?',
      'passwordHidden': 'পাসওয়ার্ড লুকানো',
      'passwordVisible': 'পাসওয়ার্ড দৃশ্যমান',
      'home': 'হোম',
      'balance': 'ব্যালেন্স',
      'fanBalance': 'FAN ব্যালেন্স',
      'afamBalance': 'AFAM ব্যালেন্স',
      'miningBalance': 'মাইনিং ব্যালেন্স',
      'originalCoin': 'মূল কয়েন',
      'mining': 'মাইনিং',
      'startMining': 'মাইনিং শুরু করুন',
      'miningNow': 'মাইনিং চলছে',
      'miningStopped': 'মাইনিং বন্ধ',
      'claimMining': 'মাইনিং ক্লেম করুন',
      'claim': 'ক্লেম',
      'claimed': 'ক্লেম করা হয়েছে',
      'miningRate': 'মাইনিং রেট',
      'fanPerHour': 'FAN / ঘণ্টা',
      'remainingTime': 'অবশিষ্ট সময়',
      'miningSession': 'মাইনিং সেশন',
      'miningEndsIn': 'মাইনিং শেষ হবে',
      'miningStarted': 'মাইনিং সফলভাবে শুরু হয়েছে',
      'miningCompleted': 'মাইনিং সেশন সম্পন্ন হয়েছে',
      'boostMining': 'মাইনিং বুস্ট',
      'boost': 'বুস্ট',
      'watchAd': 'বিজ্ঞাপন দেখুন',
      'adsWatched': 'দেখা বিজ্ঞাপন',
      'dailyAds': 'দৈনিক বিজ্ঞাপন',
      'maxAds': 'সর্বোচ্চ বিজ্ঞাপন',
      'boostPerAd': 'প্রতি বিজ্ঞাপনে +0.1 FAN/H',
      'maximumBoost': 'সর্বোচ্চ বুস্ট: +0.7 FAN/H',
      'adReward': 'বিজ্ঞাপন পুরস্কার',
      'rewardedAd': 'রিওয়ার্ডেড বিজ্ঞাপন',
      'watchAdsToBoost': 'মাইনিং রেট বাড়াতে বিজ্ঞাপন দেখুন',
      'adSystemComingSoon': 'রিওয়ার্ডেড বিজ্ঞাপন সিস্টেম শীঘ্রই আসছে',
      'dailySocialTask': 'দৈনিক সোশ্যাল টাস্ক',
      'socialTasks': 'সোশ্যাল টাস্ক',
      'dailyTasks': 'দৈনিক টাস্ক',
      'completeTask': 'টাস্ক সম্পন্ন করুন',
      'openTask': 'টাস্ক খুলুন',
      'verifyTask': 'টাস্ক যাচাই করুন',
      'claimReward': 'পুরস্কার ক্লেম করুন',
      'taskCompleted': 'টাস্ক সম্পন্ন হয়েছে',
      'taskClaimed': 'পুরস্কার ইতিমধ্যে নেওয়া হয়েছে',
      'taskNotReady': 'প্রথমে প্রয়োজনীয় কাজ সম্পন্ন করুন',
      'follow': 'ফলো',
      'comment': 'কমেন্ট',
      'share': 'শেয়ার',
      'checkIn': 'চেক-ইন',
      'dailyCheckIn': 'দৈনিক চেক-ইন',
      'socialReward': 'সোশ্যাল পুরস্কার',
      'fanReward': 'FAN পুরস্কার',
      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',
      'referral': 'রেফারেল',
      'referrals': 'রেফারেল',
      'inviteFriends': 'বন্ধুদের আমন্ত্রণ করুন',
      'inviteAndEarn': 'আমন্ত্রণ করুন ও আয় করুন',
      'myReferralCode': 'আমার রেফারেল কোড',
      'copyCode': 'কোড কপি করুন',
      'shareCode': 'কোড শেয়ার করুন',
      'copied': 'কপি হয়েছে',
      'totalReferrals': 'মোট রেফারেল',
      'activeReferrals': 'সক্রিয় রেফারেল',
      'referralEarnings': 'রেফারেল আয়',
      'referralReward': 'রেফারেল পুরস্কার',
      'newUserReward': 'নতুন ব্যবহারকারী 20 FAN পাবেন',
      'miningBonus': 'মাইনিং বোনাস',
      'perActiveReferral': 'প্রতি সক্রিয় রেফারেলে +0.02 FAN/H',
      'referralHowItWorks': 'রেফারেল কীভাবে কাজ করে',
      'referralStepOne': 'আপনার রেফারেল কোড বন্ধুদের সাথে শেয়ার করুন।',
      'referralStepTwo': 'আপনার বন্ধু আপনার কোড ব্যবহার করে যোগ দেবে।',
      'referralStepThree': 'আপনি 5 FAN এবং মাইনিং বোনাস পাবেন।',
      'wallet': 'ওয়ালেট',
      'afamWallet': 'AFAM ওয়ালেট',
      'fanMiningBalance': 'FAN মাইনিং ব্যালেন্স',
      'migration': 'মাইগ্রেশন',
      'migrate': 'মাইগ্রেট করুন',
      'migrationComingSoon': 'মাইগ্রেশন শীঘ্রই আসছে',
      'migrationInfo': 'আপনার FAN ব্যালেন্স পরে AFAM-এ মাইগ্রেট করা যাবে।',
      'migrationRate': 'মাইগ্রেশন হার',
      'oneHundredFanOneAfam': '100 FAN = 1 AFAM',
      'transactions': 'লেনদেন',
      'noTransactions': 'এখনও কোনো লেনদেন নেই',
      'send': 'পাঠান',
      'receive': 'গ্রহণ করুন',
      'sendAfam': 'AFAM পাঠান',
      'receiveAfam': 'AFAM গ্রহণ করুন',
      'usernameTransactions': 'ইউজারনেম ব্যবহার করে লেনদেন করা হয়।',
      'walletSecurity': 'ওয়ালেট নিরাপত্তা',
      'walletSecurityMessage': 'আপনার অ্যাকাউন্ট নিরাপদ রাখুন। পাসওয়ার্ড বা যাচাই তথ্য শেয়ার করবেন না।',
      'kyc': 'KYC',
      'kycVerification': 'KYC যাচাই',
      'faceVerification': 'ফেস ভেরিফিকেশন',
      'faceVerificationComingSoon': 'ফেস ভেরিফিকেশন শীঘ্রই আসছে',
      'kycComingSoon': 'KYC শীঘ্রই আসছে',
      'kycRequirements': 'KYC প্রয়োজনীয়তা',
      'kycRequirementOne': 'টানা 30 দিন দৈনিক চেক-ইন সম্পন্ন করুন।',
      'kycRequirementTwo': '30 দিন প্রতিদিন অন্তত একটি বুস্ট সম্পন্ন করুন।',
      'kycRequirementThree': 'তারপর ফেস ভেরিফিকেশন সম্পন্ন করুন।',
      'thirtyDayCheckIn': '30 দিনের দৈনিক চেক-ইন',
      'thirtyDayBoost': '30 দিনের দৈনিক বুস্ট',
      'kycUnlocked': 'KYC আনলক হয়েছে',
      'kycLocked': 'KYC লক করা আছে',
      'startFaceVerification': 'ফেস ভেরিফিকেশন শুরু করুন',
      'verificationInProgress': 'ভেরিফিকেশন চলছে',
      'verificationComplete': 'ভেরিফিকেশন সম্পন্ন হয়েছে',
      'keepFaceVisible': 'ক্যামেরায় আপনার মুখ দৃশ্যমান রাখুন।',
      'lookAtCamera': 'সরাসরি ক্যামেরার দিকে তাকান।',
      'verificationSeconds': '30 সেকেন্ড ভেরিফিকেশন',
      'secondsRemaining': 'সেকেন্ড বাকি',
      'cameraPermissionRequired': 'ক্যামেরা অনুমতি প্রয়োজন',
      'cameraPermissionMessage': 'লাইভ ফেস ভেরিফিকেশনের জন্য ক্যামেরা অ্যাক্সেস প্রয়োজন।',
      'oneDeviceOneAccount': 'একটি ডিভাইস = একটি অ্যাকাউন্ট',
      'deviceSecurity': 'ডিভাইস নিরাপত্তা',
      'livenessWarning': 'লাইভ ক্যামেরা যাচাই নেটওয়ার্ক সুরক্ষায় সহায়তা করে, তবে শুধু 30 সেকেন্ডের টাইমার সম্পূর্ণ বায়োমেট্রিক লাইভনেস শনাক্তকরণ নয়।',
      'settings': 'সেটিংস',
      'account': 'অ্যাকাউন্ট',
      'profile': 'প্রোফাইল',
      'notifications': 'নোটিফিকেশন',
      'security': 'নিরাপত্তা',
      'privacy': 'গোপনীয়তা',
      'about': 'সম্পর্কে',
      'help': 'সহায়তা',
      'logout': 'লগআউট',
      'logoutConfirm': 'আপনি কি নিশ্চিত যে লগআউট করতে চান?',
      'save': 'সংরক্ষণ',
      'cancel': 'বাতিল',
      'close': 'বন্ধ',
      'continue': 'চালিয়ে যান',
      'done': 'সম্পন্ন',
      'refresh': 'রিফ্রেশ',
      'retry': 'আবার চেষ্টা করুন',
      'loading': 'লোড হচ্ছে...',
      'error': 'ত্রুটি',
      'success': 'সফল',
      'failed': 'ব্যর্থ',
      'comingSoon': 'শীঘ্রই আসছে',
      'enabled': 'চালু',
      'disabled': 'বন্ধ',
      'yes': 'হ্যাঁ',
      'no': 'না',
      'today': 'আজ',
      'tomorrow': 'আগামীকাল',
      'loginRequired': 'অনুগ্রহ করে প্রথমে লগইন করুন।',
      'invalidEmail': 'সঠিক ইমেইল ঠিকানা লিখুন।',
      'invalidPassword': 'পাসওয়ার্ড কমপক্ষে 6 অক্ষরের হতে হবে।',
      'invalidUsername': 'সঠিক ইউজারনেম লিখুন।',
      'passwordsDoNotMatch': 'পাসওয়ার্ড মিলছে না।',
      'somethingWentWrong': 'কিছু ভুল হয়েছে।',
      'networkError': 'নেটওয়ার্ক সমস্যা। আবার চেষ্টা করুন।',
      'noInternet': 'ইন্টারনেট সংযোগ নেই।',
      'operationSuccessful': 'অপারেশন সফল হয়েছে।',
      'claimRequiresAd': '২৪ ঘণ্টার মাইনিং রিওয়ার্ড ক্লেম করার আগে রিওয়ার্ডেড বিজ্ঞাপন দেখুন।',
      'claimAdMessage': 'বিজ্ঞাপন সম্পন্ন হলে আপনার মাইনিং রিওয়ার্ড ক্লেম হবে এবং নতুন ২৪ ঘণ্টার সেশন স্বয়ংক্রিয়ভাবে শুরু হবে।',
      'dailyBoostRequired': 'দৈনিক বুস্ট প্রয়োজন',
      'dailyBoostReminder': 'সক্রিয় থাকতে এবং KYC-এর দিকে এগোতে প্রতিদিন অন্তত একটি বুস্ট বিজ্ঞাপন দেখুন।',
      'miningRules': 'মাইনিং নিয়ম',
      'miningRuleClaim24h': 'প্রতিটি ২৪ ঘণ্টার মাইনিং সেশনের পর রিওয়ার্ড ক্লেম করুন।',
      'miningRuleRateIncrease': 'মাইনিং রেট শুধুমাত্র অনুমোদিত বুস্ট এবং সক্রিয় রেফারেলের মাধ্যমে বাড়তে পারে।',
      'miningRuleDailyBoost': 'সক্রিয় থাকতে প্রতিদিন অন্তত একটি বুস্ট সম্পন্ন করুন।',
      'robotWarning': 'রোবট বা স্বয়ংক্রিয় কার্যকলাপ অনুমোদিত নয়।',
      'unauthorizedActivity': 'অননুমোদিত পদ্ধতি, বট, স্ক্রিপ্ট বা অন্য কোনো অপব্যবহারের কারণে অ্যাকাউন্ট সীমাবদ্ধ বা স্থগিত হতে পারে।',
      'accountRestrictionWarning': 'নেটওয়ার্কের নিয়ম ভঙ্গকারী অ্যাকাউন্ট পর্যালোচনা ও সীমাবদ্ধ করা হতে পারে। ব্যবস্থা লঙ্ঘনের ওপর নির্ভর করবে।',
      'deviceAlreadyRegistered': 'এই ডিভাইসটি ইতিমধ্যে অন্য একটি অ্যাকাউন্টের সাথে যুক্ত।',
      'oneDeviceRuleMessage': 'একজন ব্যক্তি একটি ডিভাইসে একটি অ্যাকাউন্ট ব্যবহার করতে পারবেন। একই ডিভাইসে একাধিক অ্যাকাউন্ট অনুমোদিত নয়।',
      'boostCompleted': 'বুস্ট সফলভাবে সম্পন্ন হয়েছে।',
      'dailyBoostCompleted': 'আজকের বুস্ট সম্পন্ন হয়েছে।',
    },

    // ========================================================================
    // RUSSIAN
    // ========================================================================
    'ru': {
      'appName': 'POWER FAN',
      'brandName': 'POWER FAN',
      'mineFan': 'Майнинг FAN',
      'powerFanNetwork': 'POWER FAN NETWORK',
      'fan': 'FAN',
      'afam': 'AFAM',
      'language': 'Язык',
      'selectLanguage': 'Выберите язык',
      'chooseLanguage': 'Выберите ваш язык',
      'languageChanged': 'Язык успешно изменён',
      'login': 'Войти',
      'register': 'Регистрация',
      'signIn': 'Войти',
      'signUp': 'Зарегистрироваться',
      'welcomeBack': 'С возвращением',
      'createAccount': 'Создать аккаунт',
      'loginToContinue': 'Войдите, чтобы продолжить',
      'joinPowerFanNetwork': 'Присоединиться к POWER FAN NETWORK',
      'username': 'Имя пользователя',
      'email': 'Электронная почта',
      'password': 'Пароль',
      'confirmPassword': 'Подтвердите пароль',
      'referralCode': 'Реферальный код',
      'referralCodeOptional': 'Реферальный код (необязательно)',
      'enterUsername': 'Введите имя пользователя',
      'enterEmail': 'Введите электронную почту',
      'enterPassword': 'Введите пароль',
      'enterReferralCode': 'Введите реферальный код',
      'forgotPassword': 'Забыли пароль?',
      'resetPassword': 'Сбросить пароль',
      'dontHaveAccount': 'Нет аккаунта?',
      'alreadyHaveAccount': 'Уже есть аккаунт?',
      'passwordHidden': 'Пароль скрыт',
      'passwordVisible': 'Пароль виден',
      'home': 'Главная',
      'balance': 'Баланс',
      'fanBalance': 'Баланс FAN',
      'afamBalance': 'Баланс AFAM',
      'miningBalance': 'Баланс майнинга',
      'originalCoin': 'Исходная монета',
      'mining': 'Майнинг',
      'startMining': 'НАЧАТЬ МАЙНИНГ',
      'miningNow': 'МАЙНИНГ',
      'miningStopped': 'Майнинг остановлен',
      'claimMining': 'ПОЛУЧИТЬ НАГРАДУ',
      'claim': 'Получить',
      'claimed': 'Получено',
      'miningRate': 'Скорость майнинга',
      'fanPerHour': 'FAN / Час',
      'remainingTime': 'Оставшееся время',
      'miningSession': 'Сессия майнинга',
      'miningEndsIn': 'Майнинг закончится через',
      'miningStarted': 'Майнинг успешно начат',
      'miningCompleted': 'Сессия майнинга завершена',
      'boostMining': 'Ускорить майнинг',
      'boost': 'Ускорение',
      'watchAd': 'СМОТРЕТЬ РЕКЛАМУ',
      'adsWatched': 'Просмотрено рекламы',
      'dailyAds': 'Ежедневная реклама',
      'maxAds': 'Максимум рекламы',
      'boostPerAd': '+0.1 FAN/H за рекламу',
      'maximumBoost': 'Максимальное ускорение: +0.7 FAN/H',
      'adReward': 'Награда за рекламу',
      'rewardedAd': 'Реклама с наградой',
      'watchAdsToBoost': 'Смотрите рекламу, чтобы увеличить скорость майнинга',
      'adSystemComingSoon': 'Система рекламы с наградами скоро появится',
      'dailySocialTask': 'Ежедневное социальное задание',
      'socialTasks': 'Социальные задания',
      'dailyTasks': 'Ежедневные задания',
      'completeTask': 'Выполнить задание',
      'openTask': 'ОТКРЫТЬ ЗАДАНИЕ',
      'verifyTask': 'ПРОВЕРИТЬ ЗАДАНИЕ',
      'claimReward': 'ПОЛУЧИТЬ НАГРАДУ',
      'taskCompleted': 'Задание выполнено',
      'taskClaimed': 'Награда уже получена',
      'taskNotReady': 'Сначала выполните необходимые действия',
      'follow': 'Подписаться',
      'comment': 'Комментарий',
      'share': 'Поделиться',
      'checkIn': 'Отметиться',
      'dailyCheckIn': 'Ежедневная отметка',
      'socialReward': 'Социальная награда',
      'fanReward': 'Награда FAN',
      'facebook': 'Facebook',
      'instagram': 'Instagram',
      'telegram': 'Telegram',
      'tiktok': 'TikTok',
      'twitterX': 'X',
      'youtube': 'YouTube',
      'referral': 'Рефералы',
      'referrals': 'Рефералы',
      'inviteFriends': 'Пригласить друзей',
      'inviteAndEarn': 'Приглашайте и зарабатывайте',
      'myReferralCode': 'Мой реферальный код',
      'copyCode': 'КОПИРОВАТЬ КОД',
      'shareCode': 'ПОДЕЛИТЬСЯ КОДОМ',
      'copied': 'Скопировано',
      'totalReferrals': 'Всего рефералов',
      'activeReferrals': 'Активные рефералы',
      'referralEarnings': 'Доход от рефералов',
      'referralReward': 'Реферальная награда',
      'newUserReward': 'Новый пользователь получает 20 FAN',
      'miningBonus': 'Бонус майнинга',
      'perActiveReferral': '+0.02 FAN/H за активного реферала',
      'referralHowItWorks': 'Как работает реферал',
      'referralStepOne': 'Поделитесь своим реферальным кодом с друзьями.',
      'referralStepTwo': 'Друг присоединяется по вашему коду.',
      'referralStepThree': 'Вы получаете 5 FAN и бонус к майнингу.',
      'wallet': 'Кошелёк',
      'afamWallet': 'Кошелёк AFAM',
      'fanMiningBalance': 'Баланс майнинга FAN',
      'migration': 'Миграция',
      'migrate': 'МИГРИРОВАТЬ',
      'migrationComingSoon': 'Миграция скоро будет доступна',
      'migrationInfo': 'Ваш баланс FAN позже можно будет перевести в AFAM.',
      'migrationRate': 'Курс миграции',
      'oneHundredFanOneAfam': '100 FAN = 1 AFAM',
      'transactions': 'Транзакции',
      'noTransactions': 'Транзакций пока нет',
      'send': 'ОТПРАВИТЬ',
      'receive': 'ПОЛУЧИТЬ',
      'sendAfam': 'Отправить AFAM',
      'receiveAfam': 'Получить AFAM',
      'usernameTransactions': 'Транзакции выполняются по имени пользователя.',
      'walletSecurity': 'Безопасность кошелька',
      'walletSecurityMessage': 'Защищайте свой аккаунт. Никому не сообщайте пароль и данные проверки.',
      'kyc': 'KYC',
      'kycVerification': 'Проверка KYC',
      'faceVerification': 'Проверка лица',
      'faceVerificationComingSoon': 'Проверка лица скоро будет доступна',
      'kycComingSoon': 'KYC скоро будет доступен',
      'kycRequirements': 'Требования KYC',
      'kycRequirementOne': 'Выполняйте ежедневную отметку 30 дней подряд.',
      'kycRequirementTwo': 'Выполняйте хотя бы одно ускорение каждый день в течение 30 дней.',
      'kycRequirementThree': 'После этого пройдите проверку лица.',
      'thirtyDayCheckIn': '30 дней ежедневной отметки',
      'thirtyDayBoost': '30 дней ежедневного ускорения',
      'kycUnlocked': 'KYC разблокирован',
      'kycLocked': 'KYC заблокирован',
      'startFaceVerification': 'НАЧАТЬ ПРОВЕРКУ ЛИЦА',
      'verificationInProgress': 'Проверка выполняется',
      'verificationComplete': 'Проверка завершена',
      'keepFaceVisible': 'Держите лицо в поле камеры.',
      'lookAtCamera': 'Смотрите прямо в камеру.',
      'verificationSeconds': 'Проверка 30 секунд',
      'secondsRemaining': 'секунд осталось',
      'cameraPermissionRequired': 'Требуется разрешение камеры',
      'cameraPermissionMessage': 'Для проверки лица в реальном времени нужен доступ к камере.',
      'oneDeviceOneAccount': 'Одно устройство = Один аккаунт',
      'deviceSecurity': 'Безопасность устройства',
      'livenessWarning': 'Проверка с помощью камеры помогает защитить сеть, но один 30-секундный таймер не является полной биометрической проверкой живого человека.',
      'settings': 'Настройки',
      'account': 'Аккаунт',
      'profile': 'Профиль',
      'notifications': 'Уведомления',
      'security': 'Безопасность',
      'privacy': 'Конфиденциальность',
      'about': 'О приложении',
      'help': 'Помощь',
      'logout': 'Выйти',
      'logoutConfirm': 'Вы уверены, что хотите выйти?',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'close': 'Закрыть',
      'continue': 'Продолжить',
      'done': 'Готово',
      'refresh': 'Обновить',
      'retry': 'Повторить',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'success': 'Успешно',
      'failed': 'Не удалось',
      'comingSoon': 'Скоро',
      'enabled': 'Включено',
      'disabled': 'Выключено',
      'yes': 'Да',
      'no': 'Нет',
      'today': 'Сегодня',
      'tomorrow': 'Завтра',
      'loginRequired': 'Сначала войдите в аккаунт.',
      'invalidEmail': 'Введите действительный адрес электронной почты.',
      'invalidPassword': 'Пароль должен содержать не менее 6 символов.',
      'invalidUsername': 'Введите действительное имя пользователя.',
      'passwordsDoNotMatch': 'Пароли не совпадают.',
      'somethingWentWrong': 'Что-то пошло не так.',
      'networkError': 'Ошибка сети. Попробуйте снова.',
      'noInternet': 'Нет подключения к интернету.',
      'operationSuccessful': 'Операция выполнена успешно.',
      'claimRequiresAd': 'Посмотрите рекламу с наградой перед получением награды за 24 часа майнинга.',
      'claimAdMessage': 'После завершения рекламы награда будет получена, и автоматически начнётся новый 24-часовой сеанс.',
      'dailyBoostRequired': 'Требуется ежедневное ускорение',
      'dailyBoostReminder': 'Смотрите хотя бы одну рекламу для ускорения каждый день, чтобы оставаться активным и продвигаться к KYC.',
      'miningRules': 'Правила майнинга',
      'miningRuleClaim24h': 'Получайте награду после каждого 24-часового сеанса.',
      'miningRuleRateIncrease': 'Скорость майнинга может увеличиваться только благодаря одобренным ускорениям и активным рефералам.',
      'miningRuleDailyBoost': 'Выполняйте хотя бы одно ускорение каждый день, чтобы оставаться активным.',
      'robotWarning': 'Использование роботов и автоматизированная активность запрещены.',
      'unauthorizedActivity': 'Несанкционированные методы, боты, скрипты и другие злоупотребления могут привести к ограничению или блокировке аккаунта.',
      'accountRestrictionWarning': 'Мы можем проверять и ограничивать аккаунты, нарушающие правила сети. Мера зависит от нарушения.',
      'deviceAlreadyRegistered': 'Это устройство уже связано с другим аккаунтом.',
      'oneDeviceRuleMessage': 'Один человек может использовать один аккаунт на одном устройстве. Несколько аккаунтов на одном устройстве запрещены.',
      'boostCompleted': 'Ускорение успешно выполнено.',
      'dailyBoostCompleted': 'Сегодняшнее ускорение выполнено.',
    },
