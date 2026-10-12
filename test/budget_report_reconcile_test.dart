import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/budgets/domain/budget_progress.dart';
import 'package:family_income_expense_tracker/features/budgets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/budgets/presentation/budgets_screen.dart';
import 'package:family_income_expense_tracker/features/budgets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/dashboard_summary.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/dashboard_screen.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/recurring_rules_repository.dart';
import 'package:family_income_expense_tracker/features/recurring/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/reports/domain/entities.dart';
import 'package:family_income_expense_tracker/features/reports/domain/report_data.dart';
import 'package:family_income_expense_tracker/features/reports/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/reports/presentation/reports_screen.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// One dataset, three consumers. The dashboard, the Budgets screen and the
/// Reports screen must all agree on the month's expense total: 23,845.67.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

class _FakeRecurringRepo implements RecurringRulesRepository {
  @override
  Future<int> generateDue() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

final _month = DateTime(DateTime.now().year, DateTime.now().month);

final _categories = <Category>[
  const Category(
    id: 'food',
    householdId: 'h1',
    group: CategoryGroup.general,
    nameEn: 'Food',
    nameAr: 'طعام',
  ),
  const Category(
    id: 'transport',
    householdId: 'h1',
    group: CategoryGroup.general,
    nameEn: 'Transport',
    nameAr: 'مواصلات',
  ),
  const Category(
    id: 'rent',
    householdId: 'h1',
    group: CategoryGroup.fixed,
    nameEn: 'Rent',
    nameAr: 'إيجار',
  ),
  const Category(
    id: 'salary',
    householdId: 'h1',
    group: CategoryGroup.income,
    nameEn: 'Salary',
    nameAr: 'راتب',
  ),
];

final _members = <Member>[
  const Member(
    id: 'm1',
    householdId: 'h1',
    name: 'Alex',
    isActive: true,
    userId: 'u1',
  ),
];

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
    memberId: 'm1',
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

/// A rule that already posted, so it never adds to "still due" and the
/// projection equals the spent figure.
final _rules = <RecurringRule>[
  RecurringRule(
    id: 'r1',
    householdId: 'h1',
    categoryId: 'rent',
    memberId: 'm1',
    amountMinorUnits: 900000,
    frequency: RecurrenceFrequency.monthly,
    nextDue: _month,
    isActive: true,
    dayOfMonth: 1,
    startDate: _month,
  ),
];

/// food is OVER its limit (12,345.67 > 10,000.00); the overall limit is NEAR
/// (23,845.67 / 25,000.00 = 95%).
final _budgets = <Budget>[
  const Budget(
    id: 'b0',
    householdId: 'h1',
    amountMinorUnits: 2500000,
    isActive: true,
  ),
  const Budget(
    id: 'b1',
    householdId: 'h1',
    categoryId: 'food',
    amountMinorUnits: 1000000,
    isActive: true,
  ),
];

const _totalExpensesMinor = 2384567;

ProviderScope _scope({
  required MemberRole role,
  Widget? child,
  GoRouter? router,
  Locale locale = const Locale('en'),
}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        recurringRulesRepositoryProvider
            .overrideWithValue(_FakeRecurringRepo()),
        categoriesProvider.overrideWith((ref) async => _categories),
        membersProvider.overrideWith((ref) async => _members),
        budgetsProvider.overrideWith((ref) async => _budgets),
        recurringRulesProvider.overrideWith((ref) async => _rules),
        dashboardMonthTransactionsProvider.overrideWith(
          (ref) async => _transactions,
        ),
        monthlyTotalsProvider.overrideWith(
          (ref) async => <MonthlyTotal>[
            MonthlyTotal(
              month: _month,
              incomeMinor: 5000000,
              expenseMinor: _totalExpensesMinor,
            ),
          ],
        ),
      ],
      child: router != null
          ? MaterialApp.router(
              routerConfig: router,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
            )
          : MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              home: child,
            ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  test('dashboard, budget overall and report totals all agree exactly', () {
    final summary = dashboardSummary(
      transactions: _transactions,
      rules: _rules,
      incomeCategoryIds: const {'salary'},
      month: _month,
    );
    final overview = budgetOverview(
      budgets: _budgets,
      monthTransactions: _transactions,
      categories: _categories,
      rules: _rules,
      month: _month,
    );
    final report = buildReportData(
      monthTransactions: _transactions,
      monthlyTotals: const [],
      endMonth: _month,
    );

    expect(summary.expensesMinor, _totalExpensesMinor);
    expect(overview.overall!.spentMinor, _totalExpensesMinor);
    expect(report.totalExpensesMinor, _totalExpensesMinor);
    // No floating point anywhere: the string is derived from the integer.
    expect(summary.balanceMinor, 5000000 - _totalExpensesMinor);
  });

  testWidgets('Budgets screen shows the exact overall and category figures',
      (tester) async {
    await tester.pumpWidget(
      _scope(role: MemberRole.owner, child: const BudgetsScreen()),
    );
    await _settle(tester);

    // Overall: spent of limit, both exact.
    expect(
      find.textContaining('23,845.67 EGP of 25,000.00 EGP'),
      findsOneWidget,
    );
    // food: over its limit.
    expect(
      find.textContaining('12,345.67 EGP of 10,000.00 EGP'),
      findsOneWidget,
    );
    expect(find.text('Over budget'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reports donut total equals the dashboard expense figure',
      (tester) async {
    await tester.pumpWidget(
      _scope(role: MemberRole.owner, child: const ReportsScreen()),
    );
    await _settle(tester);

    // The card subtitle states the month's total expenses, and the donut
    // centre shows the same figure - both derived from the same integer.
    expect(
      find.text('Total expenses: 23,845.67 EGP'),
      findsOneWidget,
    );
    expect(find.text('23,845.67 EGP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows a budget alert card with the category count '
      'and the overall limit', (tester) async {
    await tester.pumpWidget(
      _scope(role: MemberRole.owner, child: const DashboardScreen()),
    );
    await _settle(tester);

    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('1 category near or over its limit'), findsOneWidget);
    expect(find.textContaining('Overall limit: 25,000.00 EGP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard hides the budget card from a child', (tester) async {
    await tester.pumpWidget(
      _scope(role: MemberRole.child, child: const DashboardScreen()),
    );
    await _settle(tester);

    expect(find.text('Budgets'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the alert card opens the Budgets screen',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const BudgetsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_scope(role: MemberRole.owner, router: router));
    await _settle(tester);

    await tester.tap(find.text('Budgets'));
    await _settle(tester);

    expect(find.byType(BudgetsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
