import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/pets_repository.dart';

/// Pet reminders (Phase 4b). Reads go through the adult-only SELECT policy;
/// every write is an RPC (the table has no write policies at all).
const _reminderColumns =
    'id, household_id, pet_id, title, kind, due_date, repeat_months, done_at';

class PetRemindersRepositoryImpl implements PetRemindersRepository {
  PetRemindersRepositoryImpl(this._client);

  final SupabaseClient _client;

  PetReminder _mapReminder(Map<String, dynamic> row) => PetReminder(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        petId: row['pet_id'] as String,
        title: row['title'] as String,
        kind: PetReminderKind.fromDb(row['kind'] as String),
        dueDate: DateTime.parse(row['due_date'] as String),
        repeatMonths: (row['repeat_months'] as num?)?.toInt(),
        doneAt: row['done_at'] == null
            ? null
            : DateTime.parse(row['done_at'] as String),
      );

  @override
  Future<List<PetReminder>> listReminders({required String petId}) async {
    try {
      final rows = await _client
          .from('pet_reminders')
          .select(_reminderColumns)
          .eq('pet_id', petId)
          .order('due_date', ascending: true);
      return rows.map(_mapReminder).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<PetReminder> createReminder({
    required String petId,
    required String title,
    required PetReminderKind kind,
    required DateTime dueDate,
    int? repeatMonths,
  }) async {
    try {
      final id = await _client.rpc(
        'create_pet_reminder',
        params: {
          'p_pet_id': petId,
          'p_title': title.trim(),
          'p_kind': kind.dbValue,
          'p_due_date': _dateKey(dueDate),
          'p_repeat_months': repeatMonths,
        },
      ) as String;
      return PetReminder(
        id: id,
        householdId: '',
        petId: petId,
        title: title.trim(),
        kind: kind,
        dueDate: dueDate,
        repeatMonths: repeatMonths,
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updateReminder({
    required String id,
    required String title,
    required PetReminderKind kind,
    required DateTime dueDate,
    int? repeatMonths,
  }) async {
    try {
      await _client.rpc(
        'update_pet_reminder',
        params: {
          'p_reminder_id': id,
          'p_title': title.trim(),
          'p_kind': kind.dbValue,
          'p_due_date': _dateKey(dueDate),
          'p_repeat_months': repeatMonths,
        },
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> completeReminder({
    required String id,
    int? amountMinorUnits,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'complete_pet_reminder',
        params: {
          'p_reminder_id': id,
          'p_amount_minor': amountMinorUnits,
          'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        },
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteReminder({required String id}) async {
    try {
      await _client.rpc(
        'delete_pet_reminder',
        params: {'p_reminder_id': id},
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  String? _dateKey(DateTime? day) => day == null
      ? null
      : '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
}