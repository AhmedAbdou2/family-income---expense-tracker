import 'entities.dart';

/// Vehicles of the household (owner/adult only - RLS narrows children to
/// an empty list). Writes go straight to the table.
abstract interface class VehiclesRepository {
  /// All vehicles, archived included (the UI filters), oldest first.
  Future<List<Vehicle>> listVehicles({required String householdId});

  /// One row by id, or null when it doesn't exist / RLS hides it.
  Future<Vehicle?> getVehicle({required String id});

  Future<Vehicle> createVehicle({
    required String householdId,
    required String name,
    required FuelType fuelType,
    required double currentOdometerKm,
    String? plate,
  });

  Future<void> updateVehicle({
    required String id,
    required String name,
    required FuelType fuelType,
    required double currentOdometerKm,
    required bool isActive,
    String? plate,
  });
}
