import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities.dart';
import '../domain/vehicles_repository.dart';

/// numeric columns arrive as JSON numbers; accept a string too so a
/// PostgREST change can never break the parse.
double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Not a number: $value');
}

const _columns =
    'id, household_id, name, plate, fuel_type, current_odometer, is_active';

class VehiclesRepositoryImpl implements VehiclesRepository {
  VehiclesRepositoryImpl(this._client);

  final SupabaseClient _client;

  Vehicle _map(Map<String, dynamic> row) => Vehicle(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        name: row['name'] as String,
        plate: row['plate'] as String?,
        fuelType: FuelType.fromDb(row['fuel_type'] as String),
        currentOdometerKm: _asDouble(row['current_odometer']),
        isActive: row['is_active'] as bool,
      );

  @override
  Future<List<Vehicle>> listVehicles({required String householdId}) async {
    try {
      final rows = await _client
          .from('vehicles')
          .select(_columns)
          .eq('household_id', householdId)
          .order('created_at', ascending: true);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Vehicle?> getVehicle({required String id}) async {
    try {
      final row = await _client
          .from('vehicles')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<Vehicle> createVehicle({
    required String householdId,
    required String name,
    required FuelType fuelType,
    required double currentOdometerKm,
    String? plate,
  }) async {
    try {
      final row = await _client
          .from('vehicles')
          .insert({
            'household_id': householdId,
            'name': name.trim(),
            'fuel_type': fuelType.dbValue,
            'current_odometer': currentOdometerKm,
            if (plate != null && plate.trim().isNotEmpty) 'plate': plate.trim(),
          })
          .select(_columns)
          .single();
      return _map(row);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<void> updateVehicle({
    required String id,
    required String name,
    required FuelType fuelType,
    required double currentOdometerKm,
    required bool isActive,
    String? plate,
  }) async {
    try {
      await _client.from('vehicles').update({
        'name': name.trim(),
        'fuel_type': fuelType.dbValue,
        'current_odometer': currentOdometerKm,
        'is_active': isActive,
        'plate': (plate == null || plate.trim().isEmpty) ? null : plate.trim(),
      }).eq('id', id);
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
