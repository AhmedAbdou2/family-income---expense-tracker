import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:family_income_expense_tracker/core/utils/money.dart';
import 'package:family_income_expense_tracker/features/export/domain/month_summary.dart';
import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// AMENDMENT F splits the PDF proof in two:
///
///   * machine-checkable - the Cairo subset really is embedded AND the glyphs
///     the page draws are the Arabic *contextual* forms (U+FE70..U+FEFC), not
///     the raw letters. Both are asserted here by decompressing the PDF's own
///     streams.
///   * human - whether those glyphs, as rendered, look connected and run
///     right-to-left. `pdftotext` cannot decide that, so
///     docs/phase4b/pdf-sample-ar.pdf exists to be rendered to a PNG and
///     looked at (see docs/phase4b/README.md).
PdfSummaryLabels _labels({bool arabic = false}) => PdfSummaryLabels(
      title: arabic ? 'الملخص الشهري' : 'Monthly summary',
      householdLabel: arabic ? 'الأسرة' : 'Household',
      periodLabel: arabic ? 'الفترة' : 'Period',
      incomeLabel: arabic ? 'الإيرادات' : 'Income',
      expensesLabel: arabic ? 'المصروفات' : 'Expenses',
      balanceLabel: arabic ? 'الرصيد' : 'Balance',
      byCategoryLabel: arabic ? 'المصروفات حسب التصنيف' : 'By category',
      byPersonLabel: arabic ? 'الإنفاق حسب الشخص' : 'By person',
      emptyLabel: arabic ? 'لا توجد عمليات.' : 'No transactions.',
      footer: arabic ? 'متابعة المصروفات' : 'Expense tracker',
    );

final _arabicRegular = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
final _arabicBold = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();

/// Every FlateDecode stream in the document, inflated and concatenated.
///
/// The PDF writer compresses its streams, so the interesting strings (the
/// font subset, the ToUnicode CMaps, the page content) are not visible in the
/// raw bytes. This makes them searchable.
String _inflatedStreams(Uint8List pdf) {
  final zlib = ZLibDecoder();
  final buffer = StringBuffer();
  var index = 0;
  while (true) {
    final start = _indexOf(pdf, 'stream', index);
    if (start < 0) break;
    // Skip "stream" + EOL.
    var cursor = start + 'stream'.length;
    if (pdf[cursor] == 0x0D) cursor++;
    if (pdf[cursor] == 0x0A) cursor++;
    final end = _indexOf(pdf, 'endstream', cursor);
    if (end < 0) break;
    final chunk = Uint8List.sublistView(pdf, cursor, end);
    try {
      buffer.write(latin1.decode(zlib.convert(chunk)));
    } catch (_) {
      // An uncompressed stream - fine, just read it as-is.
      buffer.write(latin1.decode(chunk));
    }
    index = end + 'endstream'.length;
  }
  return buffer.toString();
}

int _indexOf(Uint8List bytes, String needle, int from) {
  final target = ascii.encode(needle);
  for (var i = from; i <= bytes.length - target.length; i++) {
    var matched = true;
    for (var j = 0; j < target.length; j++) {
      if (bytes[i + j] != target[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  return -1;
}

/// One-word document, so the font subset holds exactly that word's glyphs.
Future<Uint8List> _wordPdf(String word) => buildMonthSummaryPdf(
      labels: _labels(arabic: true),
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
      regularFont: _arabicRegular,
      boldFont: _arabicBold,
    );

void main() {
  test('the document is a real PDF with the embedded font program', () async {
    final bytes = await _wordPdf('الأسرة');
    final raw = latin1.decode(bytes);

    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(raw.contains('FontFile2'), isTrue, reason: 'font program embedded');
    expect(raw.contains('Cairo'), isTrue, reason: 'Cairo family embedded');
  });

  test('the text mapping uses CONTEXTUAL Arabic forms, not raw letters',
      () async {
    // "الملخص" = ا ل م ل خ ص. Correct joining is:
    //   ALEF isolated FE8D, LAM initial FEDF, MEEM medial FEE4,
    //   LAM medial FEE0, KHAH medial FEA8, SAD final FEBA.
    // Every one of those is in the Arabic Presentation Forms-B block, so a
    // page that merely passed the raw letters through (0627, 0644, ...) would
    // fail this test while copying the text out would still "look" Arabic.
    final cmaps = _inflatedStreams(await _wordPdf('الملخص'));

    for (final form in const ['FE8D', 'FEDF', 'FEE4', 'FEE0', 'FEA8', 'FEBA']) {
      expect(cmaps.contains(form), isTrue,
          reason: 'expected contextual form U+$form in the ToUnicode CMap');
    }
    for (final raw_ in const ['0627', '0644', '0645', '062E', '0635']) {
      expect(cmaps.contains(raw_), isFalse,
          reason: 'raw letter U+$raw_ must have been shaped away');
    }
  });

  test('a word with a lam-alef ligature is shaped as that ligature', () async {
    // "لا" is written as the single ligature FEFB (LAM WITH ALEF ISOLATED
    // FORM); a pass-through would leave LAM + ALEF.
    final cmaps = _inflatedStreams(await _wordPdf('لا'));

    expect(cmaps.contains('FEFB'), isTrue,
        reason: 'the lam-alef ligature must be used');
    expect(cmaps.contains('0644'), isFalse);
  });

  test('non-joining letters stay isolated inside a word', () async {
    // In "دور" the DAL (062F) does not join to the following WAW, so the
    // correct forms are: DAL isolated FEA9, WAW final FEEE, REH isolated
    // FEAD. A naive "everything medial" shaper would produce FEB1-ish
    // mistakes, which is exactly what this pins down.
    final cmaps = _inflatedStreams(await _wordPdf('دور'));

    expect(cmaps.contains('FEA9'), isTrue); // DAL isolated
    expect(cmaps.contains('FEEE'), isTrue); // WAW final
    expect(cmaps.contains('FEAD'), isTrue); // REH isolated
  });

  test('the Latin sheet builds without the Cairo subset', () async {
    final summary = MonthSummary.fromTransactions(
      const [],
      categoryNames: const {},
      memberNames: const {},
    );
    final bytes = await buildMonthSummaryPdf(
      labels: _labels(),
      householdName: 'Home',
      periodText: 'June 2026',
      summary: summary,
      currencyCode: 'EGP',
    );

    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(latin1.decode(bytes).contains('FontFile2'), isFalse,
        reason: 'core fonts are used when no TTF is passed');
  });

  test('the sheet carries the exact totals through Money.format', () async {
    const summary = MonthSummary(
      incomeMinorUnits: 5000000,
      expensesMinorUnits: 2384567,
      byCategory: [AmountLine(name: 'Food', amountMinorUnits: 1234567)],
      byPerson: [AmountLine(name: 'Alex', amountMinorUnits: 1234567)],
    );
    final bytes = await buildMonthSummaryPdf(
      labels: _labels(),
      householdName: 'Home',
      periodText: 'June 2026',
      summary: summary,
      currencyCode: 'EGP',
    );

    // The amounts are drawn as text (word by word), so they survive in the
    // inflated content stream - exact minor units, never a rounded float.
    final content = _inflatedStreams(bytes);
    for (final minorUnits in const [5000000, 2384567, 1234567]) {
      final rendered = Money.format(minorUnits: minorUnits, currencyCode: 'EGP');
      // The digits are drawn as their own word (the currency code is separate).
      final digits = rendered.split(' ').first;
      expect(content.contains(digits), isTrue, reason: digits);
    }
  });
}
