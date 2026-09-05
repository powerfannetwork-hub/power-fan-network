import 'package:flutter/material.dart';

import 'translations/translations.dart';

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  Locale get locale => Locale(code);
}

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

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
    return Localizations.of<AppLocalizations>(
          context,
          AppLocalizations,
        ) ??
        const AppLocalizations(Locale('en'));
  }

  Map<String, String> get _translations {
    return translations[locale.languageCode] ?? translations['en']!;
  }

  String translate(String key) {
    final language = _translations;

    final resolvedKey = _legacyKeyAliases[key] ?? key;

    return language[resolvedKey] ??
        translations['en']![resolvedKey] ??
        language[key] ??
        translations['en']![key] ??
        key;
  }

  String t(String key) {
    return translate(key);
  }

  bool hasTranslation(String key) {
    final resolvedKey = _legacyKeyAliases[key] ?? key;

    return _translations.containsKey(resolvedKey) ||
        translations['en']!.containsKey(resolvedKey);
  }

  static const Map<String, String> _legacyKeyAliases = {
    'mining_loading': 'mining_loading',
    'mining_active': 'mining_active',
    'mining_rate': 'miningRate',
    'session_time': 'session_time',
    'boost_by_watching_ads': 'boostMining',
    'watch_ad': 'watchAd',
    'daily_task': 'dailySocialTask',
    'complete_social_tasks': 'completeTask',
    'no_daily_tasks': 'no_daily_tasks',
    'rewarded_ad_not_connected': 'rewarded_ad_not_connected',

    'claim_mining': 'claimMining',
    'start_mining': 'startMining',
    'fan_balance': 'fanBalance',
    'afam_balance': 'afamBalance',
    'mining_balance': 'miningBalance',
    'remaining_time': 'remainingTime',
    'mining_session': 'miningSession',
    'ads_watched': 'adsWatched',
    'daily_ads': 'dailyAds',
    'max_ads': 'maxAds',
    'boost_mining': 'boostMining',
    'daily_social_task': 'dailySocialTask',
    'complete_task': 'completeTask',
    'open_task': 'openTask',
    'verify_task': 'verifyTask',
    'claim_reward': 'claimReward',
    'task_completed': 'taskCompleted',
    'task_claimed': 'taskClaimed',
    'task_not_ready': 'taskNotReady',
  };
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) =>
          supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) {
    return false;
  }
}
