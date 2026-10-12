import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../categories/presentation/providers.dart';
import '../../household/presentation/providers.dart';
import '../../recurring/presentation/providers.dart';
import '../../transactions/presentation/providers.dart';
import '../data/budgets_repository_impl.dart';
import '../domain/budget_progress.dart';
import '../domain/budgets_repository.dart';
import '../domain/entities.dart';

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Monthly limits of the current household (owner/adult only via RLS).
final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Budget>[];
  return ref
      .watch(budgetsRepositoryProvider)
      .listBudgets(householdId: membership.household.id);
});

/// Budget rows + progress + alert counts for the SHARED dashboard month, so
/// every figure reconciles exactly with the dashboard's month summary. All
/// inputs are the same providers the dashboard reads.
final budgetOverviewProvider = FutureProvider<BudgetOverview>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const BudgetOverview.empty();
  final month = ref.watch(dashboardMonthProvider);
  final budgets = await ref.watch(budgetsProvider.future);
  final transactions =
      await ref.watch(dashboardMonthTransactionsProvider.future);
  final categories = await ref.watch(categoriesProvider.future);
  final rules = await ref.watch(recurringRulesProvider.future);
  return budgetOverview(
    budgets: budgets,
    monthTransactions: transactions,
    categories: categories,
    rules: rules,
    month: month,
  );
});
