import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/budgets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/budgets/presentation/budgets_screen.dart';
import 'package:family_income_expense_tracker/features/budgets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/reports/domain/entities.dart';
import 'package:family_income_expense_tracker/features/reports/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/reports/presentation/reports_screen.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Budgets and Reports screens are dense: a donut + legend, grouped bars,
/// proportional bars, status chips and long Arabic labels. Pumped at a 360px
/// phone, a 800px window and a very wide 1854px window for all three roles
/// (and both locales) they must never throw a layout exception.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

const _household = Household(id: 'h1', name: 'Home', currency: 'EGP');

final _categories = <Category>[
  const Category(
    id: 'food',
    householdId: 'h1',
    group: CategoryGroup.general,
    nameEn: 'Food & groceries',
    nameAr: 'الطعام والبقالة',
    icon: 'restaurant',
    color: '#EF5350',
  ),
  const Category(
    id: 'transport',
    householdId: 'h1',
    group: CategoryGroup.general,
    nameEn: 'Transport',
    nameAr: 'المواصلات',
    icon: 'local_gas_station',
    color: '#42A5F5',
  ),
  const Category(
    id: 'rent',
    householdId: 'h1',
    group: CategoryGroup.fixed,
    nameEn: 'Rent',
    nameAr: 'الإيجار',
    icon: 'home',
    color: '#AB47BC',
  ),
  const Category(
    id: 'salary',
    householdId: 'h1',
    group: CategoryGroup.income,
    nameEn: 'Salary',
    nameAr: 'الراتب',
    icon: 'payments',
    color: '#66BB6A',
  ),
];

final _members = <Member>[
  const Member(
    id: 'm1',
    householdId: 'h1',
    name: 'Alexandra',
    isActive: true,
    userId: 'u1',
  ),
  const Member(
    id: 'm2',
    householdId: 'h1',
    name: 'Sam',
    isActive: true,
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
    date: DateTime(2026, 6, 5),
  ),
  Transaction(
    id: 't2',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 250000,
    categoryId: 'transport',
    memberId: 'm2',
    date: DateTime(2026, 6, 6),
  ),
  Transaction(
    id: 't3',
    householdId: 'h1',
    type: TransactionType.expense,
    amountMinorUnits: 900000,
    categoryId: 'rent',
    memberId: 'm1',
    date: DateTime(2026, 6, 1),
    recurringRuleId: 'r1',
  ),
  Transaction(
    id: 't4',
    householdId: 'h1',
    type: TransactionType.income,
    amountMinorUnits: 5000000,
    categoryId: 'salary',
    memberId: 'm1',
    date: DateTime(2026, 6, 1),
  ),
];

final _rules = <RecurringRule>[
  RecurringRule(
    id: 'r1',
    householdId: 'h1',
    categoryId: 'rent',
    memberId: 'm1',
    amountMinorUnits: 900000,
    frequency: RecurrenceFrequency.monthly,
    nextDue: DateTime(2026, 6, 25),
    isActive: true,
    dayOfMonth: 25,
    startDate: DateTime(2026, 6),
  ),
];

final _budgets = <Budget>[
  const Budget(
    id: 'b0',
    householdId: 'h1',
    amountMinorUnits: 3000000,
    isActive: true,
  ),
  const Budget(
    id: 'b1',
    householdId: 'h1',
    categoryId: 'food',
    amountMinorUnits: 2000000,
    isActive: true,
  ),
  const Budget(
    id: 'b2',
    householdId: 'h1',
    categoryId: 'transport',
    amountMinorUnits: 200000,
    isActive: false,
  ),
];

final _totals = <MonthlyTotal>[
  MonthlyTotal(
    month: DateTime(2026, 4),
    incomeMinor: 5000000,
    expenseMinor: 3200000,
  ),
  MonthlyTotal(
    month: DateTime(2026, 5),
    incomeMinor: 4800000,
    expenseMinor: 3900000,
  ),
  MonthlyTotal(
    month: DateTime(2026, 6),
    incomeMinor: 5000000,
    expenseMinor: 2384567,
  ),
];

Widget _app({
  required MemberRole role,
  required Widget child,
  required Locale locale,
}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        membershipProvider.overrideWith(
          (ref) async => Membership(household: _household, role: role),
        ),
        categoriesProvider.overrideWith((ref) async => _categories),
        membersProvider.overrideWith((ref) async => _members),
        budgetsProvider.overrideWith(
          (ref) async =>
              role == MemberRole.child ? const <Budget>[] : _budgets,
        ),
        dashboardMonthTransactionsProvider.overrideWith(
          (ref) async => _transactions,
        ),
        recurringRulesProvider.overrideWith(
          (ref) async =>
              role == MemberRole.child ? const <RecurringRule>[] : _rules,
        ),
        monthlyTotalsProvider.overrideWith((ref) async => _totals),
      ],
      child: MaterialApp(
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

const _sizes = <Size>[
  Size(360, 800),
  Size(800, 1000),
  Size(1854, 1000),
];

void main() {
  for (final size in _sizes) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final role in MemberRole.values) {
        testWidgets(
          'Budgets lays out at ${size.width.toInt()}px, '
          '${locale.languageCode}, ${role.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _app(
                role: role,
                locale: locale,
                child: const BudgetsScreen(),
              ),
            );
            await _settle(tester);

            expect(tester.takeException(), isNull);
            expect(find.byType(BudgetsScreen), findsOneWidget);
          },
        );

        testWidgets(
          'Reports lays out at ${size.width.toInt()}px, '
          '${locale.languageCode}, ${role.name}',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _app(
                role: role,
                locale: locale,
                child: const ReportsScreen(),
              ),
            );
            await _settle(tester);

            expect(tester.takeException(), isNull);
            expect(find.byType(ReportsScreen), findsOneWidget);
          },
        );
      }
    }
  }

  testWidgets('a child (RLS-empty data) sees the empty Budgets state',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        role: MemberRole.child,
        locale: const Locale('ar'),
        child: const BudgetsScreen(),
      ),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
  });
}
