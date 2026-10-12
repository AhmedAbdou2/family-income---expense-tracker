import 'entities.dart';

/// Monthly budget limits. Reads go straight through RLS (owner/adult only);
/// every write goes through the migration-16 RPCs, which validate the
/// household, the category and the amount server-side.
abstract interface class BudgetsRepository {
  Future<List<Budget>> listBudgets({required String householdId});

  /// Upserts the limit for one category (resumes it if paused). Returns the
  /// budget id.
  Future<String> setCategoryBudget({
    required String householdId,
    required String categoryId,
    required int amountMinorUnits,
  });

  /// Upserts the household's single overall limit. Returns the budget id.
  Future<String> setOverallBudget({
    required String householdId,
    required int amountMinorUnits,
  });

  Future<void> setActive({
    required String budgetId,
    required bool isActive,
  });

  Future<void> deleteBudget({required String budgetId});
}
