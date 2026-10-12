import '../../transactions/domain/entities.dart';
import 'entities.dart';

/// One bar/slice of a report: an id (category or person) and its amount.
class ReportSlice {
  const ReportSlice({required this.id, required this.amountMinorUnits});

  final String id;
  final int amountMinorUnits;
}

/// Everything the Reports screen draws for one month, in integer minor
/// units. Built from the SAME month transactions the dashboard sums, so the
/// totals reconcile exactly with the dashboard's expense figure.
class ReportData {
  const ReportData({
    required this.byCategory,
    required this.byPerson,
    required this.trend,
  });

  /// This month's expenses per category, biggest first.
  final List<ReportSlice> byCategory;

  /// This month's expenses per person, biggest first.
  final List<ReportSlice> byPerson;

  /// Income vs expenses for the last [months] months (oldest first, exactly
  /// `months` entries with zero-filled gaps).
  final List<MonthlyTotal> trend;

  /// Total expenses of the selected month - identical to the dashboard's
  /// expenses card (posted fixed expenses included).
  int get totalExpensesMinor =>
      byCategory.fold(0, (sum, slice) => sum + slice.amountMinorUnits);

  bool get hasCategoryData => byCategory.isNotEmpty;
  bool get hasPersonData => byPerson.isNotEmpty;
  bool get isEmpty => byCategory.isEmpty && byPerson.isEmpty;
}

/// Whole-percent share of [part] out of [total]; 0 when [total] is 0.
int sharePercent(int part, int total) {
  if (total <= 0) return 0;
  return part * 100 ~/ total;
}

List<ReportSlice> _groupExpenses(
  List<Transaction> transactions,
  String Function(Transaction) keyOf,
) {
  final totals = <String, int>{};
  for (final transaction in transactions) {
    if (transaction.type != TransactionType.expense) continue;
    final key = keyOf(transaction);
    totals.update(
      key,
      (value) => value + transaction.amountMinorUnits,
      ifAbsent: () => transaction.amountMinorUnits,
    );
  }
  final slices = [
    for (final entry in totals.entries)
      ReportSlice(id: entry.key, amountMinorUnits: entry.value),
  ];
  slices.sort((a, b) {
    final byAmount = b.amountMinorUnits.compareTo(a.amountMinorUnits);
    return byAmount != 0 ? byAmount : a.id.compareTo(b.id);
  });
  return slices;
}

/// This month's expenses per category, biggest first.
List<ReportSlice> expensesByCategory(List<Transaction> transactions) =>
    _groupExpenses(transactions, (transaction) => transaction.categoryId);

/// This month's expenses per person, biggest first.
List<ReportSlice> expensesByPerson(List<Transaction> transactions) =>
    _groupExpenses(transactions, (transaction) => transaction.memberId);

/// [months] month buckets ending at [endMonth] (inclusive), oldest first.
/// Months missing from [totals] are filled with zeros so the chart always
/// has a fixed number of bars and ends at the selected month.
List<MonthlyTotal> fillMonthTrend({
  required List<MonthlyTotal> totals,
  required DateTime endMonth,
  int months = 6,
}) {
  final start = DateTime(endMonth.year, endMonth.month - (months - 1));
  return [
    for (var i = 0; i < months; i++)
      _monthTotal(totals, DateTime(start.year, start.month + i)),
  ];
}

MonthlyTotal _monthTotal(List<MonthlyTotal> totals, DateTime month) {
  for (final total in totals) {
    if (total.isSameMonth(month)) return total;
  }
  return MonthlyTotal(month: month, incomeMinor: 0, expenseMinor: 0);
}

/// Assembles the Reports screen's data for the selected month.
ReportData buildReportData({
  required List<Transaction> monthTransactions,
  required List<MonthlyTotal> monthlyTotals,
  required DateTime endMonth,
  int months = 6,
}) =>
    ReportData(
      byCategory: expensesByCategory(monthTransactions),
      byPerson: expensesByPerson(monthTransactions),
      trend: fillMonthTrend(
        totals: monthlyTotals,
        endMonth: endMonth,
        months: months,
      ),
    );
