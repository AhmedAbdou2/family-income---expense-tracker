import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../domain/entities.dart';
import '../domain/fuel_repository.dart';

/// Read `total_cost::text` so money only ever passes through [Money].
const _columns =
    'id, household_id, vehicle_id, date, odometer_km, liters, '
    'total_cost::text, is_full, transaction_id';

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Not a number: $value');
}

class FuelRepositoryImpl implements FuelRepository {
  FuelRepositoryImpl(this._client);

  final SupabaseClient _client;

  String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  FuelLog _map(Map<String, dynamic> row) => FuelLog(
        id: row['id'] as String,
        householdId: row['household_id'] as String,
        vehicleId: row['vehicle_id'] as String,
        date: DateTime.parse(row['date'] as String),
        odometerKm: _asDouble(row['odometer_km']),
        liters: _asDouble(row['liters']),
        totalCostMinorUnits:
            Money.decimalStringToMinorUnits(row['total_cost'] as String),
        isFull: row['is_full'] as bool,
        transactionId: row['transaction_id'] as String?,
      );

  @override
  Future<List<FuelLog>> listFuelLogs({
    required String householdId,
    String? vehicleId,
  }) async {
    try {
      PostgrestFilterBuilder<PostgrestList> query = _client
          .from('fuel_logs')
          .select(_columns)
          .eq('household_id', householdId);
      if (vehicleId != null) {
        query = query.eq('vehicle_id', vehicleId);
      }
      final rows = await query
          .order('date', ascending: false)
          .order('odometer_km', ascending: false);
      return rows.map(_map).toList();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<String> addFuelLog({
    required String vehicleId,
    required DateTime date,
    required double odometerKm,
    required double liters,
    required int totalCostMinorUnits,
    required bool isFull,
  }) async {
    try {
      final result = await _client.rpc(
        'add_fuel_log',
        params: {
          'p_vehicle_id': vehicleId,
          'p_date': _dateKey(date),
          'p_odometer_km': odometerKm,
          'p_liters': liters,
          'p_total_cost_minor': totalCostMinorUnits,
          'p_is_full': isFull,
        },
      );
      return result as String;
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }

  @override
  Future<List<String>> deleteFuelLog({required String logId}) async {
    try {
      final result = await _client.rpc(
        'delete_fuel_log',
        params: {'p_log_id': logId},
      );
      return (result as List<dynamic>? ?? const []).cast<String>();
    } catch (error) {
      throw ExceptionMapper.map(error);
    }
  }
}
