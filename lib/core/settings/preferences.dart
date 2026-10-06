import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the pre-loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Typed access to the small set of user preferences stored on device
/// (language, theme mode, Arabic-Indic digits). Offline cache for reads
/// arrives in Phase 4 with drift - this is only settings persistence.
class AppPreferences {
  AppPreferences(this._prefs);

  static const _kLocale = 'pref_locale';
  static const _kThemeMode = 'pref_theme_mode';
  static const _kArabicDigits = 'pref_arabic_digits';

  final SharedPreferences _prefs;

  /// null = follow the device language.
  Locale? get locale {
    final value = _prefs.getString(_kLocale);
    return value == null ? null : Locale(value);
  }

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  bool get arabicDigits => _prefs.getBool(_kArabicDigits) ?? false;

  Future<void> setLocale(Locale? value) => value == null
      ? _prefs.remove(_kLocale)
      : _prefs.setString(_kLocale, value.languageCode);

  Future<void> setThemeMode(ThemeMode value) =>
      _prefs.setString(_kThemeMode, value.name);

  Future<void> setArabicDigits(bool value) => _prefs.setBool(_kArabicDigits, value);
}

final preferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);
