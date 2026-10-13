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

/// Renders a one-month summary sheet.
///
/// The Cairo font bytes are always supplied by the app (see
/// `ExportScreen._exportPdf`): a household on the English UI can still have
/// Arabic category or person names, and the Latin core fonts cannot render
/// them at all. [rtl] only controls the page direction and the column
/// alignment, [arabicDigits] the numeral shape.
///
/// Arabic shaping is done by the `bidi` engine the `pdf` package uses
/// (contextual letter forms + RTL ordering). Because that cannot be verified
/// by reading the bytes back (`pdftotext` shows the same characters either
/// way), the rendered sample in docs/phase4b is reviewed by a human
/// (AMENDMENT F) - see docs/phase4b/README.md for the exact commands.
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
  final document = pw.Document(
    title: labels.title,
    compress: true,
  );

  final theme = (regularFont != null && boldFont != null)
      ? pw.ThemeData.withFont(
          base: pw.Font.ttf(ByteData.sublistView(regularFont)),
          bold: pw.Font.ttf(ByteData.sublistView(boldFont)),
        )
      : null;

  String amount(int minorUnits) => Money.format(
        minorUnits: minorUnits,
        arabicDigits: arabicDigits,
        currencyCode: currencyCode,
      );

  pw.Widget table(String title, List<AmountLine> lines) {
    if (lines.isEmpty) {
      return pw.Text(labels.emptyLabel);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 13)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerCount: 0,
          data: [
            for (final line in lines) [line.name, amount(line.amountMinorUnits)],
          ],
          cellAlignments: const {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
          },
        ),
      ],
    );
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          labels.footer,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                labels.title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text('${labels.householdLabel}: $householdName'),
              pw.Text('${labels.periodLabel}: $periodText'),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${labels.incomeLabel}: ${amount(summary.incomeMinorUnits)}'),
            pw.Text(
              '${labels.expensesLabel}: ${amount(summary.expensesMinorUnits)}',
            ),
            pw.Text(
              '${labels.balanceLabel}: ${amount(summary.balanceMinorUnits)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        if (summary.isEmpty)
          pw.Text(labels.emptyLabel)
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