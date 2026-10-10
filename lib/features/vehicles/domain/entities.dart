/// Vehicles, fuel logs and maintenance reminders (Phase 3). Pure Dart - no
/// Flutter or Supabase imports.
///
/// Note: odometer (km) and liters are PHYSICAL quantities, not money, so
/// they use `double` (the DB columns are numeric(10,1) / numeric(10,3)).
/// Money (fuel/service cost) still travels as integer minor units - see
/// [Money] and AGENTS.md.
enum FuelType {
  petrol('petrol'),
  diesel('diesel'),
  electric('electric'),
  hybrid('hybrid');

  const FuelType(this.dbValue);

  final String dbValue;

  static FuelType fromDb(String value) =>
      FuelType.values.firstWhere((type) => type.dbValue == value);
}

/// A vehicle of the household. Archived (isActive == false) vehicles stay
/// for history but are hidden from pickers.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.householdId,
    required this.name,
    required this.fuelType,
    required this.currentOdometerKm,
    required this.isActive,
    this.plate,
  });

  final String id;
  final String householdId;
  final String name;
  final String? plate;
  final FuelType fuelType;
  final double currentOdometerKm;
  final bool isActive;
}

/// One fill-up (or charge). Always paired with ONE expense transaction
/// whose id is [transactionId] - the single record of that spending.
class FuelLog {
  const FuelLog({
    required this.id,
    required this.householdId,
    required this.vehicleId,
    required this.date,
    required this.odometerKm,
    required this.liters,
    required this.totalCostMinorUnits,
    required this.isFull,
    this.transactionId,
  });

  final String id;
  final String householdId;
  final String vehicleId;
  final DateTime date;
  final double odometerKm;
  final double liters;
  final int totalCostMinorUnits;
  final bool isFull;
  final String? transactionId;
}

/// A per-vehicle reminder, due by date and/or odometer. An interval
/// (days and/or km) re-arms it after completion.
class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.householdId,
    required this.vehicleId,
    required this.name,
    this.dueDate,
    this.dueOdometerKm,
    this.intervalDays,
    this.intervalKm,
    this.completedAt,
  });

  final String id;
  final String householdId;
  final String vehicleId;
  final String name;
  final DateTime? dueDate;
  final double? dueOdometerKm;
  final int? intervalDays;
  final double? intervalKm;
  final DateTime? completedAt;
}
