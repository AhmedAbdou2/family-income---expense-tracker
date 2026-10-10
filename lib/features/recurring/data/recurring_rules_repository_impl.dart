import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../domain/entities.dart';
import '../domain/recurring_rules_repository.dart';

const _columns =
    'id, household_id, category_id, member_id, amount::text, frequency, '
    'day_of_month, next_due, is_active, name, start_date, end_date, '
    'vehicle_id, pet_id';

class RecurringRulesRepositoryImpl implements RecurringRulesRepository {
  RecurringRulesRepositoryImpl(this._client);

  final SupabaseClient _client;

  String? _dateKey(DateTime? day) => day == null
      ? null
      : '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';

  DateTime? _parse(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  RecurringRule _map(Map<String, dynamic> row) => RecurringRule(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        categoryId: row['category_id'] as String,
        memberId: row['member_id'] as String,
        amountMinorUnits:
            Money.decimalStringToMinorUnits(row['amount'] as String),
        frequency: RecurrenceFrequency.fromDb(row['frequency'] as String),
        nextDue: DateTime.parse(row['next_due'] as String),
        isActive: row['is_active'] as bool,
        name: row['name'] as String?,
        dayOfMonth: row['day_of_month'] as int?,
        startDate: _parse(row['start_date']),
        endDate: _parse(row['end_date']),
        vehicleId: row['vehicle_id'] as String?,
        petId: row['pet_id'] as String?,
      );

  @override
  Future<List<RecurringRule>> listRules({required String householdId}) async {
    try {
      final rows = await _client
          .from('recurring_rules')
          .select(_columns)
          .eq('household_id', householdId)
          .order('next_due', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<RecurringRule?> getRule({required String id}) async {
    try {
      final row = await _client
          .from('recurring_rules')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<RecurringRule> createRule({
    required String householdId,
    required String categoryId,
    required String memberId,
    required int amountMinorUnits,
    required RecurrenceFrequency frequency,
    int? dayOfMonth,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? vehicleId,
    String? petId,
  }) async {
    try {
      final firstDue = startDate ?? DateTime.now();
      final row = await _client
          .from('recurring_rules')
          .insert({
            'household_id': householdId,
            'category_id': categoryId,
            'member_id': memberId,
            'amount': Money.minorUnitsToDecimalString(amountMinorUnits),
            'frequency': frequency.dbValue,
            'day_of_month': frequency == RecurrenceFrequency.monthly
                ? (dayOfMonth ?? firstDue.day)
                : dayOfMonth,
            'next_due': _dateKey(firstDue),
            'start_date': _dateKey(startDate),
            'end_date': _dateKey(endDate),
            'name': (name == null || name.trim().isEmpty) ? null : name.trim(),
            'vehicle_id': vehicleId,
            'pet_id': petId,
          })
          .select(_columns)
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updateRule({
    required String id,
    required String categoryId,
    required String memberId,
    required int amountMinorUnits,
    required RecurrenceFrequency frequency,
    required DateTime nextDue,
    required bool isActive,
    int? dayOfMonth,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? vehicleId,
    String? petId,
  }) async {
    try {
      await _client.from('recurring_rules').update({
        'category_id': categoryId,
        'member_id': memberId,
        'amount': Money.minorUnitsToDecimalString(amountMinorUnits),
        'frequency': frequency.dbValue,
        'day_of_month': frequency == RecurrenceFrequency.monthly
            ? (dayOfMonth ?? nextDue.day)
            : dayOfMonth,
        'next_due': _dateKey(nextDue),
        'is_active': isActive,
        'start_date': _dateKey(startDate),
        'end_date': _dateKey(endDate),
        'name': (name == null || name.trim().isEmpty) ? null : name.trim(),
        'vehicle_id': vehicleId,
        'pet_id': petId,
      }).eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteRule({required String id}) async {
    try {
      await _client.from('recurring_rules').delete().eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<int> generateDue() async {
    try {
      final result =
          await _client.rpc('generate_recurring_transactions');
      return (result as num).toInt();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
