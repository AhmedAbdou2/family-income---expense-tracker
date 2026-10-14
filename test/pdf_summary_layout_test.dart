import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/pdf_summary_fixture.dart';
import 'support/arabic_presentation_forms.dart';

/// Machine-checkable layout guard for the PDF summary.
///
/// The Arabic sheet is built right-to-left, but the `pdf` package lays every
/// Row and Table out left-to-right, so the *positions* (not just the letters)
/// have to be asserted. This test renders the exact sample the human reviews,
/// asks Poppler (`pdftotext -bbox-layout`) where every word landed, and checks
/// the reading order:
///
///  * Arabic: the header title sits at the RIGHT margin, every table puts the
///    name to the right of the amount, and the summary row reads
///    income -> expenses -> balance from right to left.
///  * English: the mirror image (title at the LEFT margin, name left of the
///    amount).
///  * The month/year gap is a real space, and the full title is present.
///
/// Poppler is not always installed, so the suite skips (with a reason) when
/// `pdftotext` is missing instead of failing the build.
final bool _popplerAvailable = _checkPoppler();

bool _checkPoppler() {
  try {
    return Process.runSync('pdftotext', ['-v']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

const String _skipReason = 'pdftotext (poppler) is not installed';
final Object? _skip = _popplerAvailable ? null : _skipReason;

class _Word {
  _Word(this.xMin, this.yMin, this.xMax, this.yMax, this.text);

  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;
  final String text;

  @override
  String toString() => '$text@[$xMin-$xMax]';
}

List<_Word> _extract(List<int> bytes) {
  final dir = Directory.systemTemp.createTempSync('pdf-layout');
  try {
    final file = File('${dir.path}/sample.pdf')..writeAsBytesSync(bytes);
    final out = File('${dir.path}/out.html');
    final result = Process.runSync('pdftotext', [
      '-bbox-layout',
      file.path,
      out.path,
    ]);
    if (result.exitCode != 0) {
      throw StateError('pdftotext failed: ${result.stderr}');
    }
    final html = out.readAsStringSync();
    final word = RegExp(
      r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>',
    );
    return [
      for (final m in word.allMatches(html))
        _Word(
          double.parse(m[1]!),
          double.parse(m[2]!),
          double.parse(m[3]!),
          double.parse(m[4]!),
          _unescape(m[5]!),
        ),
    ];
  } finally {
    dir.deleteSync(recursive: true);
  }
}

String _unescape(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");

bool _isDigit(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || (rune >= 0x0660 && rune <= 0x0669);

/// Turns one `pdftotext` word back into logical text.
///
/// Numbers are left alone (BiDi keeps their digits in order; only the digits
/// themselves are normalised). A shaped Arabic word is decoded glyph by glyph
/// in reverse, so contextual forms and lam-alef ligatures come out as the base
/// letters in their original order - which is how the test can tell whether
/// the title lost its last letter.
String _normalize(String word) {
  final runes = word.runes.toList();
  if (runes.any(_isDigit)) {
    return String.fromCharCodes(
      runes.map((r) => (r >= 0x0660 && r <= 0x0669) ? r - 0x0660 + 0x30 : r),
    );
  }
  final hasArabic = runes.any(
    (r) => (r >= 0x0600 && r <= 0x06FF) || (r >= 0xFE70 && r <= 0xFEFF),
  );
  if (!hasArabic) return word;
  final buffer = StringBuffer();
  for (final rune in runes.reversed) {
    buffer.write(kArabicPresentationForms[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

List<_Word> _rowOf(List<_Word> words, _Word anchor) =>
    words.where((w) => (w.yMin - anchor.yMin).abs() < 2).toList();

/// The amount words on [anchor]'s line (a number and its separate currency).
List<_Word> _amountsOnLine(List<_Word> words, _Word anchor) => _rowOf(words, anchor)
    .where((w) => _normalize(w.text).contains(RegExp(r'\d')))
    .toList();

_Word _find(List<_Word> words, String normalized) {
  final matches = words.where((w) => _normalize(w.text) == normalized);
  expect(matches, hasLength(1), reason: 'expected exactly one "$normalized"');
  return matches.single;
}

/// A person/category name appears both in the header ("Family: Ahmed") and in
/// a table; pick the one that shares its line with an amount.
_Word _findInTable(List<_Word> words, String normalized) {
  final matches = words
      .where((w) => _normalize(w.text) == normalized)
      .where((w) => _amountsOnLine(words, w).isNotEmpty);
  expect(matches, hasLength(1), reason: 'expected one table row "$normalized"');
  return matches.single;
}

void main() {
  late List<_Word> ar;
  late List<_Word> en;

  setUpAll(() async {
    if (!_popplerAvailable) return;
    ar = _extract(await buildSamplePdf(arabic: true));
    en = _extract(await buildSamplePdf(arabic: false));
  });

  group('Arabic summary', skip: _skip, () {
    test('the header title is at the right margin and complete', () {
      final titleRow = _rowOf(ar, _find(ar, 'ملخص'))
        ..sort((a, b) => b.xMin.compareTo(a.xMin));
      final title = titleRow.map((w) => _normalize(w.text)).join(' ');

      expect(title, 'ملخص الشهر',
          reason: 'the full bold title must be laid out (no lost final letter)');
      expect(titleRow.first.xMax, greaterThan(595 - 80),
          reason: 'the title must start at the right margin');
      expect(titleRow.last.xMin, greaterThan(40),
          reason: 'the title must stay inside the page');
      expect(titleRow.first.xMax, lessThan(595),
          reason: 'the title must not overflow the page');
    });

    test('every table puts the name to the RIGHT of the amount', () {
      for (final name in const ['الطعام', 'الحيوانات', 'أحمد', 'فاطمة']) {
        final nameWord = _findInTable(ar, name);
        for (final amountWord in _amountsOnLine(ar, nameWord)) {
          expect(nameWord.xMin, greaterThan(amountWord.xMax),
              reason: '"$name" must be right of ${amountWord.text}');
        }
      }
    });

    test('the summary row reads income -> expenses -> balance (RTL)', () {
      final income = _find(ar, '12,000.00');
      final expenses = _find(ar, '3,245.67');
      final balance = _find(ar, '8,754.33');

      expect(income.xMin, greaterThan(expenses.xMin),
          reason: 'income must be the rightmost figure');
      expect(expenses.xMin, greaterThan(balance.xMin),
          reason: 'the balance must be the leftmost figure');
    });

    test('the month and year are separated by a real space', () {
      final month = _find(ar, 'يونيو');
      final year = _find(ar, '2026');

      expect(month.xMin - year.xMax, greaterThanOrEqualTo(2.0),
          reason: 'bidi must not glue "يونيو" and "٢٠٢٦" together');
    });
  });

  group('English summary', skip: _skip, () {    test('the header title is at the left margin', () {
      final titleRow = _rowOf(en, _find(en, 'Monthly'))
        ..sort((a, b) => a.xMin.compareTo(b.xMin));

      expect(titleRow.map((w) => w.text).join(' '), 'Monthly summary');
      expect(titleRow.first.xMin, lessThan(80));
    });

    test('every table puts the name to the LEFT of the amount', () {
      for (final name in const ['Food', 'Pets', 'Ahmed', 'Fatima']) {
        final nameWord = _findInTable(en, name);
        for (final amountWord in _amountsOnLine(en, nameWord)) {
          expect(nameWord.xMax, lessThan(amountWord.xMin),
              reason: '"$name" must be left of ${amountWord.text}');
        }
      }
    });

    test('the summary row reads income -> expenses -> balance (LTR)', () {
      final income = _find(en, '12,000.00');
      final expenses = _find(en, '3,245.67');
      final balance = _find(en, '8,754.33');

      expect(income.xMin, lessThan(expenses.xMin));
      expect(expenses.xMin, lessThan(balance.xMin));
    });
  });
}
