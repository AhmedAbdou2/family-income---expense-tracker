import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../domain/month_summary.dart';

/// Localized labels the summary sheet prints. Passing them in keeps this
/// file free of l10n lookups (and testable without a widget tree).
class PdfSummaryLabels {
  const PdfSummaryLabels({
    required this.title,
    required this.householdLabel,
    required this.periodLabel,
    required this.incomeLabel,
    required this.expensesLabel,
    required this.balanceLabel,
    required this.byCategoryLabel,
    required this.byPersonLabel,
    required this.emptyLabel,
    required this.footer,
  });

  final String title;
  final String householdLabel;
  final String periodLabel;
  final String incomeLabel;
  final String expensesLabel;
  final String balanceLabel;
  final String byCategoryLabel;
  final String byPersonLabel;
  final String emptyLabel;
  final String footer;
}

/// Extra word spacing for RTL text.
///
/// The Cairo metrics make a single space between an Arabic word and an
/// Arabic-Indic number almost invisible (measured at ~0.5pt for a 12pt font),
/// so `يونيو ٢٠٢٦` printed visibly glued. Doubling the word spacing restores a
/// normal gap without touching the string or the bidi order.
const double _rtlWordSpacing = 2;

/// Renders a [MonthSummary] as a one-page A4 PDF: a full-width header, a
/// right-to-left summary row and two tables (expenses by category, spending
/// by person).
///
/// [rtl] drives the whole page: the `MultiPage` text direction, the header
/// alignment, the table column order and the summary row order. The pdf
/// package lays every row and table out left-to-right, so RTL is achieved by
/// reversing the table columns and letting `AlignmentDirectional` and the
/// page direction put each item against the correct margin.
///
/// [regularFont]/[boldFont] are the embedded Cairo subsets (the default
/// Helvetica has no Arabic glyphs). [arabicDigits] only changes the numerals
/// printed by [Money.format].
///
/// The `pdf` package shapes Arabic itself (BiDi + contextual letter forms),
/// and `pdftotext` cannot prove that - the extracted characters look the same
/// whether the letters were joined or not. Only the rendered pixels can, so
/// the sample in docs/phase4b is reviewed by a human (AMENDMENT F); the
/// machine-checkable position guard lives in test/pdf_summary_layout_test.dart.
/// See docs/phase4b/README.md for the render commands.
Future<Uint8List> buildMonthSummaryPdf({
  required PdfSummaryLabels labels,
  required String householdName,
  required String periodText,
  required MonthSummary summary,
  required String currencyCode,
  bool rtl = false,
  bool arabicDigits = false,
  Uint8List? regularFont,
  Uint8List? boldFont,
}) async {
  final direction = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final wordSpacing = rtl ? _rtlWordSpacing : 1.0;

  final document = pw.Document(
    title: labels.title,
    compress: true,
  );

  final theme = (regularFont != null && boldFont != null)
      ? pw.ThemeData.withFont(
          base: pw.Font.ttf(ByteData.sublistView(regularFont)),
          bold: pw.Font.ttf(ByteData.sublistView(boldFont)),
        ).copyWith(defaultTextStyle: pw.TextStyle(wordSpacing: wordSpacing))
      : null;

  pw.TextStyle style({
    double? fontSize,
    pw.FontWeight? fontWeight,
    PdfColor? color,
  }) =>
      pw.TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        wordSpacing: wordSpacing,
      );

  String amount(int minorUnits) => Money.format(
        minorUnits: minorUnits,
        arabicDigits: arabicDigits,
        currencyCode: currencyCode,
      );

  // The pdf package lays every Table out left-to-right and never mirrors the
  // column order, so an RTL table is built by swapping the columns (amount
  // first, name last) and aligning with AlignmentDirectional: the name hugs
  // the start edge (the right margin in RTL) and the amount the end edge (the
  // left margin).
  pw.Widget table(String title, List<AmountLine> lines) {
    if (lines.isEmpty) {
      return pw.Text(labels.emptyLabel, style: style());
    }
    final nameAlign = pw.AlignmentDirectional.centerStart;
    final amountAlign = pw.AlignmentDirectional.centerEnd;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: style(fontSize: 13)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerCount: 0,
          data: [
            for (final line in lines)
              rtl
                  ? [amount(line.amountMinorUnits), line.name]
                  : [line.name, amount(line.amountMinorUnits)],
          ],
          cellStyle: style(),
          cellAlignments: rtl
              ? {0: amountAlign, 1: nameAlign}
              : {0: nameAlign, 1: amountAlign},
        ),
      ],
    );
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      textDirection: direction,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          labels.footer,
          style: style(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        // pw.Header hardcodes Alignment.topLeft and shrink-wraps its child,
        // which parked the title in a narrow block on the LEFT while the
        // divider ran the full width. A full-width Container that lets the
        // Column align to the start edge keeps the title under the right
        // margin in RTL (and the left margin in LTR), level with the divider.
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide()),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                labels.title,
                style: style(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${labels.householdLabel}: $householdName',
                style: style(),
              ),
              pw.Text('${labels.periodLabel}: $periodText', style: style()),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        // The Row honours the page text direction, so in RTL the income lands
        // at the right margin, expenses in the middle and the balance at the
        // left - the natural Arabic reading order.
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${labels.incomeLabel}: ${amount(summary.incomeMinorUnits)}',
              style: style(),
            ),
            pw.Text(
              '${labels.expensesLabel}: ${amount(summary.expensesMinorUnits)}',
              style: style(),
            ),
            pw.Text(
              '${labels.balanceLabel}: ${amount(summary.balanceMinorUnits)}',
              style: style(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        if (summary.isEmpty)
          pw.Text(labels.emptyLabel, style: style())
        else ...[
          table(labels.byCategoryLabel, summary.byCategory),
          pw.SizedBox(height: 16),
          table(labels.byPersonLabel, summary.byPerson),
        ],
      ],
    ),
  );

  return document.save();
}
