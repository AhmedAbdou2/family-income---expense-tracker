import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

class SettingsState {
  const SettingsState({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.arabicDigits = false,
  });

  /// null = follow the device language.
  final Locale? locale;
  final ThemeMode themeMode;
  final bool arabicDigits;

  SettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? arabicDigits,
    bool clearLocale = false,
  }) =>
      SettingsState(
        locale: clearLocale ? null : locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        arabicDigits: arabicDigits ?? this.arabicDigits,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(preferencesProvider);
    return SettingsState(
      locale: prefs.locale,
      themeMode: prefs.themeMode,
      arabicDigits: prefs.arabicDigits,
    );
  }

  void setLocale(Locale? locale) {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    ref.read(preferencesProvider).setLocale(locale);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(preferencesProvider).setThemeMode(mode);
  }

  void setArabicDigits(bool enabled) {
    state = state.copyWith(arabicDigits: enabled);
    ref.read(preferencesProvider).setArabicDigits(enabled);
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);
