import 'package:family_income_expense_tracker/features/vehicles/domain/entities.dart';
import 'package:family_income_expense_tracker/features/vehicles/domain/maintenance_status.dart';
import 'package:flutter_test/flutter_test.dart';

MaintenanceItem _item({DateTime? dueDate, double? dueOdometerKm}) {
  return MaintenanceItem(
    id: 'm1',
    householdId: 'h1',
    vehicleId: 'v1',
    name: 'Oil change',
    dueDate: dueDate,
    dueOdometerKm: dueOdometerKm,
  );
}

void main() {
  final today = DateTime(2026, 6, 15);

  MaintenanceStatus status(MaintenanceItem item, {double odo = 10000}) =>
      MaintenanceReminder.status(item, today: today, currentOdometerKm: odo);

  group('MaintenanceReminder.status', () {
    test('overdue when the due date has passed', () {
      expect(
        status(_item(dueDate: DateTime(2026, 6, 14))),
        MaintenanceStatus.overdue,
      );
    });

    test('overdue when the odometer has been reached', () {
      expect(
        status(_item(dueOdometerKm: 10000)),
        MaintenanceStatus.overdue,
      );
      expect(
        status(_item(dueOdometerKm: 9000)),
        MaintenanceStatus.overdue,
      );
    });

    test('due soon within the day window', () {
      expect(
        status(_item(dueDate: DateTime(2026, 6, 22))),
        MaintenanceStatus.dueSoon,
      );
      // Today itself is not overdue (only strictly-before counts).
      expect(
        status(_item(dueDate: DateTime(2026, 6, 15))),
        MaintenanceStatus.dueSoon,
      );
    });

    test('due soon within the km window', () {
      expect(
        status(_item(dueOdometerKm: 10500)),
        MaintenanceStatus.dueSoon,
      );
    });

    test('ok when both triggers are far away', () {
      expect(
        status(_item(
          dueDate: DateTime(2026, 7, 15),
          dueOdometerKm: 12000,
        )),
        MaintenanceStatus.ok,
      );
    });

    test('ignores missing fields', () {
      expect(status(_item()), MaintenanceStatus.ok);
      expect(
        status(_item(dueDate: DateTime(2026, 7, 15))),
        MaintenanceStatus.ok,
      );
    });
  });
}
