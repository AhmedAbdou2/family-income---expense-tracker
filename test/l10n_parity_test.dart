import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every UI string must live in the ARB files - this test keeps
/// app_en.arb and app_ar.arb in perfect sync.
void main() {
  Map<String, Object?> loadArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  Set<String> messageKeys(Map<String, Object?> arb) => arb.keys
      .where((key) => !key.startsWith('@'))
      .toSet();

  test('app_en.arb and app_ar.arb have identical message keys', () {
    final en = loadArb('lib/core/l10n/app_en.arb');
    final ar = loadArb('lib/core/l10n/app_ar.arb');

    final enKeys = messageKeys(en);
    final arKeys = messageKeys(ar);

    final missingInAr = enKeys.difference(arKeys);
    final missingInEn = arKeys.difference(enKeys);

    expect(missingInAr, isEmpty, reason: 'missing Arabic translations');
    expect(missingInEn, isEmpty, reason: 'extra Arabic translations');
  });

  test('no message is left untranslated (empty or identical placeholder)', () {
    final en = loadArb('lib/core/l10n/app_en.arb');
    final ar = loadArb('lib/core/l10n/app_ar.arb');

    for (final key in messageKeys(en)) {
      expect(ar[key], isNotNull, reason: 'missing ar value for $key');
      expect((ar[key] as String).trim(), isNotEmpty, reason: 'empty ar value for $key');
    }
  });

  test('locales are declared in each file', () {
    expect(loadArb('lib/core/l10n/app_en.arb')['@@locale'], 'en');
    expect(loadArb('lib/core/l10n/app_ar.arb')['@@locale'], 'ar');
  });

  /// Every `{placeholder}` in a message (works for plain `{currency}` and for
  /// `{count, plural, ...}` alike).
  Set<String> placeholders(Object? value) {
    if (value is! String) return const {};
    return RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\s*[,}]')
        .allMatches(value)
        .map((match) => match.group(1)!)
        .toSet();
  }

  test('placeholders match between the two languages', () {
    final en = loadArb('lib/core/l10n/app_en.arb');
    final ar = loadArb('lib/core/l10n/app_ar.arb');

    for (final key in messageKeys(en)) {
      expect(
        placeholders(ar[key]),
        placeholders(en[key]),
        reason: 'placeholder mismatch for "$key"',
      );
    }
  });

  test('a plural message in English is plural in Arabic too', () {
    final en = loadArb('lib/core/l10n/app_en.arb');
    final ar = loadArb('lib/core/l10n/app_ar.arb');

    for (final key in messageKeys(en)) {
      final enIsPlural = (en[key] as String).contains(', plural,');
      final arIsPlural = (ar[key] as String).contains(', plural,');
      expect(arIsPlural, enIsPlural, reason: 'plural mismatch for "$key"');
      if (enIsPlural) {
        expect(
          (ar[key] as String).contains('other{'),
          isTrue,
          reason: 'Arabic plural "$key" must keep an "other" branch',
        );
      }
    }
  });

  test('Arabic plurals carry the Arabic CLDR categories', () {
    final ar = loadArb('lib/core/l10n/app_ar.arb');

    for (final key in messageKeys(ar)) {
      final value = ar[key] as String;
      if (!value.contains(', plural,')) continue;
      // Arabic needs more than English's one/other; the app uses the full set
      // (zero is optional - it only reads better for "nothing to delete").
      for (final category in const ['one', 'two', 'few', 'many', 'other']) {
        expect(
          value.contains('$category{'),
          isTrue,
          reason: 'Arabic plural "$key" is missing the "$category" category',
        );
      }
    }
  });
}
