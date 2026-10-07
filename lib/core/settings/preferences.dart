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

  // Quick-add defaults: remember the last person/category/type so a repeat
  // entry takes three taps (+, digits, save).
  static const _kQuickType = 'quick_add_type';
  static const _kQuickCategory = 'quick_add_category';
  static const _kQuickMember = 'quick_add_member';

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

  String? get quickAddType => _prefs.getString(_kQuickType);
  String? get quickAddCategoryId => _prefs.getString(_kQuickCategory);
  String? get quickAddMemberId => _prefs.getString(_kQuickMember);

  Future<void> setQuickAddDefaults({
    required String type,
    required String categoryId,
    required String memberId,
  }) async {
    await _prefs.setString(_kQuickType, type);
    await _prefs.setString(_kQuickCategory, categoryId);
    await _prefs.setString(_kQuickMember, memberId);
  }
}

final preferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);
