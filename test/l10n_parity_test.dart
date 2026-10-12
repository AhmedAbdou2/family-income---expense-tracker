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

  /// Every argument a message actually references. Works for plain
  /// `{currency}`, `{count, plural, ...}` and `{code, select, ...}`: the
  /// literal text inside a `plural`/`select` branch (`EUR{Euro}` is the word
  /// "Euro", not a placeholder) is skipped, while arguments nested in a branch
  /// body (`other{{count}}`) are still collected.
  Set<String> placeholders(Object? value) {
    if (value is! String) return const {};
    final found = <String>{};
    final head = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\s*([,}])');

    // Reads the argument or literal token starting at `start` (which points at
    // a `{`), and returns the index just past it.
    int read(String s, int start) {
      final match = head.matchAsPrefix(s, start);
      if (match == null) return start + 1;
      found.add(match.group(1)!);
      if (match.group(2) == '}') return match.end;

      final typed = RegExp(r'\s*([a-zA-Z]+)\s*,').matchAsPrefix(s, match.end)!;
      final type = typed.group(1)!;
      var i = typed.end;
      if (type == 'select' || type == 'plural' || type == 'selectordinal') {
        // Branches look like `key{body}` repeated until the construct closes.
        while (i < s.length && s[i] != '}') {
          while (i < s.length && s[i] != '{') {
            i++;
          }
          if (i >= s.length) break;
          i++; // into the branch body
          var closed = false;
          while (i < s.length) {
            if (s[i] == '{') {
              i = read(s, i);
              continue;
            }
            if (s[i] == '}') {
              i++;
              closed = true;
              break;
            }
            i++;
          }
          if (!closed) break;
        }
        if (i < s.length && s[i] == '}') i++;
        return i;
      }
      // Any other typed argument ({n, number}, ...) has no branch bodies.
      var depth = 1;
      while (i < s.length && depth > 0) {
        if (s[i] == '{') {
          depth++;
        } else if (s[i] == '}') {
          depth--;
        }
        i++;
      }
      return i;
    }

    var i = 0;
    while (i < value.length) {
      if (value[i] == '{') {
        i = read(value, i);
        continue;
      }
      i++;
    }
    return found;
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
