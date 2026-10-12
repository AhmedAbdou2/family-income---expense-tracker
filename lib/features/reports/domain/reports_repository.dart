import 'entities.dart';

/// Read-only reporting queries.
///
/// The 6-month trend is aggregated by the `monthly_totals` SECURITY DEFINER
/// RPC (migration 16) rather than by fetching transactions: a household with
/// more than 1000 rows in the window would otherwise be silently truncated by
/// PostgREST's response cap, and the numbers would be wrong. The RPC returns
/// one row per month, so it can never be truncated, and it sums in SQL with
/// the exact same definition of income/expense as the dashboard.
abstract interface class ReportsRepository {
  /// Totals per month in `[startMonth, endMonthExclusive)`. Months with no
  /// transactions are absent from the result.
  Future<List<MonthlyTotal>> monthlyTotals({
    required String householdId,
    required DateTime startMonth,
    required DateTime endMonthExclusive,
  });
}
