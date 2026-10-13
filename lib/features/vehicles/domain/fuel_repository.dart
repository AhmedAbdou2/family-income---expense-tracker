import 'entities.dart';

/// Fuel logs. Every add/delete goes through a SECURITY DEFINER RPC so the
/// paired expense transaction can never desync from the log.
abstract interface class FuelRepository {
  /// Logs of one vehicle (newest first) when [vehicleId] is given, else
  /// every log of the household.
  Future<List<FuelLog>> listFuelLogs({
    required String householdId,
    String? vehicleId,
  });

  /// Add a fill-up: validates the odometer, writes the linked expense, and
  /// bumps the vehicle odometer. Returns the new log id.
  Future<String> addFuelLog({
    required String vehicleId,
    required DateTime date,
    required double odometerKm,
    required double liters,
    required int totalCostMinorUnits,
    required bool isFull,
  });

  /// Delete a log and its linked expense together. Returns the storage
  /// paths of the receipts that cascaded away with that expense (empty when
  /// there were none) so the caller can remove the objects too.
  Future<List<String>> deleteFuelLog({required String logId});
}
