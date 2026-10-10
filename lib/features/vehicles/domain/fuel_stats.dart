import 'entities.dart';

/// Fuel-economy figures for one vehicle, derived purely from its logs.
///
/// Money stays in integer minor units: [costPerKmMinor] is a derived RATE
/// (minor units per km, e.g. 52.3 = 0.523 EGP/km). The UI rounds it to a
/// whole minor unit and hands it to `Money.format`, so no float ever
/// renders a ledger amount.
class FuelStats {
  const FuelStats({this.litersPer100Km, this.costPerKmMinor});

  /// Consumption over full-to-full segments (null when unknown / electric).
  final double? litersPer100Km;

  /// Average cost per kilometre, minor units per km.
  final double? costPerKmMinor;

  bool get hasData => litersPer100Km != null || costPerKmMinor != null;

  /// Full-to-full method: distance is measured between two consecutive
  /// *full* tanks, and the liters/cost of every fill in between (including
  /// the partial ones) are summed into that segment - a partial fill alone
  /// tells you nothing about what was burned since the last full tank.
  static FuelStats compute(List<FuelLog> logs) {
    if (logs.length < 2) return const FuelStats();

    final sorted = [...logs]..sort(
        (a, b) => a.odometerKm.compareTo(b.odometerKm),
      );

    var segmentKm = 0.0;
    var segmentLiters = 0.0;
    var segmentCostMinor = 0.0;

    double? lastFullOdometer;
    var pendingLiters = 0.0;
    var pendingCostMinor = 0.0;

    for (final log in sorted) {
      if (lastFullOdometer == null) {
        // Nothing measurable until the first full tank anchors a segment.
        if (log.isFull) lastFullOdometer = log.odometerKm;
        continue;
      }
      pendingLiters += log.liters;
      pendingCostMinor += log.totalCostMinorUnits.toDouble();
      if (!log.isFull) continue;

      final km = log.odometerKm - lastFullOdometer;
      if (km > 0) {
        segmentKm += km;
        segmentLiters += pendingLiters;
        segmentCostMinor += pendingCostMinor;
      }
      lastFullOdometer = log.odometerKm;
      pendingLiters = 0;
      pendingCostMinor = 0;
    }

    if (segmentKm <= 0) return const FuelStats();

    return FuelStats(
      // An EV logs 0 liters: consumption is meaningless, cost/km is not.
      litersPer100Km:
          segmentLiters > 0 ? (segmentLiters * 100) / segmentKm : null,
      costPerKmMinor: segmentCostMinor / segmentKm,
    );
  }
}
