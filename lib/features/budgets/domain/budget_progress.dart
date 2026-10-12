import '../../categories/domain/entities.dart';
import '../../recurring/domain/entities.dart';
import '../../recurring/domain/recurring_schedule.dart';
import '../../transactions/domain/entities.dart';
import 'entities.dart';

/// How a limit is doing, derived from SPENT (projections never trigger an
/// alert - they are shown separately).
enum BudgetStatus { ok, near, over }

/// One limit with its month figures, all in integer minor units.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spentMinor,
    required this.projectedMinor,
  });

  final Budget budget;

  /// Every expense transaction of the month for this limit's scope
  /// (posted fixed expenses included).
  final int spentMinor;

  /// [spentMinor] + the fixed expenses of the same scope still due later
  /// this month (a projection, never a trigger).
  final int projectedMinor;

  int get limitMinor => budget.amountMinorUnits;
  int get remainingMinor => limitMinor - spentMinor;
  int get projectedRemainingMinor => limitMinor - projectedMinor;
  bool get isActive => budget.isActive;

  /// Whole-percent of the limit already spent (may exceed 100).
  int get percent {
    if (limitMinor <= 0) return 0;
    return spentMinor * 100 ~/ limitMinor;
  }

  bool get isOver => spentMinor >= limitMinor;
  bool get isNear => !isOver && spentMinor * 100 >= limitMinor * 80;

  BudgetStatus get status =>
      isOver ? BudgetStatus.over : (isNear ? BudgetStatus.near : BudgetStatus.ok);

  /// "Projected to exceed the limit" - spent plus still-due fixed costs
  /// goes past the limit, even though nothing is over yet.
  bool get projectedExceeds => projectedMinor > limitMinor;
}

/// The whole Budgets screen / dashboard alert for one month.
class BudgetOverview {
  const BudgetOverview({
    required this.categories,
    required this.nearCount,
    required this.overCount,
    this.overall,
  });

  const BudgetOverview.empty()
      : categories = const <BudgetProgress>[],
        nearCount = 0,
        overCount = 0,
        overall = null;

  /// Category limits, in the caller's category order.
  final List<BudgetProgress> categories;
  final int nearCount;
  final int overCount;

  /// The household's single overall limit, if one is set.
  final BudgetProgress? overall;

  bool get hasBudgets => overall != null || categories.isNotEmpty;

  /// Categories near or over their limit - the number on the dashboard
  /// card. Paused limits are never counted.
  int get alertCount => nearCount + overCount;

  /// Sum of the spent figure of every category limit. Not the month total
  /// (that is [overall]'s spent) - only categories that carry a limit.
  int get budgetedSpentMinor =>
      categories.fold(0, (sum, row) => sum + row.spentMinor);
}

/// Builds the month's budget view from the same rows the dashboard uses,
/// so every figure reconciles exactly:
///
/// * a category's spent = the month's expense transactions of that category
///   (posted fixed expenses included);
/// * a category's projected = spent + the fixed rules of that category
///   still due later in the month;
/// * the overall limit's spent = ALL the month's expenses (categories
///   without a limit and posted fixed expenses included);
/// * the overall projected adds every still-due expense rule.
///
/// [rules] may be empty (a child, or a household with no fixed expenses).
/// Alert counts only look at ACTIVE limits and only at spent.
BudgetOverview budgetOverview({
  required List<Budget> budgets,
  required List<Transaction> monthTransactions,
  required List<Category> categories,
  required List<RecurringRule> rules,
  required DateTime month,
  DateTime? today,
}) {
  final incomeCategoryIds = <String>{
    for (final category in categories)
      if (category.group == CategoryGroup.income) category.id,
  };

  final spentByCategory = <String, int>{};
  var totalExpensesMinor = 0;
  for (final transaction in monthTransactions) {
    if (transaction.type != TransactionType.expense) continue;
    totalExpensesMinor += transaction.amountMinorUnits;
    spentByCategory.update(
      transaction.categoryId,
      (value) => value + transaction.amountMinorUnits,
      ifAbsent: () => transaction.amountMinorUnits,
    );
  }

  final reference = today == null
      ? DateTime.now()
      : DateTime(today.year, today.month, today.day);
  final dueByCategory = <String, int>{};
  var totalDueMinor = 0;
  for (final rule in rules) {
    if (!rule.isActive || rule.isArchived) continue;
    if (incomeCategoryIds.contains(rule.categoryId)) continue;
    for (final occurs in occurrencesInMonth(rule, month)) {
      if (!occurs.isAfter(reference)) continue;
      dueByCategory.update(
        rule.categoryId,
        (value) => value + rule.amountMinorUnits,
        ifAbsent: () => rule.amountMinorUnits,
      );
      totalDueMinor += rule.amountMinorUnits;
    }
  }

  final categoryOrder = <String, int>{
    for (var i = 0; i < categories.length; i++) categories[i].id: i,
  };

  Budget? overallBudget;
  final rows = <BudgetProgress>[];
  for (final budget in budgets) {
    if (budget.isOverall) {
      overallBudget = budget;
      continue;
    }
    final categoryId = budget.categoryId!;
    final spent = spentByCategory[categoryId] ?? 0;
    rows.add(BudgetProgress(
      budget: budget,
      spentMinor: spent,
      projectedMinor: spent + (dueByCategory[categoryId] ?? 0),
    ));
  }

  rows.sort((a, b) {
    final left = categoryOrder[a.budget.categoryId] ?? 1 << 30;
    final right = categoryOrder[b.budget.categoryId] ?? 1 << 30;
    return left.compareTo(right);
  });

  var nearCount = 0;
  var overCount = 0;
  for (final row in rows) {
    if (!row.isActive) continue;
    if (row.status == BudgetStatus.over) {
      overCount++;
    } else if (row.status == BudgetStatus.near) {
      nearCount++;
    }
  }

  final overall = overallBudget == null
      ? null
      : BudgetProgress(
          budget: overallBudget,
          spentMinor: totalExpensesMinor,
          projectedMinor: totalExpensesMinor + totalDueMinor,
        );

  return BudgetOverview(
    categories: rows,
    nearCount: nearCount,
    overCount: overCount,
    overall: overall,
  );
}
