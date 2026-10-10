import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/pets_repository.dart';

const _columns =
    'id, household_id, name, type, birth_date, notes, is_active';

class PetsRepositoryImpl implements PetsRepository {
  PetsRepositoryImpl(this._client);

  final SupabaseClient _client;

  String? _dateKey(DateTime? day) => day == null
      ? null
      : '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';

  Pet _map(Map<String, dynamic> row) => Pet(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        name: row['name'] as String,
        type: PetType.fromDb(row['type'] as String),
        birthDate: row['birth_date'] == null
            ? null
            : DateTime.parse(row['birth_date'] as String),
        notes: row['notes'] as String?,
        isActive: row['is_active'] as bool,
      );

  @override
  Future<List<Pet>> listPets({required String householdId}) async {
    try {
      final rows = await _client
          .from('pets')
          .select(_columns)
          .eq('household_id', householdId)
          .order('created_at', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Pet?> getPet({required String id}) async {
    try {
      final row = await _client
          .from('pets')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Pet> createPet({
    required String householdId,
    required String name,
    required PetType type,
    DateTime? birthDate,
    String? notes,
  }) async {
    try {
      final row = await _client
          .from('pets')
          .insert({
            'household_id': householdId,
            'name': name.trim(),
            'type': type.dbValue,
            'birth_date': _dateKey(birthDate),
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          })
          .select(_columns)
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updatePet({
    required String id,
    required String name,
    required PetType type,
    required bool isActive,
    DateTime? birthDate,
    String? notes,
  }) async {
    try {
      await _client.from('pets').update({
        'name': name.trim(),
        'type': type.dbValue,
        'is_active': isActive,
        'birth_date': _dateKey(birthDate),
        'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      }).eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
