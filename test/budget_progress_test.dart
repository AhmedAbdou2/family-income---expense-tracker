import 'package:family_income_expense_tracker/features/budgets/domain/budget_progress.dart';
import 'package:family_income_expense_tracker/features/budgets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exact, hand-computed figures. All amounts are integer minor units.
void main() {
  final month = DateTime(2026, 6);
  final today = DateTime(2026, 6, 10);

  Category category(String id, {CategoryGroup group = CategoryGroup.general}) =>
      Category(
        id: id,
        householdId: 'h1',
        group: group,
        nameEn: id,
        nameAr: id,
      );

  Transaction expense(String id, String categoryId, int minor, {int day = 5}) =>
      Transaction(
        id: id,
        householdId: 'h1',
        type: TransactionType.expense,
        amountMinorUnits: minor,
        categoryId: categoryId,
        memberId: 'm1',
        date: DateTime(2026, 6, day),
      );

  Transaction income(String id, String categoryId, int minor) => Transaction(
        id: id,
        householdId: 'h1',
        type: TransactionType.income,
        amountMinorUnits: minor,
        categoryId: categoryId,
        memberId: 'm1',
        date: DateTime(2026, 6, 1),
      );

  Budget budget(
    String id, {
    String? categoryId,
    required int minor,
    bool isActive = true,
  }) =>
      Budget(
        id: id,
        householdId: 'h1',
        categoryId: categoryId,
        amountMinorUnits: minor,
        isActive: isActive,
      );

  final categories = <Category>[
    category('food'),
    category('transport'),
    category('education'),
    category('rent', group: CategoryGroup.fixed),
    category('salary', group: CategoryGroup.income),
  ];

  // A fixed rent rule still due on the 25th (500.00).
  RecurringRule rentRule({int minor = 50000}) => RecurringRule(
        id: 'r1',
        householdId: 'h1',
        categoryId: 'rent',
        memberId: 'm1',
        amountMinorUnits: minor,
        frequency: RecurrenceFrequency.monthly,
        nextDue: DateTime(2026, 6, 25),
        isActive: true,
        dayOfMonth: 25,
        startDate: DateTime(2026, 6),
      );

  test('category spent counts every expense incl. a posted fixed one, and '
      'projected adds the still-due fixed of that category', () {
    final overview = budgetOverview(
      budgets: [budget('b1', categoryId: 'food', minor: 40000)],
      monthTransactions: [
        expense('t1', 'food', 30000),
        // Posted fixed rent for the same category as a category budget would
        // count, but food has no fixed rule here.
        expense('t2', 'rent', 50000, day: 1),
        income('t3', 'salary', 200000),
      ],
      categories: categories,
      rules: [rentRule()],
      month: month,
      today: today,
    );

    expect(overview.categories, hasLength(1));
    final food = overview.categories.single;
    expect(food.spentMinor, 30000);
    // food has no fixed rule -> projected == spent.
    expect(food.projectedMinor, 30000);
    expect(food.limitMinor, 40000);
    expect(food.remainingMinor, 10000);
    expect(food.percent, 75);
    expect(food.status, BudgetStatus.ok);
    expect(food.projectedExceeds, isFalse);
  });

  test('overall spent is ALL month expenses (budget-less categories and '
      'posted fixed included); projected adds every still-due expense rule',
      () {
    final overview = budgetOverview(
      budgets: [budget('b0', minor: 100000)],
      monthTransactions: [
        expense('t1', 'food', 30000),
        expense('t2', 'transport', 10000),
        expense('t3', 'rent', 50000, day: 1),
        income('t4', 'salary', 200000),
      ],
      categories: categories,
      rules: [rentRule()],
      month: month,
      today: today,
    );

    final overall = overview.overall!;
    expect(overall.budget.isOverall, isTrue);
    // 300.00 + 100.00 + 500.00 posted = 900.00
    expect(overall.spentMinor, 90000);
    // + 500.00 rent still due = 1400.00
    expect(overall.projectedMinor, 140000);
    expect(overall.percent, 90);
    expect(overall.status, BudgetStatus.near);
    expect(overall.projectedExceeds, isTrue);
    // Only category limits feed the alert count, not the overall row.
    expect(overview.alertCount, 0);
    expect(overview.hasBudgets, isTrue);
  });

  test('80% is near and 100% is over; a paused limit never counts', () {
    final overview = budgetOverview(
      budgets: [
        budget('b1', categoryId: 'food', minor: 40000),
        budget('b2', categoryId: 'transport', minor: 10000),
        budget('b3', categoryId: 'education', minor: 1000, isActive: false),
      ],
      monthTransactions: [
        expense('t1', 'food', 32000), // exactly 80% -> near
        expense('t2', 'transport', 10000), // exactly 100% -> over
        expense('t3', 'education', 9000), // paused -> ignored
      ],
      categories: categories,
      rules: const [],
      month: month,
      today: today,
    );

    final food = overview.categories
        .firstWhere((row) => row.budget.categoryId == 'food');
    final transport = overview.categories
        .firstWhere((row) => row.budget.categoryId == 'transport');
    final education = overview.categories
        .firstWhere((row) => row.budget.categoryId == 'education');

    expect(food.status, BudgetStatus.near);
    expect(transport.status, BudgetStatus.over);
    // Paused: progress still computed, but status/percent never alert.
    expect(education.isActive, isFalse);
    expect(education.spentMinor, 9000);
    expect(overview.nearCount, 1);
    expect(overview.overCount, 1);
    expect(overview.alertCount, 2);
  });

  test('a category limit with no transactions is spent 0 and ok', () {
    final overview = budgetOverview(
      budgets: [budget('b1', categoryId: 'food', minor: 40000)],
      monthTransactions: const [],
      categories: categories,
      rules: const [],
      month: month,
      today: today,
    );

    final food = overview.categories.single;
    expect(food.spentMinor, 0);
    expect(food.projectedMinor, 0);
    expect(food.percent, 0);
    expect(food.status, BudgetStatus.ok);
    expect(food.projectedExceeds, isFalse);
    expect(overview.alertCount, 0);
  });

  test('no limits at all -> hasBudgets false, no alerts', () {
    final overview = budgetOverview(
      budgets: const [],
      monthTransactions: [expense('t1', 'food', 30000)],
      categories: categories,
      rules: [rentRule()],
      month: month,
      today: today,
    );

    expect(overview.hasBudgets, isFalse);
    expect(overview.categories, isEmpty);
    expect(overview.overall, isNull);
    expect(overview.alertCount, 0);
  });

  test('projected exceeds is flagged even while spent is still ok', () {
    final overview = budgetOverview(
      budgets: [budget('b1', categoryId: 'rent', minor: 40000)],
      monthTransactions: [expense('t1', 'rent', 10000, day: 1)],
      categories: categories,
      rules: [rentRule(minor: 35000)],
      month: month,
      today: today,
    );

    final rent = overview.categories.single;
    expect(rent.spentMinor, 10000);
    expect(rent.projectedMinor, 45000);
    expect(rent.status, BudgetStatus.ok);
    expect(rent.projectedExceeds, isTrue);
  });

  test('an income rule never adds to projected spending', () {
    final overview = budgetOverview(
      budgets: [budget('b0', minor: 100000)],
      monthTransactions: [expense('t1', 'food', 20000)],
      categories: categories,
      rules: [
        RecurringRule(
          id: 'r2',
          householdId: 'h1',
          categoryId: 'salary',
          memberId: 'm1',
          amountMinorUnits: 900000,
          frequency: RecurrenceFrequency.monthly,
          nextDue: DateTime(2026, 6, 28),
          isActive: true,
          dayOfMonth: 28,
          startDate: DateTime(2026, 6),
        ),
      ],
      month: month,
      today: today,
    );

    expect(overview.overall!.spentMinor, 20000);
    expect(overview.overall!.projectedMinor, 20000);
  });

  test('a paused or archived expense rule does not add to projected', () {
    final rules = [
      RecurringRule(
        id: 'r3',
        householdId: 'h1',
        categoryId: 'rent',
        memberId: 'm1',
        amountMinorUnits: 50000,
        frequency: RecurrenceFrequency.monthly,
        nextDue: DateTime(2026, 6, 25),
        isActive: false,
        dayOfMonth: 25,
        startDate: DateTime(2026, 6),
      ),
      RecurringRule(
        id: 'r4',
        householdId: 'h1',
        categoryId: 'rent',
        memberId: 'm1',
        amountMinorUnits: 70000,
        frequency: RecurrenceFrequency.monthly,
        nextDue: DateTime(2026, 6, 26),
        isActive: true,
        dayOfMonth: 26,
        startDate: DateTime(2026, 6),
        archivedAt: DateTime(2026, 6, 2),
      ),
    ];
    final overview = budgetOverview(
      budgets: [budget('b0', minor: 100000)],
      monthTransactions: const [],
      categories: categories,
      rules: rules,
      month: month,
      today: today,
    );

    expect(overview.overall!.projectedMinor, 0);
  });
}
