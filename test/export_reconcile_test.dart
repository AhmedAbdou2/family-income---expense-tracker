import 'dart:convert';
import 'dart:io';

import 'package:family_income_expense_tracker/core/utils/money.dart';
import 'package:family_income_expense_tracker/features/export/domain/csv_export.dart';
import 'package:family_income_expense_tracker/features/export/domain/month_summary.dart';
import 'package:family_income_expense_tracker/features/export/presentation/pdf_summary.dart';
import 'package:family_income_expense_tracker/features/household/domain/dashboard_summary.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// One dataset, four consumers: the dashboard, the CSV file, the PDF summary
/// and the per-category/person tables must all agree on the month's figures.
/// The fixture is the same one the Budgets/Reports reconcile test uses, so the
/// expense total is exactly 23,845.67.
final _month = DateTime(DateTime.now().year, DateTime.now().month);

final _transactions = <Transaction>[
  Transaction(
    id: 't1',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 1234567,
    categoryId: 'food',
    memberId: 'm1',
    date: _month,
  ),
  Transaction(
    id: 't2',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 250000,
    categoryId: 'transport',
    memberId: 'm1',
    date: _month,
  ),
  Transaction(
    id: 't3',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 900000,
    categoryId: 'rent',
    memberId: 'm2',
    date: _month,
    recurringRuleId: 'r1',
  ),
  Transaction(
    id: 't4',
    householdId: 'h1',
    type: TransactionType.income,
    amountMinorUnits: 5000000,
    categoryId: 'salary',
    memberId: 'm1',
    date: _month,
  ),
];

final _rules = <RecurringRule>[
  RecurringRule(
    id: 'r1',
    householdId: 'h1',
    categoryId: 'rent',
    memberId: 'm2',
    amountMinorUnits: 900000,
    frequency: RecurrenceFrequency.monthly,
    nextDue: _month,
    isActive: true,
    dayOfMonth: 1,
    startDate: _month,
  ),
];

const _categoryNames = <String, String>{
  'food': 'Food & groceries',
  'transport': 'Transport',
  'rent': 'Rent',
  'salary': 'Salary',
};

const _memberNames = <String, String>{'m1': 'Alex', 'm2': 'Sam'};

PdfSummaryLabels _labels = const PdfSummaryLabels(
  title: 'Monthly summary',
  householdLabel: 'Household',
  periodLabel: 'Period',
  incomeLabel: 'Income',
  expensesLabel: 'Expenses',
  balanceLabel: 'Balance',
  byCategoryLabel: 'Expenses by category',
  byPersonLabel: 'Spending by person',
  emptyLabel: 'No transactions in this period.',
  footer: 'Family income & expense tracker',
);

void main() {
  test('the dashboard, the PDF summary and the CSV agree on every total', () {
    final dashboard = dashboardSummary(
      transactions: _transactions,
      rules: _rules,
      incomeCategoryIds: const {'salary'},
      month: _month,
    );
    final summary = MonthSummary.fromTransactions(
      _transactions,
      categoryNames: _categoryNames,
      memberNames: _memberNames,
    );

    expect(dashboard.incomeMinor, 5000000);
    expect(dashboard.expensesMinor, 2384567);
    expect(dashboard.balanceMinor, 2615433);

    expect(summary.incomeMinorUnits, dashboard.incomeMinor);
    expect(summary.expensesMinorUnits, dashboard.expensesMinor);
    expect(summary.balanceMinorUnits, dashboard.balanceMinor);
    expect(summary.isEmpty, isFalse);
  });

  test('per-category and per-person tables carry the exact amounts', () {
    final summary = MonthSummary.fromTransactions(
      _transactions,
      categoryNames: _categoryNames,
      memberNames: _memberNames,
    );

    // Biggest spend first: food 12,345.67, rent 9,000.00, transport 2,500.00.
    expect(
      summary.byCategory.map((line) => (line.name, line.amountMinorUnits)),
      [
        ('Food & groceries', 1234567),
        ('Rent', 900000),
        ('Transport', 250000),
      ],
    );
    // Income is NOT a "spending" line.
    expect(summary.byCategory.length, 3);

    // Sam 9,000.00 then Alex 14,845.67 sorted by amount -> Alex first.
    expect(
      summary.byPerson.map((line) => (line.name, line.amountMinorUnits)),
      [
        ('Alex', 1484567),
        ('Sam', 900000),
      ],
    );
  });

  test('summing the CSV amount cells reproduces the dashboard totals', () {
    final csvRows = csvRowsFor(
      transactions: _transactions,
      categoryNames: _categoryNames,
      memberNames: _memberNames,
      currency: 'EGP',
    );

    expect(
      csvRows.skip(1).map((row) => row[4]).toList(),
      ['12345.67', '2500.00', '9000.00', '50000.00'],
    );

    var expenses = 0;
    var income = 0;
    for (final row in csvRows.skip(1)) {
      final amount = Money.decimalStringToMinorUnits(row[4]);
      if (row[1] == 'expense') {
        expenses += amount;
      } else {
        income += amount;
      }
    }
    expect(expenses, 2384567);
    expect(income, 5000000);

    // The document itself quotes/prefixes nothing unexpected for clean rows.
    final document = buildCsv(csvRows);
    expect(document.split('\r\n').where((line) => line.isNotEmpty).length, 5);
    expect(document.contains('12345.67,EGP'), isTrue);
  });

  test('the PDF summary renders from the same numbers', () async {
    final summary = MonthSummary.fromTransactions(
      _transactions,
      categoryNames: _categoryNames,
      memberNames: _memberNames,
    );
    final bytes = await buildMonthSummaryPdf(
      labels: _labels,
      householdName: 'Home',
      periodText: 'June 2026',
      summary: summary,
      currencyCode: 'EGP',
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(String.fromCharCodes(bytes.sublist(bytes.length - 6)), '%%EOF\n');
  });

  test('the Arabic PDF embeds the Cairo font and still renders', () async {
    final regular = File('assets/fonts/Cairo-Regular.ttf').readAsBytesSync();
    final bold = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();
    final summary = MonthSummary.fromTransactions(
      _transactions,
      categoryNames: const {
        'food': 'الطعام والبقالة',
        'transport': 'المواصلات',
        'rent': 'الإيجار',
        'salary': 'الراتب',
      },
      memberNames: const {'m1': 'أليكس', 'm2': 'سام'},
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
      householdName: 'الأسرة',
      periodText: 'يونيو ٢٠٢٦',
      summary: summary,
      currencyCode: 'ج.م',
      rtl: true,
      regularFont: regular,
      boldFont: bold,
    );

    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    // The automated half of the AMENDMENT F proof: the font program really is
    // embedded. Whether the letters come out CONNECTED and in RTL order is
    // checked on the rendered PNG / by test/pdf_summary_test.dart.
    expect(latin1.decode(bytes).contains('FontFile2'), isTrue);
    expect(bytes.length, greaterThan(8000));
  });

  test('an empty month still produces a page', () async {
    final summary = MonthSummary.fromTransactions(
      const [],
      categoryNames: _categoryNames,
      memberNames: _memberNames,
    );
    expect(summary.isEmpty, isTrue);

    final bytes = await buildMonthSummaryPdf(
      labels: _labels,
      householdName: 'Home',
      periodText: 'June 2026',
      summary: summary,
      currencyCode: 'EGP',
    );
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}
