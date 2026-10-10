import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../domain/entities.dart';
import '../domain/transactions_repository.dart';

/// Reads `amount::text` so no float ever enters the app: the decimal
/// string goes straight through [Money.decimalStringToMinorUnits].
const _columns =
    'id, household_id, type, amount::text, category_id, member_id, '
    'vehicle_id, pet_id, recurring_rule_id, date, note, created_by';

class TransactionsRepositoryImpl implements TransactionsRepository {
  TransactionsRepositoryImpl(this._client);

  final SupabaseClient _client;

  Transaction _map(Map<String, dynamic> row) => Transaction(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        type: TransactionType.fromDb(row['type'] as String),
        amountMinorUnits:
            Money.decimalStringToMinorUnits(row['amount'] as String),
        categoryId: row['category_id'] as String,
        memberId: row['member_id'] as String,
        date: DateTime.parse(row['date'] as String),
        note: row['note'] as String?,
        vehicleId: row['vehicle_id'] as String?,
        petId: row['pet_id'] as String?,
        recurringRuleId: row['recurring_rule_id'] as String?,
        createdBy: row['created_by'] as String?,
      );

  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Future<List<Transaction>> listTransactions({
    required String householdId,
    required DateTime month,
    String? memberId,
    String? petId,
  }) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);

      PostgrestFilterBuilder<PostgrestList> query = _client
          .from('transactions')
          .select(_columns)
          .eq('household_id', householdId)
          .gte('date', _dateKey(start))
          .lt('date', _dateKey(end));
      if (memberId != null) {
        query = query.eq('member_id', memberId);
      }
      if (petId != null) {
        query = query.eq('pet_id', petId);
      }
      final rows = await query
          .order('date', ascending: false)
          .order('created_at', ascending: false);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Transaction?> getTransaction({required String id}) async {
    try {
      final row = await _client
          .from('transactions')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Transaction> createTransaction({
    required String householdId,
    required TransactionType type,
    required int amountMinorUnits,
    required String categoryId,
    required String memberId,
    required DateTime date,
    String? note,
    String? petId,
  }) async {
    try {
      final row = await _client
          .from('transactions')
          .insert({
            'household_id': householdId,
            'type': type.dbValue,
            'amount': Money.minorUnitsToDecimalString(amountMinorUnits),
            'category_id': categoryId,
            'member_id': memberId,
            'date': _dateKey(date),
            'pet_id': petId,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          })
          .select(_columns)
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updateTransaction({
    required String id,
    required TransactionType type,
    required int amountMinorUnits,
    required String categoryId,
    required String memberId,
    required DateTime date,
    String? note,
    String? petId,
  }) async {
    try {
      await _client.from('transactions').update({
        'type': type.dbValue,
        'amount': Money.minorUnitsToDecimalString(amountMinorUnits),
        'category_id': categoryId,
        'member_id': memberId,
        'date': _dateKey(date),
        'pet_id': petId,
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      }).eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteTransaction({required String id}) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
