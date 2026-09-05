import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance =
      LanguageController._();

  static const String _languageKey = 'selected_language';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage =
        prefs.getString(_languageKey);

    if (savedLanguage == null ||
        savedLanguage.trim().isEmpty) {
      return;
    }

    _locale = Locale(savedLanguage);
    notifyListeners();
  }

  Future<void> setLanguage(
    String languageCode,
  ) async {
    final code = languageCode.trim().toLowerCase();

    if (code.isEmpty) {
      return;
    }

    final newLocale = Locale(code);

    if (_locale.languageCode == newLocale.languageCode) {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        _languageKey,
        code,
      );

      return;
    }

    _locale = newLocale;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _languageKey,
      code,
    );

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    await setLanguage(locale.languageCode);
  }

  Future<void> resetToEnglish() async {
    await setLanguage('en');
  }
}
