import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/core/utils/money.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/household/domain/entities.dart';
import 'package:family_income_expense_tracker/features/household/presentation/dashboard_screen.dart';
import 'package:family_income_expense_tracker/features/household/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/members/domain/entities.dart';
import 'package:family_income_expense_tracker/features/members/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/recurring_rules_repository.dart';
import 'package:family_income_expense_tracker/features/recurring/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/transactions/domain/entities.dart';
import 'package:family_income_expense_tracker/features/transactions/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The generator is a no-op here; the test drives the numbers directly.
class _FakeRecurringRepo implements RecurringRulesRepository {
  @override
  Future<int> generateDue() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

void main() {
  testWidgets(
      'dashboard takes posted fixed from real transactions (no double count) '
      'and shows the help lines', (tester) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // A fixed rule whose projected post is 200.00 ...
    final rule = RecurringRule(
      id: 'r1',
      householdId: 'h1',
      categoryId: 'cat-exp',
      memberId: 'm1',
      amountMinorUnits: 20000,
      frequency: RecurrenceFrequency.monthly,
      nextDue: monthStart,
      isActive: true,
      dayOfMonth: 1,
      startDate: monthStart,
    );
    // ... but the actually posted transaction is only 150.00.
    final transactions = <Transaction>[
      Transaction(
        id: 't1',
        householdId: 'h1',
        type: TransactionType.income,
        amountMinorUnits: 100000,
        categoryId: 'cat-inc',
        memberId: 'm1',
        date: monthStart,
      ),
      Transaction(
        id: 't2',
        householdId: 'h1',
        type: TransactionType.expense,
        amountMinorUnits: 15000,
        categoryId: 'cat-exp',
        memberId: 'm1',
        date: monthStart,
        recurringRuleId: 'r1',
      ),
      Transaction(
        id: 't3',
        householdId: 'h1',
        type: TransactionType.expense,
        amountMinorUnits: 1000,
        categoryId: 'cat-exp',
        memberId: 'm1',
        date: monthStart,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettings.new),
          membershipProvider.overrideWith(
            (ref) async => const Membership(
              household: Household(id: 'h1', name: 'Home', currency: 'EGP'),
              role: MemberRole.owner,
            ),
          ),
          recurringRulesRepositoryProvider
              .overrideWithValue(_FakeRecurringRepo()),
          recurringRulesProvider.overrideWith((ref) async => [rule]),
          categoriesProvider.overrideWith(
            (ref) async => const [
              Category(
                id: 'cat-inc',
                householdId: 'h1',
                group: CategoryGroup.income,
                nameEn: 'Salary',
                nameAr: 'راتب',
              ),
              Category(
                id: 'cat-exp',
                householdId: 'h1',
                group: CategoryGroup.general,
                nameEn: 'Food',
                nameAr: 'طعام',
              ),
            ],
          ),
          membersProvider.overrideWith(
            (ref) async => const [
              Member(
                id: 'm1',
                householdId: 'h1',
                name: 'Alex',
                isActive: true,
                userId: 'u1',
              ),
            ],
          ),
          dashboardMonthTransactionsProvider
              .overrideWith((ref) async => transactions),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: DashboardScreen(),
        ),
      ),
    );

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    // 1000.00 income - 150.00 actually posted fixed = 850.00 (not 800.00).
    final expectedRemaining =
        Money.format(minorUnits: 85000, currencyCode: 'EGP');
    final buggyRemaining =
        Money.format(minorUnits: 80000, currencyCode: 'EGP');
    expect(find.text(expectedRemaining), findsOneWidget);
    expect(find.text(buggyRemaining), findsNothing);

    // 150.00 posted fixed + 10.00 manual = 160.00 expenses.
    expect(
      find.text(Money.format(minorUnits: 16000, currencyCode: 'EGP')),
      findsOneWidget,
    );

    expect(
      find.text('All expenses this month, including posted fixed ones.'),
      findsOneWidget,
    );
    expect(
      find.text('Fixed commitments still due later this month.'),
      findsOneWidget,
    );
    expect(
      find.text('Income minus posted and still-due fixed commitments.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'deleting the posted fixed transaction recomputes expenses and remaining '
      'without touching the still-due figure', (tester) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final rule = RecurringRule(
      id: 'r1',
      householdId: 'h1',
      categoryId: 'cat-exp',
      memberId: 'm1',
      amountMinorUnits: 20000,
      frequency: RecurrenceFrequency.monthly,
      nextDue: monthStart,
      isActive: true,
      dayOfMonth: 1,
      startDate: monthStart,
    );
    // The posted fixed row (t2) has been deleted, so only income + a manual
    // expense remain.
    final transactions = <Transaction>[
      Transaction(
        id: 't1',
        householdId: 'h1',
        type: TransactionType.income,
        amountMinorUnits: 100000,
        categoryId: 'cat-inc',
        memberId: 'm1',
        date: monthStart,
      ),
      Transaction(
        id: 't3',
        householdId: 'h1',
        type: TransactionType.expense,
        amountMinorUnits: 1000,
        categoryId: 'cat-exp',
        memberId: 'm1',
        date: monthStart,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettings.new),
          membershipProvider.overrideWith(
            (ref) async => const Membership(
              household: Household(id: 'h1', name: 'Home', currency: 'EGP'),
              role: MemberRole.owner,
            ),
          ),
          recurringRulesRepositoryProvider
              .overrideWithValue(_FakeRecurringRepo()),
          recurringRulesProvider.overrideWith((ref) async => [rule]),
          categoriesProvider.overrideWith(
            (ref) async => const [
              Category(
                id: 'cat-inc',
                householdId: 'h1',
                group: CategoryGroup.income,
                nameEn: 'Salary',
                nameAr: 'راتب',
              ),
              Category(
                id: 'cat-exp',
                householdId: 'h1',
                group: CategoryGroup.general,
                nameEn: 'Food',
                nameAr: 'طعام',
              ),
            ],
          ),
          membersProvider.overrideWith(
            (ref) async => const [
              Member(
                id: 'm1',
                householdId: 'h1',
                name: 'Alex',
                isActive: true,
                userId: 'u1',
              ),
            ],
          ),
          dashboardMonthTransactionsProvider
              .overrideWith((ref) async => transactions),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: DashboardScreen(),
        ),
      ),
    );

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    // 1000.00 income, no posted fixed left, nothing still due -> remaining
    // 1000.00 and expenses only the 10.00 manual row. (The 1000.00 appears
    // twice: the income stat and the "left after fixed" stat.)
    expect(
      find.text(Money.format(minorUnits: 100000, currencyCode: 'EGP')),
      findsNWidgets(2),
    );
    expect(
      find.text(Money.format(minorUnits: 1000, currencyCode: 'EGP')),
      findsOneWidget,
    );
    // The 150.00/160.00 figures from the other scenario must be gone.
    expect(
      find.text(Money.format(minorUnits: 85000, currencyCode: 'EGP')),
      findsNothing,
    );
    expect(
      find.text(Money.format(minorUnits: 16000, currencyCode: 'EGP')),
      findsNothing,
    );
  });

  testWidgets('Arabic fixed labels read consistently and fit at 360px',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final rule = RecurringRule(
      id: 'r1',
      householdId: 'h1',
      categoryId: 'cat-exp',
      memberId: 'm1',
      amountMinorUnits: 20000,
      frequency: RecurrenceFrequency.monthly,
      nextDue: monthStart,
      isActive: true,
      dayOfMonth: 1,
      startDate: monthStart,
    );
    final transactions = <Transaction>[
      Transaction(
        id: 't1',
        householdId: 'h1',
        type: TransactionType.income,
        amountMinorUnits: 100000,
        categoryId: 'cat-inc',
        memberId: 'm1',
        date: monthStart,
      ),
      Transaction(
        id: 't2',
        householdId: 'h1',
        type: TransactionType.expense,
        amountMinorUnits: 15000,
        categoryId: 'cat-exp',
        memberId: 'm1',
        date: monthStart,
        recurringRuleId: 'r1',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_TestSettings.new),
          membershipProvider.overrideWith(
            (ref) async => const Membership(
              household: Household(id: 'h1', name: 'Home', currency: 'EGP'),
              role: MemberRole.owner,
            ),
          ),
          recurringRulesRepositoryProvider
              .overrideWithValue(_FakeRecurringRepo()),
          recurringRulesProvider.overrideWith((ref) async => [rule]),
          categoriesProvider.overrideWith(
            (ref) async => const [
              Category(
                id: 'cat-inc',
                householdId: 'h1',
                group: CategoryGroup.income,
                nameEn: 'Salary',
                nameAr: 'راتب',
              ),
              Category(
                id: 'cat-exp',
                householdId: 'h1',
                group: CategoryGroup.general,
                nameEn: 'Food',
                nameAr: 'طعام',
              ),
            ],
          ),
          membersProvider.overrideWith(
            (ref) async => const [
              Member(
                id: 'm1',
                householdId: 'h1',
                name: 'Alex',
                isActive: true,
                userId: 'u1',
              ),
            ],
          ),
          dashboardMonthTransactionsProvider
              .overrideWith((ref) async => transactions),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: DashboardScreen(),
        ),
      ),
    );

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    // The three fixed labels and the two help lines must all be present and,
    // with the longer Arabic wording, lay out at a 360px phone width.
    expect(tester.takeException(), isNull);
    expect(find.text('المسجَّل'), findsOneWidget);
    expect(find.text('مستحق لاحقًا'), findsOneWidget);
    expect(find.text('المتبقي بعد المصروفات الثابتة'), findsOneWidget);
    expect(
      find.text('المصروفات الثابتة المسجّلة هذا الشهر.'),
      findsOneWidget,
    );
    expect(
      find.text('المصروفات الثابتة المستحقة لاحقًا هذا الشهر.'),
      findsOneWidget,
    );
    expect(
      find.text('الإيرادات ناقص المصروفات الثابتة المسجّلة والمستحقة لاحقًا.'),
      findsOneWidget,
    );
  });
}
