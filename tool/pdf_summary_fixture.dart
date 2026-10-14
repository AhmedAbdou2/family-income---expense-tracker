import 'dart:io';
import 'dart:typed_data';

import 'package:family_income_expense_tracker/core/utils/currency.dart';
import 'package:family_income_expense_tracker/features/export/domain/month_summary.dart';
import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';

/// Fixed month, household, people and amounts behind both PDF samples and the
/// machine-checkable layout guard in `test/pdf_summary_layout_test.dart`.
///
/// The amounts are deliberately uneven (12,000.00 / 3,245.67 / 8,754.33) so a
/// swapped row or column cannot cancel out, and the names are single words so
/// the position test can find them without relying on text order.
final sampleMonth = DateTime(2026, 6, 15);

const sampleLabelsAr = PdfSummaryLabels(
  // The app's real title (lib/core/l10n/app_ar.arb -> export_pdf_title). The
  // sample must match the product, not a longer variant.
  title: 'ملخص الشهر',
  householdLabel: 'الأسرة',
  periodLabel: 'الفترة',
  incomeLabel: 'الإيرادات',
  expensesLabel: 'المصروفات',
  balanceLabel: 'الرصيد',
  byCategoryLabel: 'المصروفات حسب التصنيف',
  byPersonLabel: 'الإنفاق حسب الشخص',
  emptyLabel: 'لا توجد عمليات في هذه الفترة.',
  footer: 'تطبيق متابعة إيرادات ومصروفات الأسرة',
);

const sampleLabelsEn = PdfSummaryLabels(
  title: 'Monthly summary',
  householdLabel: 'Household',
  periodLabel: 'Period',
  incomeLabel: 'Income',
  expensesLabel: 'Expenses',
  balanceLabel: 'Balance',
  byCategoryLabel: 'Expenses by category',
  byPersonLabel: 'Spending by person',
  emptyLabel: 'No transactions in this period.',
  footer: 'Family income and expense tracker',
);

const sampleCategoryNamesAr = {
  'salary': 'الراتب',
  'food': 'الطعام',
  'pet_food': 'الحيوانات',
};
const sampleMemberNamesAr = {'m1': 'أحمد', 'm2': 'فاطمة'};

const sampleCategoryNamesEn = {
  'salary': 'Salary',
  'food': 'Food',
  'pet_food': 'Pets',
};
const sampleMemberNamesEn = {'m1': 'Ahmed', 'm2': 'Fatima'};

final List<Transaction> _rows = <Transaction>[
  Transaction(
    id: 's1',
    householdId: 'h1',
    type: TransactionType.income,
    amountMinorUnits: 1200000,
    categoryId: 'salary',
    memberId: 'm1',
    date: sampleMonth,
  ),
  Transaction(
    id: 's2',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 234567,
    categoryId: 'food',
    memberId: 'm1',
    date: sampleMonth,
  ),
  Transaction(
    id: 's3',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 90000,
    categoryId: 'pet_food',
    memberId: 'm2',
    date: sampleMonth,
  ),
];

/// The summary the sample prints: income 12,000.00, expenses 3,245.67,
/// balance 8,754.33.
MonthSummary sampleSummary({required bool arabic}) => MonthSummary.fromTransactions(
      _rows,
      categoryNames: arabic ? sampleCategoryNamesAr : sampleCategoryNamesEn,
      memberNames: arabic ? sampleMemberNamesAr : sampleMemberNamesEn,
    );

/// Builds the Arabic or English sample exactly the way `export_screen.dart`
/// calls the builder (same fonts, labels, period text and currency label).
Future<Uint8List> buildSamplePdf({required bool arabic}) async {
  final regular = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
  final bold = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();
  return buildMonthSummaryPdf(
    labels: arabic ? sampleLabelsAr : sampleLabelsEn,
    // 'الشهري' ends in a YEH right after a non-joining REH, i.e. an *isolated*
    // YEH (U+FEF1): the exact case the old font mapping broke. It keeps the
    // rendered sample an honest check of the fix rather than one that hides
    // it. See docs/phase4b/README.md.
    householdName: arabic ? 'أسرة الشهري' : 'Ahmed Family',
    periodText: arabic ? 'يونيو ٢٠٢٦' : 'June 2026',
    summary: sampleSummary(arabic: arabic),
    currencyCode: Currency.label('EGP', locale: arabic ? 'ar' : 'en'),
    rtl: arabic,
    // The app's default is Western digits; the Arabic sample turns the
    // Settings toggle on so the harder rendering is the one under review.
    arabicDigits: arabic,
    regularFont: regular,
    boldFont: bold,
  );
}
