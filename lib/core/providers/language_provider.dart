import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _appLocale = const Locale('en'); // Default

  Locale get appLocale => _appLocale;

  // Load saved language on startup
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    String? langCode = prefs.getString('language_code');

    if (langCode != null) {
      _appLocale = Locale(langCode);
      notifyListeners();
    }
  }

  // Change language and save it
  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);

    _appLocale = Locale(languageCode);
    notifyListeners();
  }
}
