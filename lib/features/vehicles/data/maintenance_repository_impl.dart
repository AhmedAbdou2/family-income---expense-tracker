import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/maintenance_repository.dart';

const _columns =
    'id, household_id, vehicle_id, name, due_date, due_odometer_km, '
    'interval_days, interval_km, completed_at';

double? _asNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Not a number: $value');
}

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl(this._client);

  final SupabaseClient _client;

  String? _dateKey(DateTime? day) => day == null
      ? null
      : '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';

  MaintenanceItem _map(Map<String, dynamic> row) => MaintenanceItem(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        vehicleId: row['vehicle_id'] as String,
        name: row['name'] as String,
        dueDate: row['due_date'] == null
            ? null
            : DateTime.parse(row['due_date'] as String),
        dueOdometerKm: _asNullableDouble(row['due_odometer_km']),
        intervalDays: row['interval_days'] as int?,
        intervalKm: _asNullableDouble(row['interval_km']),
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.parse(row['completed_at'] as String),
      );

  @override
  Future<List<MaintenanceItem>> listMaintenance({
    required String householdId,
    String? vehicleId,
  }) async {
    try {
      PostgrestFilterBuilder<PostgrestList> query = _client
          .from('maintenance_items')
          .select(_columns)
          .eq('household_id', householdId);
      if (vehicleId != null) {
        query = query.eq('vehicle_id', vehicleId);
      }
      final rows = await query.order('created_at', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<MaintenanceItem?> getMaintenance({required String id}) async {
    try {
      final row = await _client
          .from('maintenance_items')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<MaintenanceItem> createMaintenance({
    required String householdId,
    required String vehicleId,
    required String name,
    DateTime? dueDate,
    double? dueOdometerKm,
    int? intervalDays,
    double? intervalKm,
  }) async {
    try {
      final row = await _client
          .from('maintenance_items')
          .insert({
            'household_id': householdId,
            'vehicle_id': vehicleId,
            'name': name.trim(),
            'due_date': _dateKey(dueDate),
            'due_odometer_km': dueOdometerKm,
            'interval_days': intervalDays,
            'interval_km': intervalKm,
          })
          .select(_columns)
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updateMaintenance({
    required String id,
    required String name,
    DateTime? dueDate,
    double? dueOdometerKm,
    int? intervalDays,
    double? intervalKm,
  }) async {
    try {
      await _client.from('maintenance_items').update({
        'name': name.trim(),
        'due_date': _dateKey(dueDate),
        'due_odometer_km': dueOdometerKm,
        'interval_days': intervalDays,
        'interval_km': intervalKm,
      }).eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> deleteMaintenance({required String id}) async {
    try {
      await _client.from('maintenance_items').delete().eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> completeMaintenance({
    required String itemId,
    int? amountMinorUnits,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'complete_maintenance',
        params: {
          'p_item_id': itemId,
          'p_amount_minor': amountMinorUnits,
          'p_note':
              (note == null || note.trim().isEmpty) ? null : note.trim(),
        },
      );
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
