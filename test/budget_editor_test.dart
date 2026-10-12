import 'package:family_income_expense_tracker/core/l10n/l10n.dart';
import 'package:family_income_expense_tracker/core/settings/settings_controller.dart';
import 'package:family_income_expense_tracker/features/budgets/domain/budgets_repository.dart';
import 'package:family_income_expense_tracker/features/budgets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/budgets/presentation/budget_editor.dart';
import 'package:family_income_expense_tracker/features/budgets/presentation/providers.dart';
import 'package:family_income_expense_tracker/features/categories/domain/entities.dart';
import 'package:family_income_expense_tracker/features/categories/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor must reject amounts the database would reject too: zero,
/// a negative and more than two decimals. Valid input must reach the RPC
/// with an EXACT integer minor-unit amount.
class _TestSettings extends SettingsController {
  @override
  SettingsState build() => const SettingsState();
}

class _RecordingBudgetsRepo implements BudgetsRepository {
  final List<String> calls = [];

  @override
  Future<List<Budget>> listBudgets({required String householdId}) async =>
      const <Budget>[];

  @override
  Future<String> setCategoryBudget({
    required String householdId,
    required String categoryId,
    required int amountMinorUnits,
  }) async {
    calls.add('category:$categoryId:$amountMinorUnits');
    return 'b-new';
  }

  @override
  Future<String> setOverallBudget({
    required String householdId,
    required int amountMinorUnits,
  }) async {
    calls.add('overall:$amountMinorUnits');
    return 'b-overall';
  }

  @override
  Future<void> setActive({
    required String budgetId,
    required bool isActive,
  }) async {
    calls.add('active:$budgetId:$isActive');
  }

  @override
  Future<void> deleteBudget({required String budgetId}) async {
    calls.add('delete:$budgetId');
  }
}

final _categories = <Category>[
  const Category(
    id: 'food',
    householdId: 'h1',
    group: CategoryGroup.general,
    nameEn: 'Food',
    nameAr: 'طعام',
  ),
  const Category(
    id: 'salary',
    householdId: 'h1',
    group: CategoryGroup.income,
    nameEn: 'Salary',
    nameAr: 'راتب',
  ),
];

Widget _host(_RecordingBudgetsRepo repo, BudgetEditorMode mode) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_TestSettings.new),
        budgetsRepositoryProvider.overrideWithValue(repo),
        budgetsProvider.overrideWith((ref) async => const <Budget>[]),
        categoriesProvider.overrideWith((ref) async => _categories),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showBudgetEditor(
                  context,
                  householdId: 'h1',
                  mode: mode,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, _RecordingBudgetsRepo repo,
    BudgetEditorMode mode) async {
  await tester.pumpWidget(_host(repo, mode));
  await tester.tap(find.text('open'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('zero is rejected and never reaches the RPC', (tester) async {
    final repo = _RecordingBudgetsRepo();
    await _open(tester, repo, BudgetEditorMode.overall);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Enter valid values.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.text('0'), findsWidgets); // dialog still open
    expect(tester.takeException(), isNull);
  });

  testWidgets('more than two decimals is rejected', (tester) async {
    final repo = _RecordingBudgetsRepo();
    await _open(tester, repo, BudgetEditorMode.overall);

    await tester.enterText(find.byType(TextField), '1.234');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('Enter valid values.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a valid overall limit reaches the RPC as exact minor units',
      (tester) async {
    final repo = _RecordingBudgetsRepo();
    await _open(tester, repo, BudgetEditorMode.overall);

    await tester.enterText(find.byType(TextField), '1500.25');
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(repo.calls, ['overall:150025']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a category limit stores the picked category and amount',
      (tester) async {
    final repo = _RecordingBudgetsRepo();
    await _open(tester, repo, BudgetEditorMode.category);

    // Only expense categories are offered - income is filtered out.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('Salary'), findsNothing);
    await tester.tap(find.text('Food').last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(repo.calls, ['category:food:50000']);
    expect(tester.takeException(), isNull);
  });
}
