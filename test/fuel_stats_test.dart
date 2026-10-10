import 'package:family_income_expense_tracker/features/vehicles/domain/entities.dart';
import 'package:family_income_expense_tracker/features/vehicles/domain/fuel_stats.dart';
import 'package:flutter_test/flutter_test.dart';

FuelLog _log({
  required double odometerKm,
  required double liters,
  required int costMinor,
  bool isFull = true,
  int day = 1,
}) {
  return FuelLog(
    id: 'log-$odometerKm',
    householdId: 'h1',
    vehicleId: 'v1',
    date: DateTime(2026, 1, day),
    odometerKm: odometerKm,
    liters: liters,
    totalCostMinorUnits: costMinor,
    isFull: isFull,
  );
}

void main() {
  group('FuelStats.compute', () {
    test('needs at least two logs', () {
      expect(FuelStats.compute(const []).hasData, isFalse);
      expect(
        FuelStats.compute([_log(odometerKm: 1000, liters: 30, costMinor: 30000)])
            .hasData,
        isFalse,
      );
    });

    test('full-to-full consumption and cost per km', () {
      final stats = FuelStats.compute([
        _log(odometerKm: 1000, liters: 30, costMinor: 30000),
        _log(odometerKm: 1300, liters: 30, costMinor: 30000, day: 10),
      ]);
      // 30 L over 300 km = 10 L/100km; 30000 minor over 300 km = 100/km.
      expect(stats.litersPer100Km, closeTo(10, 0.0001));
      expect(stats.costPerKmMinor, closeTo(100, 0.0001));
    });

    test('sorts by odometer regardless of input order', () {
      final stats = FuelStats.compute([
        _log(odometerKm: 1300, liters: 30, costMinor: 30000, day: 10),
        _log(odometerKm: 1000, liters: 30, costMinor: 30000),
      ]);
      expect(stats.litersPer100Km, closeTo(10, 0.0001));
    });

    test('a partial fill does not close a segment', () {
      final stats = FuelStats.compute([
        _log(odometerKm: 1000, liters: 30, costMinor: 30000),
        _log(odometerKm: 1150, liters: 20, costMinor: 20000, isFull: false, day: 5),
        _log(odometerKm: 1300, liters: 30, costMinor: 30000, day: 10),
      ]);
      // Distance spans 1000->1300 and ALL liters since the last full tank
      // count: 20 + 30 = 50 L over 300 km ~= 16.67 L/100km.
      expect(stats.litersPer100Km, closeTo(50 / 3, 0.0001));
      expect(stats.costPerKmMinor, closeTo(50000 / 300, 0.0001));
    });

    test('electric (0 liters) has no L/100km but keeps cost/km', () {
      final stats = FuelStats.compute([
        _log(odometerKm: 1000, liters: 0, costMinor: 40000),
        _log(odometerKm: 1200, liters: 0, costMinor: 40000, day: 10),
      ]);
      expect(stats.litersPer100Km, isNull);
      expect(stats.costPerKmMinor, closeTo(200, 0.0001));
    });
  });
}
