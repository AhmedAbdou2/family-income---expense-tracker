import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../data/fuel_repository_impl.dart';
import '../data/maintenance_repository_impl.dart';
import '../data/vehicles_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/fuel_repository.dart';
import '../domain/maintenance_repository.dart';
import '../domain/vehicles_repository.dart';

final vehiclesRepositoryProvider = Provider<VehiclesRepository>(
  (ref) => VehiclesRepositoryImpl(ref.watch(supabaseClientProvider)),
);

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) => FuelRepositoryImpl(ref.watch(supabaseClientProvider)),
);

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Vehicles of the current household. A child's RLS returns an empty list
/// (vehicles are an adult feature), so the UI must render that gracefully.
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Vehicle>[];
  return ref
      .watch(vehiclesRepositoryProvider)
      .listVehicles(householdId: membership.household.id);
});

/// Fuel logs of one vehicle, or every log when [vehicleId] is null.
final fuelLogsProvider =
    FutureProvider.family<List<FuelLog>, String?>((ref, vehicleId) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <FuelLog>[];
  return ref.watch(fuelRepositoryProvider).listFuelLogs(
        householdId: membership.household.id,
        vehicleId: vehicleId,
      );
});

/// Maintenance reminders of one vehicle, or every one when null.
final maintenanceProvider =
    FutureProvider.family<List<MaintenanceItem>, String?>(
        (ref, vehicleId) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <MaintenanceItem>[];
  return ref.watch(maintenanceRepositoryProvider).listMaintenance(
        householdId: membership.household.id,
        vehicleId: vehicleId,
      );
});
