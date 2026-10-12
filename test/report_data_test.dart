import 'package:family_income_expense_tracker/features/reports/domain/entities.dart';
import 'package:family_income_expense_tracker/features/reports/domain/report_data.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exact, hand-computed figures in integer minor units.
void main() {
  Transaction row(
    String id,
    TransactionType type,
    int minor, {
    String categoryId = 'food',
    String memberId = 'm1',
  }) =>
      Transaction(
        id: id,
        householdId: 'h1',
        type: type,
        amountMinorUnits: minor,
        categoryId: categoryId,
        memberId: memberId,
        date: DateTime(2026, 6, 5),
      );

  test('expenses by category: income ignored, biggest first, ties by id', () {
    final slices = expensesByCategory([
      row('t1', TransactionType.expense, 30000, categoryId: 'food'),
      row('t2', TransactionType.expense, 10000, categoryId: 'transport'),
      row('t3', TransactionType.expense, 20000, categoryId: 'food'),
      row('t4', TransactionType.income, 500000, categoryId: 'salary'),
      row('t5', TransactionType.expense, 40000, categoryId: 'rent'),
      row('t6', TransactionType.expense, 40000, categoryId: 'car'),
    ]);

    expect(slices.map((slice) => slice.id).toList(), [
      'food', // 500.00 - biggest
      'car', // 400.00 - tie with rent broken alphabetically by id
      'rent', // 400.00
      'transport', // 100.00
    ]);
    expect(slices.first.amountMinorUnits, 50000);
  });

  test('expenses by person and total reconcile with the sum', () {
    final transactions = [
      row('t1', TransactionType.expense, 30000, memberId: 'm1'),
      row('t2', TransactionType.expense, 20000, memberId: 'm2'),
      row('t3', TransactionType.expense, 10000, memberId: 'm1'),
      row('t4', TransactionType.income, 900000, memberId: 'm1'),
    ];
    final data = buildReportData(
      monthTransactions: transactions,
      monthlyTotals: const [],
      endMonth: DateTime(2026, 6),
    );

    expect(data.byPerson.map((slice) => slice.id).toList(), ['m1', 'm2']);
    expect(data.byPerson.first.amountMinorUnits, 40000);
    expect(data.totalExpensesMinor, 60000);
    expect(
      data.byCategory.fold(0, (sum, slice) => sum + slice.amountMinorUnits),
      data.totalExpensesMinor,
    );
  });

  test('a month with no expenses is empty', () {
    final data = buildReportData(
      monthTransactions: [row('t1', TransactionType.income, 100000)],
      monthlyTotals: const [],
      endMonth: DateTime(2026, 6),
    );

    expect(data.isEmpty, isTrue);
    expect(data.hasCategoryData, isFalse);
    expect(data.hasPersonData, isFalse);
    expect(data.totalExpensesMinor, 0);
  });

  test('trend is exactly 6 months, oldest first, ends at the selected month, '
      'with zero-filled gaps', () {
    final trend = fillMonthTrend(
      totals: [
        MonthlyTotal(
          month: DateTime(2026, 3),
          incomeMinor: 100000,
          expenseMinor: 40000,
        ),
        MonthlyTotal(
          month: DateTime(2026, 6),
          incomeMinor: 200000,
          expenseMinor: 90000,
        ),
      ],
      endMonth: DateTime(2026, 6),
    );

    expect(trend, hasLength(6));
    expect(trend.first.month, DateTime(2026, 1));
    expect(trend.last.month, DateTime(2026, 6));
    // January and February have no rows -> zeros.
    expect(trend[0].incomeMinor, 0);
    expect(trend[1].incomeMinor, 0);
    expect(trend[2].incomeMinor, 100000);
    expect(trend[2].expenseMinor, 40000);
    expect(trend[3].incomeMinor, 0);
    expect(trend[5].incomeMinor, 200000);
    expect(trend[5].expenseMinor, 90000);
  });

  test('a trend window that crosses a year boundary is still 6 months', () {
    final trend = fillMonthTrend(
      totals: const [],
      endMonth: DateTime(2026, 2),
    );

    expect(trend.map((total) => total.month).toList(), [
      DateTime(2025, 9),
      DateTime(2025, 10),
      DateTime(2025, 11),
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 2),
    ]);
  });

  test('rows outside the trend window are ignored', () {
    final trend = fillMonthTrend(
      totals: [
        MonthlyTotal(
          month: DateTime(2020, 1),
          incomeMinor: 500,
          expenseMinor: 500,
        ),
        MonthlyTotal(
          month: DateTime(2026, 6),
          incomeMinor: 700,
          expenseMinor: 300,
        ),
      ],
      endMonth: DateTime(2026, 6),
    );

    expect(trend.fold(0, (sum, total) => sum + total.incomeMinor), 700);
  });

  test('sharePercent is a whole percent and never divides by zero', () {
    expect(sharePercent(25, 100), 25);
    expect(sharePercent(1, 3), 33);
    expect(sharePercent(5, 0), 0);
    expect(sharePercent(0, 100), 0);
  });
}
