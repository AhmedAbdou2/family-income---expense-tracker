import 'entities.dart';

/// Maintenance reminders (owner/adult only). Direct table CRUD for the
/// item itself; completing goes through an RPC that can also record a
/// service expense and re-arm the next due date/odometer.
abstract interface class MaintenanceRepository {
  Future<List<MaintenanceItem>> listMaintenance({
    required String householdId,
    String? vehicleId,
  });

  /// One row by id, or null when it doesn't exist / RLS hides it.
  Future<MaintenanceItem?> getMaintenance({required String id});

  Future<MaintenanceItem> createMaintenance({
    required String householdId,
    required String vehicleId,
    required String name,
    DateTime? dueDate,
    double? dueOdometerKm,
    int? intervalDays,
    double? intervalKm,
  });

  Future<void> updateMaintenance({
    required String id,
    required String name,
    DateTime? dueDate,
    double? dueOdometerKm,
    int? intervalDays,
    double? intervalKm,
  });

  Future<void> deleteMaintenance({required String id});

  /// Mark complete (+ optional service cost), re-arming from the interval.
  Future<void> completeMaintenance({
    required String itemId,
    int? amountMinorUnits,
    String? note,
  });
}
