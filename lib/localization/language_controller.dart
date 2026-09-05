import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance =
      LanguageController._();

  static const String _languageKey = 'selected_language';

  Locale _locale = const Locale('en');

  bool _isLoaded = false;

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isArabic => languageCode == 'ar';

  bool get isLoaded => _isLoaded;

  /// Loads the language previously selected by the user.
  ///
  /// If no language has been saved, English is used.
  Future<void> loadSavedLanguage() async {
    if (_isLoaded) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedLanguage = prefs.getString(_languageKey);

      if (savedLanguage != null &&
          savedLanguage.trim().isNotEmpty &&
          _isSupportedLanguage(savedLanguage)) {
        _locale = Locale(savedLanguage.trim().toLowerCase());
      } else {
        _locale = const Locale('en');
      }
    } catch (_) {
      // If reading local storage fails, keep English.
      _locale = const Locale('en');
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Changes the application language and saves it on the device.
  Future<void> setLanguage(String languageCode) async {
    final code = languageCode.trim().toLowerCase();

    if (!_isSupportedLanguage(code)) {
      return;
    }

    final newLocale = Locale(code);

    if (_locale.languageCode == newLocale.languageCode) {
      // Make sure the currently selected language is still persisted.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languageKey, code);
      } catch (_) {
        // Do not crash the application if local storage fails.
      }

      return;
    }

    _locale = newLocale;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, code);
    } catch (_) {
      // The UI can still change even if persistence fails.
    }

    notifyListeners();
  }

  /// Changes language using a Flutter Locale.
  Future<void> setLocale(Locale locale) async {
    await setLanguage(locale.languageCode);
  }

  /// Resets the application language to English.
  Future<void> resetToEnglish() async {
    await setLanguage('en');
  }

  bool _isSupportedLanguage(String code) {
    return AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == code,
    );
  }
}
