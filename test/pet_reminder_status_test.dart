import 'package:family_income_expense_tracker/features/pets/domain/entities.dart';
import 'package:family_income_expense_tracker/features/pets/domain/pet_reminder_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reminder urgency and the next-due arithmetic are pure Dart, so the
/// thresholds (14 days) and the month-end clamping are pinned exactly.
PetReminder _reminder({
  DateTime? dueDate,
  int? repeatMonths,
  DateTime? doneAt,
  String id = 'r1',
}) =>
    PetReminder(
      id: id,
      householdId: 'h1',
      petId: 'p1',
      title: 'Rabies vaccine',
      kind: PetReminderKind.vaccine,
      dueDate: dueDate ?? DateTime(2026, 6, 20),
      repeatMonths: repeatMonths,
      doneAt: doneAt,
    );

void main() {
  final today = DateTime(2026, 6, 20);

  group('status', () {
    test('yesterday is overdue', () {
      expect(
        PetReminderStatuses.status(
          _reminder(dueDate: DateTime(2026, 6, 19)),
          today: today,
        ),
        PetReminderStatus.overdue,
      );
    });

    test('today is due soon, not overdue', () {
      expect(
        PetReminderStatuses.status(_reminder(dueDate: today), today: today),
        PetReminderStatus.dueSoon,
      );
    });

    test('the 14-day window is inclusive on both ends', () {
      expect(
        PetReminderStatuses.status(
          _reminder(dueDate: DateTime(2026, 6, 20, 23, 59)),
          today: today,
        ),
        PetReminderStatus.dueSoon,
      );
      expect(
        PetReminderStatuses.status(
          _reminder(dueDate: DateTime(2026, 7, 4)),
          today: today,
        ),
        PetReminderStatus.dueSoon,
        reason: 'exactly 14 days away',
      );
      expect(
        PetReminderStatuses.status(
          _reminder(dueDate: DateTime(2026, 7, 5)),
          today: today,
        ),
        PetReminderStatus.ok,
        reason: '15 days away',
      );
    });

    test('a done reminder is done even when its date has passed', () {
      expect(
        PetReminderStatuses.status(
          _reminder(
            dueDate: DateTime(2026, 1, 1),
            doneAt: DateTime(2026, 1, 2),
          ),
          today: today,
        ),
        PetReminderStatus.done,
      );
    });

    test('the window is 14 days', () {
      expect(PetReminderStatuses.dueSoonDays, 14);
    });

    test('isDone follows done_at', () {
      expect(_reminder().isDone, isFalse);
      expect(_reminder(doneAt: DateTime(2026, 6, 1)).isDone, isTrue);
    });
  });

  group('nextDueDate', () {
    test('a one-off has no next date', () {
      expect(PetReminderStatuses.nextDueDate(_reminder()), isNull);
    });

    test('monthly moves one month forward', () {
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2026, 6, 20), repeatMonths: 1),
        ),
        DateTime(2026, 7, 20),
      );
    });

    test('yearly moves twelve months forward', () {
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2026, 6, 20), repeatMonths: 12),
        ),
        DateTime(2027, 6, 20),
      );
    });

    test('a 31st is clamped to the target month length', () {
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2026, 1, 31), repeatMonths: 1),
        ),
        DateTime(2026, 2, 28),
        reason: '2026 is not a leap year',
      );
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2028, 1, 31), repeatMonths: 1),
        ),
        DateTime(2028, 2, 29),
        reason: '2028 is a leap year',
      );
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2026, 3, 31), repeatMonths: 1),
        ),
        DateTime(2026, 4, 30),
      );
    });

    test('a short month rolls across the year boundary', () {
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2026, 12, 15), repeatMonths: 1),
        ),
        DateTime(2027, 1, 15),
      );
      expect(
        PetReminderStatuses.nextDueDate(
          _reminder(dueDate: DateTime(2026, 11, 30), repeatMonths: 3),
        ),
        DateTime(2027, 2, 28),
      );
    });
  });

  group('sorted', () {
    test('open reminders come first, soonest at the top, done last', () {
      final list = [
        _reminder(id: 'done', doneAt: DateTime(2026, 5, 1)),
        _reminder(id: 'late', dueDate: DateTime(2026, 6, 1)),
        _reminder(id: 'soon', dueDate: DateTime(2026, 6, 25)),
        _reminder(id: 'done-2', dueDate: DateTime(2027, 1, 1)),
      ];
      // The second done one has done_at unset in the helper above (only
      // `dueDate` was passed), so make it explicit.
      final fixed = [
        list[0],
        list[1],
        list[2],
        _reminder(
          id: 'done-2',
          dueDate: DateTime(2027, 1, 1),
          doneAt: DateTime(2026, 5, 2),
        ),
      ];

      expect(
        PetReminderStatuses.sorted(fixed, today: today)
            .map((reminder) => reminder.id),
        ['late', 'soon', 'done', 'done-2'],
      );
    });

    test('two open reminders with the same date keep a stable order', () {
      final list = [
        _reminder(id: 'a', dueDate: DateTime(2026, 6, 25)),
        _reminder(id: 'b', dueDate: DateTime(2026, 6, 25)),
      ];
      final sorted = PetReminderStatuses.sorted(list, today: today);
      expect(sorted.map((reminder) => reminder.id), ['a', 'b']);
    });
  });
}
