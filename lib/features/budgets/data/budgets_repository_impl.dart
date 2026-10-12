import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../domain/budgets_repository.dart';
import '../domain/entities.dart';

/// Reads `amount::text` so no float ever enters the app: the decimal
/// string goes straight through [Money.decimalStringToMinorUnits].
const _columns = 'id, household_id, category_id, amount::text, is_active';

class BudgetsRepositoryImpl implements BudgetsRepository {
  BudgetsRepositoryImpl(this._client);

  final SupabaseClient _client;

  Budget _map(Map<String, dynamic> row) => Budget(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        categoryId: row['category_id'] as String?,
        amountMinorUnits:
            Money.decimalStringToMinorUnits(row['amount'] as String),
        isActive: row['is_active'] as bool,
      );

  @override
  Future<List<Budget>> listBudgets({required String householdId}) async {
    try {
      final rows = await _client
          .from('budgets')
          .select(_columns)
          .eq('household_id', householdId);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<String> setCategoryBudget({
    required String householdId,
    required String categoryId,
    required int amountMinorUnits,
  }) async {
    try {
      final result = await _client.rpc(
        'set_category_budget',
        params: {
          'p_household_id': householdId,
          'p_category_id': categoryId,
          'p_amount': Money.minorUnitsToDecimalString(amountMinorUnits),
        },
      );
      return result as String;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<String> setOverallBudget({
    required String householdId,
    required int amountMinorUnits,
  }) async {
    try {
      final result = await _client.rpc(
        'set_overall_budget',
        params: {
          'p_household_id': householdId,
          'p_amount': Money.minorUnitsToDecimalString(amountMinorUnits),
        },
      );
      return result as String;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> setActive({
    required String budgetId,
    required bool isActive,
  }) async {
    try {
      await _client.rpc(
        'set_budget_active',
        params: {'p_budget_id': budgetId, 'p_active': isActive},
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteBudget({required String budgetId}) async {
    try {
      await _client.rpc(
        'delete_budget',
        params: {'p_budget_id': budgetId},
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
