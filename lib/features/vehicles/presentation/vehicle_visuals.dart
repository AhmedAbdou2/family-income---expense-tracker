import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../domain/entities.dart';

String fuelTypeLabel(BuildContext context, FuelType type) {
  final l10n = context.l10n;
  return switch (type) {
    FuelType.petrol => l10n.fuel_type_petrol,
    FuelType.diesel => l10n.fuel_type_diesel,
    FuelType.electric => l10n.fuel_type_electric,
    FuelType.hybrid => l10n.fuel_type_hybrid,
  };
}

IconData fuelTypeIcon(FuelType type) => switch (type) {
      FuelType.electric => Icons.electric_bolt_rounded,
      FuelType.hybrid => Icons.eco_rounded,
      _ => Icons.local_gas_station_outlined,
    };
