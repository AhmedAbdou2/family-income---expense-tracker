import 'dart:io';
import 'dart:typed_data';

import 'package:family_income_expense_tracker/features/export/domain/arabic_pdf_font.dart';
import 'package:family_income_expense_tracker/features/export/domain/month_summary.dart';
import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'support/pdf_glyph_metrics.dart';

/// The pdf package rewrites Arabic letters to their legacy *Presentation
/// Forms-B* code points. Cairo is a modern font and carries no glyph for the
/// isolated forms, so the pdf package's `basicToIsolatedMappings` is supposed
/// to point each base letter at its isolated form - but it maps YEH (U+064A)
/// to U+FEEF (the ALEF MAKSURA isolated form) instead of U+FEF1. The shaper's
/// U+FEF1 then has no glyph, gets an advance width of 0, and the letter is
/// drawn on top of its neighbour.
///
/// This file makes that failure machine-checkable:
///
///  * `the detector flags the pre-fix title` proves the check really fails on a
///    document built from the raw font (otherwise the guard would be useless);
///  * `no drawn glyph has a zero advance` runs the whole word list through the
///    real `buildMonthSummaryPdf` in both weights and forbids a zero advance
///    for anything but an Arabic combining mark.
///
/// The overlapping YEH shows up as a word ending in a YEH right after a
/// non-joining letter (`ري`, `اي`, `وي`, ...): the YEH is then written in its
/// isolated form. `الملخص الشهري`, `شاي`, `المصري`, `الدوري` and `البدوي` all
/// hit it, which is why shortening the title only hid the bug.
const List<String> failingClassWords = <String>[
  'الملخص الشهري', // the title the fixture used before the fix
  'ملخص الشهر', // the title the app ships today
  'شاي',
  'المصري',
  'الدوري',
  'البدوي',
];

const List<String> realWords = <String>[
  'ديون',
  'زكريا',
  'ريال',
  'دين',
  'إيجار',
  'وقود',
  'اشتراكات',
  'طعام',
  'مواصلات',
  'صحة',
  'تعليم',
  'ترفيه',
  'هدايا',
];

final _regular = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
final _bold = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();

/// One collision: the zero-advance glyph and the neighbour drawn on top of it.
typedef _Collision = (PdfDrawnGlyph glyph, PdfDrawnGlyph? neighbour);

/// Every drawn glyph with no advance that is not a combining mark - the exact
/// collision the guard forbids.
List<_Collision> _zeroAdvanceGlyphs(Uint8List pdf) {
  final collisions = <_Collision>[];
  for (final run in readPdfGlyphRuns(pdf)) {
    for (var i = 0; i < run.glyphs.length; i++) {
      final glyph = run.glyphs[i];
      if (glyph.advance == 0 && !isArabicDiacritic(glyph.codePoint)) {
        collisions.add((
          glyph,
          i + 1 < run.glyphs.length ? run.glyphs[i + 1] : null,
        ));
      }
    }
  }
  return collisions;
}

/// A one-line document built straight from the given font bytes, so the guard
/// can be pointed at the *unpatched* font.
Future<Uint8List> _linePdf(String text, {required bool bold}) async {
  final document = pw.Document(compress: true);
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(ByteData.sublistView(_regular)),
    bold: pw.Font.ttf(ByteData.sublistView(_bold)),
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      textDirection: pw.TextDirection.rtl,
      build: (_) => <pw.Widget>[
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            wordSpacing: 2,
          ),
        ),
      ],
    ),
  );
  return document.save();
}

/// The real path: the app's labels with [word] as the title (bold), the
/// household name and the period text, so the word is drawn in both weights.
Future<Uint8List> _summaryPdf(String word) => buildMonthSummaryPdf(
  labels: PdfSummaryLabels(
    title: word,
    householdLabel: word,
    periodLabel: word,
    incomeLabel: word,
    expensesLabel: word,
    balanceLabel: word,
    byCategoryLabel: word,
    byPersonLabel: word,
    emptyLabel: word,
    footer: word,
  ),
  householdName: word,
  periodText: word,
  summary: const MonthSummary(
    incomeMinorUnits: 0,
    expensesMinorUnits: 0,
    byCategory: [],
    byPerson: [],
  ),
  currencyCode: 'ج.م',
  rtl: true,
  arabicDigits: true,
  regularFont: _regular,
  boldFont: _bold,
);

void main() {
  test(
    'the detector flags the pre-fix title (raw font, both weights)',
    () async {
      // Without this the guard below could never fail, which is what let the
      // overlap ship in the first place.
      for (final bold in <bool>[false, true]) {
        final pdf = await _linePdf('الملخص الشهري', bold: bold);
        final collisions = _zeroAdvanceGlyphs(pdf);

        expect(
          collisions,
          isNotEmpty,
          reason: 'the raw font must produce the overlapping YEH',
        );
        final yeh = collisions
            .map((c) => c.$1)
            .firstWhere(
              (g) => g.codePoint == 0xFEF1,
              orElse: () {
                throw StateError(
                  'expected an isolated YEH (U+FEF1), got '
                  '${collisions.map((c) => c.$1.codePoint.toRadixString(16))}',
                );
              },
            );
        final neighbour = collisions
            .firstWhere((c) => c.$1.codePoint == 0xFEF1)
            .$2;
        // ignore: avoid_print
        print(
          'pre-fix ${bold ? 'bold' : 'regular'}: overlapping pair '
          '$yeh over ${neighbour ?? 'its neighbour'}',
        );
      }
    },
  );

  test('no drawn glyph has a zero advance (regular and bold)', () async {
    for (final word in <String>[...failingClassWords, ...realWords]) {
      final pdf = await _summaryPdf(word);
      final collisions = _zeroAdvanceGlyphs(pdf);
      expect(
        collisions,
        isEmpty,
        reason:
            '"$word" draws '
            '${collisions.map((c) => '${c.$1} over ${c.$2}').toList()}',
      );
    }
  });

  test('the fix resolves every isolated form the shaper can emit', () {
    // Pins the table the fix relies on: each standard letter must have an
    // isolated Presentation Forms-B code point.
    expect(arabicIsolatedForms.length, 36);
    expect(arabicIsolatedForms[0x064A], 0xFEF1); // YEH
    expect(arabicIsolatedForms[0x0649], 0xFEEF); // ALEF MAKSURA
    expect(arabicIsolatedForms[0x0631], 0xFEAD); // REH
    expect(arabicIsolatedForms[0x0627], 0xFE8D); // ALEF
  });

  test(
    'the committed Arabic sample draws the isolated YEH without overlap',
    () {
      // The sample in docs/phase4b is what a human eyeballs, so it must itself
      // exercise the bug: the household name ends in `الشهري` (an isolated YEH)
      // and the title must be the app's real `ملخص الشهر`.
      final file = File('docs/phase4b/pdf-sample-ar.pdf');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run: dart run tool/build_pdf_sample.dart',
      );

      final pdf = file.readAsBytesSync();
      final runs = readPdfGlyphRuns(pdf);
      final codePoints = runs
          .expand((r) => r.glyphs)
          .map((g) => g.codePoint)
          .toSet();

      expect(
        codePoints,
        contains(0xFEF1),
        reason: 'the sample must actually draw the isolated YEH',
      );

      final collisions = _zeroAdvanceGlyphs(pdf);
      expect(
        collisions,
        isEmpty,
        reason:
            'the sample must have no zero-advance glyph: '
            '${collisions.map((c) => '${c.$1} over ${c.$2}').toList()}',
      );
    },
  );
}
