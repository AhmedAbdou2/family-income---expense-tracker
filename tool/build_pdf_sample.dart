// Builds the Arabic PDF summary sample that AMENDMENT F requires a human to
// eyeball before the PDF path is wired into the app.
//
// Run from the project root:
//   dart run tool/build_pdf_sample.dart
// then render it and LOOK at the letters:
//   pdftoppm -r 150 -png docs/phase4b/pdf-sample-ar.pdf /tmp/phase4b-ar
//
// Why a sample at all: the `pdf` package shapes Arabic itself (BiDi +
// contextual letter forms), and `pdftotext` cannot prove that - the extracted
// characters look the same whether the letters were joined or not. Only the
// rendered pixels can.
import 'dart:io';

import 'package:family_income_expense_tracker/features/export/domain/month_summary.dart';
import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';

final _month = DateTime(2026, 6, 15);

final _rows = <Transaction>[
  Transaction(
    id: 's1',
    householdId: 'h1',
    type: TransactionType.income,
    amountMinorUnits: 1200000,
    categoryId: 'salary',
    memberId: 'm1',
    date: _month,
  ),
  Transaction(
    id: 's2',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 234567,
    categoryId: 'food',
    memberId: 'm1',
    date: _month,
  ),
  Transaction(
    id: 's3',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 90000,
    categoryId: 'pet_food',
    memberId: 'm2',
    date: _month,
  ),
];

Future<void> main() async {
  final regular = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();

  final summary = MonthSummary.fromTransactions(
    _rows,
    categoryNames: const {
      'salary': 'الراتب',
      'food': 'الطعام والبقالة',
      'pet_food': 'طعام الحيوانات الأليفة',
    },
    memberNames: const {'m1': 'أحمد', 'm2': 'فاطمة'},
  );

  final bytes = await buildMonthSummaryPdf(
    labels: const PdfSummaryLabels(
      title: 'الملخص الشهري',
      householdLabel: 'الأسرة',
      periodLabel: 'الفترة',
      incomeLabel: 'الإيرادات',
      expensesLabel: 'المصروفات',
      balanceLabel: 'الرصيد',
      byCategoryLabel: 'المصروفات حسب التصنيف',
      byPersonLabel: 'الإنفاق حسب الشخص',
      emptyLabel: 'لا توجد عمليات في هذه الفترة.',
      footer: 'تطبيق متابعة إيرادات ومصروفات الأسرة',
    ),
    householdName: 'أسرة أحمد',
    periodText: 'يونيو ٢٠٢٦',
    summary: summary,
    currencyCode: 'ج.م',
    rtl: true,
    arabicDigits: true,
    regularFont: regular,
    boldFont: bold,
  );

  final output = File('docs/phase4b/pdf-sample-ar.pdf');
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(bytes);

  // The two halves of the automated proof: the font program really is
  // embedded, and the file is a real PDF. Whether the glyphs are CONNECTED
  // and in RTL order is the rendered-PNG check above.
  final raw = String.fromCharCodes(bytes);
  stdout.writeln('wrote ${output.path} (${bytes.length} bytes)');
  stdout.writeln('embedded font program: ${raw.contains('FontFile2')}');
  stdout.writeln('cairo family name in fonts: ${raw.contains('Cairo')}');
}
