import 'package:family_income_expense_tracker/features/recurring/domain/entities.dart';
import 'package:family_income_expense_tracker/features/recurring/domain/recurring_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringRule _rule({
  required RecurrenceFrequency frequency,
  required DateTime start,
  int? dayOfMonth,
  DateTime? end,
  DateTime? nextDue,
}) =>
    RecurringRule(
      id: 'r1',
      householdId: 'h1',
      categoryId: 'cat-expense',
      memberId: 'm1',
      amountMinorUnits: 100000,
      frequency: frequency,
      nextDue: nextDue ?? start,
      isActive: true,
      dayOfMonth: dayOfMonth,
      startDate: start,
      endDate: end,
    );

void main() {
  final now = DateTime(2026, 10, 10);

  group('firstOccurrence (monthly start-date cases)', () {
    test('a) start earlier this month posts on the chosen day this month', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 10, 5),
          dayOfMonth: 10,
          now: now,
        ),
        DateTime(2026, 10, 10),
      );
    });

    test('b) start today stays today', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 10, 10),
          dayOfMonth: 10,
          now: now,
        ),
        DateTime(2026, 10, 10),
      );
    });

    test('c) start later this month keeps the later day', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 10, 10),
          dayOfMonth: 25,
          now: now,
        ),
        DateTime(2026, 10, 25),
      );
    });

    test('d) start next month is not pulled back', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 11, 1),
          dayOfMonth: 5,
          now: now,
        ),
        DateTime(2026, 11, 5),
      );
    });

    test('a start months ago is clamped to the CURRENT month only', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 7, 20),
          dayOfMonth: 20,
          now: now,
        ),
        DateTime(2026, 10, 20),
      );
    });

    test('the day is clamped to the month length', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 2, 1),
          dayOfMonth: 31,
          now: DateTime(2026, 2, 5),
        ),
        DateTime(2026, 2, 28),
      );
    });

    test('weekly/yearly use the start date itself', () {
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.weekly,
          start: DateTime(2026, 10, 3),
          now: now,
        ),
        DateTime(2026, 10, 3),
      );
      expect(
        firstOccurrence(
          frequency: RecurrenceFrequency.yearly,
          start: DateTime(2026, 3, 15),
          now: now,
        ),
        DateTime(2026, 3, 15),
      );
    });
  });

  group('resolveNextDue (edit keeps a future cursor)', () {
    test('future cursor month is kept, only the day is re-aligned', () {
      expect(
        resolveNextDue(
          frequency: RecurrenceFrequency.monthly,
          existingNextDue: DateTime(2026, 11, 1),
          start: DateTime(2026, 10, 10),
          dayOfMonth: 5,
          now: now,
        ),
        DateTime(2026, 11, 5),
      );
    });

    test('a future occurrence later this month is kept', () {
      expect(
        resolveNextDue(
          frequency: RecurrenceFrequency.monthly,
          existingNextDue: DateTime(2026, 10, 25),
          start: DateTime(2026, 10, 10),
          dayOfMonth: 25,
          now: now,
        ),
        DateTime(2026, 10, 25),
      );
    });

    test('a past cursor is recomputed so it can still catch up', () {
      expect(
        resolveNextDue(
          frequency: RecurrenceFrequency.monthly,
          existingNextDue: DateTime(2026, 9, 1),
          start: DateTime(2026, 9, 1),
          dayOfMonth: 20,
          now: now,
        ),
        DateTime(2026, 10, 20),
      );
    });
  });

  group('nextOccurrenceOnOrAfter (resume does not backfill the pause)', () {
    test('monthly resumes on the next day-of-month on or after today', () {
      expect(
        nextOccurrenceOnOrAfter(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 8, 20),
          dayOfMonth: 20,
          now: now,
        ),
        DateTime(2026, 10, 20),
      );
    });

    test('monthly with a day already passed resumes next month', () {
      expect(
        nextOccurrenceOnOrAfter(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 8, 3),
          dayOfMonth: 3,
          now: now,
        ),
        DateTime(2026, 11, 3),
      );
    });

    test('monthly on exactly today keeps today', () {
      expect(
        nextOccurrenceOnOrAfter(
          frequency: RecurrenceFrequency.monthly,
          start: DateTime(2026, 8, 10),
          dayOfMonth: 10,
          now: now,
        ),
        DateTime(2026, 10, 10),
      );
    });

    test('weekly resumes on the next 7-day step, not the paused anchor', () {
      // Anchor Oct 1; paused through Oct 10 -> next step is Oct 15.
      expect(
        nextOccurrenceOnOrAfter(
          frequency: RecurrenceFrequency.weekly,
          start: DateTime(2026, 10, 1),
          now: now,
        ),
        DateTime(2026, 10, 15),
      );
    });

    test('yearly resumes this year when the date is still ahead', () {
      expect(
        nextOccurrenceOnOrAfter(
          frequency: RecurrenceFrequency.yearly,
          start: DateTime(2020, 12, 25),
          now: now,
        ),
        DateTime(2026, 12, 25),
      );
    });

    test('yearly resumes next year when this year has passed', () {
      expect(
        nextOccurrenceOnOrAfter(
          frequency: RecurrenceFrequency.yearly,
          start: DateTime(2020, 3, 15),
          now: now,
        ),
        DateTime(2027, 3, 15),
      );
    });
  });

  group('occurrencesInMonth', () {
    test('monthly compares by month, so a day before start still counts', () {
      final rule = _rule(
        frequency: RecurrenceFrequency.monthly,
        start: DateTime(2026, 10, 10),
        dayOfMonth: 1,
      );
      expect(occurrencesInMonth(rule, DateTime(2026, 10)), [
        DateTime(2026, 10, 1),
      ]);
    });

    test('a start in a previous month is not backfilled but reaches forward',
        () {
      final rule = _rule(
        frequency: RecurrenceFrequency.monthly,
        start: DateTime(2026, 8, 20),
        dayOfMonth: 20,
      );
      expect(occurrencesInMonth(rule, DateTime(2026, 10)), [
        DateTime(2026, 10, 20),
      ]);
    });

    test('a rule starting next month has no occurrence this month', () {
      final rule = _rule(
        frequency: RecurrenceFrequency.monthly,
        start: DateTime(2026, 11, 5),
        dayOfMonth: 5,
      );
      expect(occurrencesInMonth(rule, DateTime(2026, 10)), isEmpty);
    });

    test('occurrences after the end date are dropped', () {
      final rule = _rule(
        frequency: RecurrenceFrequency.monthly,
        start: DateTime(2026, 1, 10),
        dayOfMonth: 10,
        end: DateTime(2026, 9, 30),
      );
      expect(occurrencesInMonth(rule, DateTime(2026, 10)), isEmpty);
    });
  });
}
