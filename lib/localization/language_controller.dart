import 'package:flutter/material.dart';

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance =
      LanguageController._();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isArabic => _locale.languageCode == 'ar';

  void setLanguage(String languageCode) {
    final newLocale = Locale(languageCode);

    if (_locale.languageCode == newLocale.languageCode) {
      return;
    }

    _locale = newLocale;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (_locale.languageCode == locale.languageCode) {
      return;
    }

    _locale = locale;
    notifyListeners();
  }

  void resetToEnglish() {
    setLanguage('en');
  }
}
