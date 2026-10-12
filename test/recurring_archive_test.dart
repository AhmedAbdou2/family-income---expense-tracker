import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/features/household/domain/dashboard_summary.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/fixed_summary.dart';
import 'package:family_income_expense_tracker/features/recurring/presentation/recurring_delete.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scenario from the bug report, in minor units:
///   income 10,000.00 | other expenses 1,650.00 |
///   one weekly fixed expense of 500.00 posting 4 times this month (2,000.00)
///   with its 5th occurrence (500.00) still due.
///
/// October 2026 is a 31-day month; weekly from the 1st hits
/// 1, 8, 15, 22, 29. "Today" is the 23rd, so 1/8/15/22 are posted and 29 is
/// still due.
void main() {
  final month = DateTime(2026, 10);
  final today = DateTime(2026, 10, 23);

  final ruleId = 'rule-fixed';
  final rule = RecurringRule(
    id: ruleId,
    householdId: 'h1',
    categoryId: 'cat-exp',
    memberId: 'm1',
    amountMinorUnits: 50000, // 500.00
    frequency: RecurrenceFrequency.weekly,
    nextDue: DateTime(2026, 10, 29),
    isActive: true,
    startDate: DateTime(2026, 10, 1),
  );

  Transaction postedFixed(int day) => Transaction(
        id: 'fixed-$day',
        householdId: 'h1',
        type: TransactionType.expense,
        amountMinorUnits: 50000,
        categoryId: 'cat-exp',
        memberId: 'm1',
        date: DateTime(2026, 10, day),
        recurringRuleId: ruleId,
      );

  final income = Transaction(
    id: 'income',
    householdId: 'h1',
    type: TransactionType.income,
    amountMinorUnits: 1000000, // 10,000.00
    categoryId: 'cat-inc',
    memberId: 'm1',
    date: DateTime(2026, 10, 5),
  );
  final otherExpense = Transaction(
    id: 'other',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 165000, // 1,650.00
    categoryId: 'cat-exp',
    memberId: 'm1',
    date: DateTime(2026, 10, 6),
  );

  // The four occurrences the rule already posted.
  final postedRows = [postedFixed(1), postedFixed(8), postedFixed(15), postedFixed(22)];
  // Everything the household has this month.
  final allRows = [income, otherExpense, ...postedRows];

  group('before deleting the fixed expense', () {
    test('income 10,000 / expenses 3,650 / posted 2,000 / due 500 / left 7,500',
        () {
      final s = dashboardSummary(
        transactions: allRows,
        rules: [rule],
        incomeCategoryIds: const <String>{},
        month: month,
        today: today,
      );
      expect(s.incomeMinor, 1000000);
      expect(s.expensesMinor, 365000); // 1,650 + 2,000
      expect(s.balanceMinor, 635000);
      expect(s.postedFixedMinor, 200000); // 2,000
      expect(s.stillDueMinor, 50000); // 500
      expect(s.leftAfterFixedMinor, 750000); // 10,000 - 2,000 - 500
    });
  });

  group('after Keep-delete (rule archived, posted rows kept)', () {
    // Keep: the rule leaves the live list but its posted rows keep their
    // recurringRuleId link, so the dashboard sees the same rows.
    final liveRules = <RecurringRule>[]; // archived -> not in the list

    test('Posted stays 2,000, Still due drops to 0, Expenses unchanged', () {
      final s = dashboardSummary(
        transactions: allRows,
        rules: liveRules,
        incomeCategoryIds: const <String>{},
        month: month,
        today: today,
      );
      expect(s.incomeMinor, 1000000);
      expect(s.expensesMinor, 365000); // unchanged
      expect(s.balanceMinor, 635000);
      expect(s.postedFixedMinor, 200000); // 2,000 - the whole bug fix
      expect(s.stillDueMinor, 0); // future occurrence gone
      expect(s.leftAfterFixedMinor, 800000); // 10,000 - 2,000 - 0
    });

    test('the archived rule is ignored even if it is passed in the list', () {
      final archived = RecurringRule(
        id: rule.id,
        householdId: rule.householdId,
        categoryId: rule.categoryId,
        memberId: rule.memberId,
        amountMinorUnits: rule.amountMinorUnits,
        frequency: rule.frequency,
        nextDue: rule.nextDue,
        isActive: false,
        startDate: rule.startDate,
        archivedAt: DateTime(2026, 10, 23),
      );
      expect(archived.isArchived, isTrue);

      final summary = fixedMonthSummary(
        rules: [archived],
        incomeCategoryIds: const <String>{},
        month: month,
        today: today,
      );
      expect(summary.dueMinor, 0);
      expect(summary.postedMinor, 0);
    });
  });

  group('after delete-with-transactions (rule archived, month rows purged)',
      () {
    // Only the non-fixed rows survive.
    final purgedRows = [income, otherExpense];
    final liveRules = <RecurringRule>[];

    test('Posted 0 and Expenses lower by exactly 2,000', () {
      final s = dashboardSummary(
        transactions: purgedRows,
        rules: liveRules,
        incomeCategoryIds: const <String>{},
        month: month,
        today: today,
      );
      expect(s.postedFixedMinor, 0);
      expect(s.expensesMinor, 165000); // 3,650 - 2,000
      expect(s.balanceMinor, 835000); // 10,000 - 1,650
      expect(s.stillDueMinor, 0);
      expect(s.leftAfterFixedMinor, 1000000); // 10,000
    });
  });

  group('postedThisMonthCount', () {
    test('counts only this rule\'s rows of the current month', () {
      expect(postedThisMonthCount(allRows, ruleId, month), 4);
      expect(postedThisMonthCount(allRows, 'someone-else', month), 0);
      expect(
        postedThisMonthCount(allRows, ruleId, DateTime(2026, 9)),
        0,
      );
    });
  });

  testWidgets('delete dialog spells out both options and the count',
      (tester) async {
    RecurringDeleteChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  choice = await showRecurringDeleteDialog(
                    context,
                    postedThisMonthCount: 2,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Posted transactions stay and keep counting as fixed expenses'),
      findsOneWidget,
    );
    expect(
      find.text("This month's 2 posted transactions are deleted too"),
      findsOneWidget,
    );

    await tester.tap(
      find.text("This month's 2 posted transactions are deleted too"),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(choice, RecurringDeleteChoice.deleteMonth);
  });

  testWidgets('delete dialog defaults to Keep', (tester) async {
    RecurringDeleteChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  choice = await showRecurringDeleteDialog(
                    context,
                    postedThisMonthCount: 0,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(choice, RecurringDeleteChoice.keep);
  });
}
