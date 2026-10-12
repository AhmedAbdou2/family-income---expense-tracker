/// One month's income/expense totals, aggregated in the database. Amounts
/// are integer MINOR units. Pure Dart - no Flutter or Supabase imports.
class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  /// First day of the month (time part is midnight).
  final DateTime month;
  final int incomeMinor;
  final int expenseMinor;

  bool isSameMonth(DateTime other) =>
      month.year == other.year && month.month == other.month;
}
