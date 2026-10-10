import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/fixed_summary.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringRule _rule({
  required RecurrenceFrequency frequency,
  required DateTime start,
  int amount = 100000,
  int? dayOfMonth,
  DateTime? end,
  String categoryId = 'cat-expense',
  bool isActive = true,
}) =>
    RecurringRule(
      id: 'r1',
      householdId: 'h1',
      categoryId: categoryId,
      memberId: 'm1',
      amountMinorUnits: amount,
      frequency: frequency,
      nextDue: start,
      isActive: isActive,
      dayOfMonth: dayOfMonth,
      startDate: start,
      endDate: end,
    );

void main() {
  final month = DateTime(2026, 10);

  test('monthly expense is due before its day and posted after', () {
    final rule = _rule(
      frequency: RecurrenceFrequency.monthly,
      start: DateTime(2026, 10, 10),
      dayOfMonth: 10,
    );

    final before = fixedMonthSummary(
      rules: [rule],
      incomeCategoryIds: const <String>{},
      month: month,
      today: DateTime(2026, 10, 5),
    );
    expect(before.postedMinor, 0);
    expect(before.dueMinor, 100000);

    final after = fixedMonthSummary(
      rules: [rule],
      incomeCategoryIds: const <String>{},
      month: month,
      today: DateTime(2026, 10, 15),
    );
    expect(after.postedMinor, 100000);
    expect(after.dueMinor, 0);
  });

  test('weekly rule splits posted and due within the month', () {
    final rule = _rule(
      frequency: RecurrenceFrequency.weekly,
      start: DateTime(2026, 10, 1),
      amount: 1000,
    );
    final summary = fixedMonthSummary(
      rules: [rule],
      incomeCategoryIds: const <String>{},
      month: month,
      today: DateTime(2026, 10, 10),
    );
    // Days 1, 8, 15, 22, 29 -> 2 posted, 3 due.
    expect(summary.postedMinor, 2000);
    expect(summary.dueMinor, 3000);
  });

  test('income rules, paused rules and past end dates are ignored', () {
    final income = _rule(
      frequency: RecurrenceFrequency.monthly,
      start: DateTime(2026, 10, 10),
      dayOfMonth: 10,
      categoryId: 'cat-income',
    );
    final paused = _rule(
      frequency: RecurrenceFrequency.monthly,
      start: DateTime(2026, 10, 10),
      dayOfMonth: 10,
      isActive: false,
    );
    final ended = _rule(
      frequency: RecurrenceFrequency.monthly,
      start: DateTime(2026, 1, 10),
      dayOfMonth: 10,
      end: DateTime(2026, 9, 30),
    );

    final summary = fixedMonthSummary(
      rules: [income, paused, ended],
      incomeCategoryIds: const {'cat-income'},
      month: month,
      today: DateTime(2026, 10, 20),
    );
    expect(summary.postedMinor, 0);
    expect(summary.dueMinor, 0);
  });

  test('yearly rule only counts its own month', () {
    final rule = _rule(
      frequency: RecurrenceFrequency.yearly,
      start: DateTime(2026, 3, 15),
    );
    final october = fixedMonthSummary(
      rules: [rule],
      incomeCategoryIds: const <String>{},
      month: month,
      today: DateTime(2026, 10, 20),
    );
    expect(october.totalMinor, 0);

    final march = fixedMonthSummary(
      rules: [rule],
      incomeCategoryIds: const <String>{},
      month: DateTime(2026, 3),
      today: DateTime(2026, 3, 1),
    );
    expect(march.dueMinor, 100000);
  });
}
