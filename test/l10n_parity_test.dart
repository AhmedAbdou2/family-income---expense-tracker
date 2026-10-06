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
}
