import 'entities.dart';

/// How urgent a maintenance reminder is, computed against the current date
/// and the vehicle's odometer. Pure Dart so the thresholds are unit-tested.
enum MaintenanceStatus { ok, dueSoon, overdue }

abstract final class MaintenanceReminder {
  /// "Due soon" window: within this many days or this many km.
  static const int dueSoonDays = 7;
  static const double dueSoonKm = 500;

  static MaintenanceStatus status(
    MaintenanceItem item, {
    required DateTime today,
    required double currentOdometerKm,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final dueDate = item.dueDate;

    final dateOverdue = dueDate != null && dueDate.isBefore(day);
    final odometerOverdue =
        item.dueOdometerKm != null && item.dueOdometerKm! <= currentOdometerKm;
    if (dateOverdue || odometerOverdue) return MaintenanceStatus.overdue;

    final soonest = day.add(const Duration(days: dueSoonDays));
    final dateSoon = dueDate != null && !dueDate.isAfter(soonest);
    final odometerSoon = item.dueOdometerKm != null &&
        item.dueOdometerKm! - currentOdometerKm <= dueSoonKm;
    if (dateSoon || odometerSoon) return MaintenanceStatus.dueSoon;

    return MaintenanceStatus.ok;
  }
}
