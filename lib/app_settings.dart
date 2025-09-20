import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ar'); // افتراضي عربي

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  static const _kThemeKey = 'themeMode';
  static const _kLocaleKey = 'localeCode';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_kThemeKey);
    final l = prefs.getString(_kLocaleKey);

    if (t == 'light') _themeMode = ThemeMode.light;
    else if (t == 'dark') _themeMode = ThemeMode.dark;
    else _themeMode = ThemeMode.system;

    if (l == 'en') _locale = const Locale('en');
    else _locale = const Locale('ar');

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey,
        mode == ThemeMode.light ? 'light' : (mode == ThemeMode.dark ? 'dark' : 'system'));
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    await setLocale(_locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
  }
}
