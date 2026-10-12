import '../../recurring/domain/entities.dart';
import '../../recurring/domain/fixed_summary.dart';
import '../../transactions/domain/entities.dart';

/// The dashboard's month figures, all in integer minor units.
///
/// * [expensesMinor] is every expense transaction of the month, including
///   fixed ones that were posted.
/// * [postedFixedMinor] sums only the expense transactions that carry a
///   `recurringRuleId` - i.e. money a fixed commitment already spent.
/// * [stillDueMinor] is the projection of fixed rule occurrences left to
///   post later this month (from [fixedMonthSummary]).
/// * [leftAfterFixedMinor] = income - postedFixed - stillDue.
///
/// [fixedProjectedMinor] is the rule-level projection (posted + due) used
/// only to decide whether the month has any fixed activity at all.
class DashboardSummary {
  const DashboardSummary({
    required this.incomeMinor,
    required this.expensesMinor,
    required this.balanceMinor,
    required this.postedFixedMinor,
    required this.stillDueMinor,
    required this.leftAfterFixedMinor,
    required this.fixedProjectedMinor,
  });

  final int incomeMinor;
  final int expensesMinor;
  final int balanceMinor;
  final int postedFixedMinor;
  final int stillDueMinor;
  final int leftAfterFixedMinor;
  final int fixedProjectedMinor;
}

/// Pure dashboard arithmetic over one month. [transactions] must already be
/// the month's rows (the dashboard provider scopes them); [rules] the live
/// fixed commitments. Archived/paused/income rules are ignored by
/// [fixedMonthSummary].
DashboardSummary dashboardSummary({
  required List<Transaction> transactions,
  required List<RecurringRule> rules,
  required Set<String> incomeCategoryIds,
  required DateTime month,
  DateTime? today,
}) {
  var income = 0;
  var expenses = 0;
  var postedFixed = 0;
  for (final transaction in transactions) {
    if (transaction.type == TransactionType.income) {
      income += transaction.amountMinorUnits;
    } else {
      expenses += transaction.amountMinorUnits;
      // A posted fixed expense keeps counting as fixed only while its link
      // survives - which is exactly why rules are archived, not deleted.
      if (transaction.recurringRuleId != null) {
        postedFixed += transaction.amountMinorUnits;
      }
    }
  }
  final fixed = fixedMonthSummary(
    rules: rules,
    incomeCategoryIds: incomeCategoryIds,
    month: month,
    today: today,
  );
  return DashboardSummary(
    incomeMinor: income,
    expensesMinor: expenses,
    balanceMinor: income - expenses,
    postedFixedMinor: postedFixed,
    stillDueMinor: fixed.dueMinor,
    leftAfterFixedMinor: income - postedFixed - fixed.dueMinor,
    fixedProjectedMinor: fixed.totalMinor,
  );
}
