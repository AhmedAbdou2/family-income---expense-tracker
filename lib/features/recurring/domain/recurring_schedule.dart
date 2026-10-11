import 'entities.dart';

/// Number of days in a calendar month.
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _monthOnly(DateTime value) => DateTime(value.year, value.month);

int _clampDay(int day, int year, int month) =>
    day.clamp(1, daysInMonth(year, month));

/// The FIRST occurrence date a rule should post.
///
/// - **monthly**: the start date selects the *starting month*; `dayOfMonth`
///   selects the day. A start month earlier than [now]'s month is clamped to
///   the current month, so a new rule only catches up the CURRENT month
///   (never backfills older months).
/// - **weekly / yearly**: the start date is the first occurrence itself.
///
/// This is the single source of truth the app writes to `next_due`; the RPC
/// generator then walks forward from that date.
DateTime firstOccurrence({
  required RecurrenceFrequency frequency,
  required DateTime start,
  int? dayOfMonth,
  required DateTime now,
}) {
  final startDate = dateOnly(start);
  switch (frequency) {
    case RecurrenceFrequency.monthly:
      var month = _monthOnly(startDate);
      final currentMonth = _monthOnly(dateOnly(now));
      if (month.isBefore(currentMonth)) month = currentMonth;
      return DateTime(
        month.year,
        month.month,
        _clampDay(dayOfMonth ?? startDate.day, month.year, month.month),
      );
    case RecurrenceFrequency.weekly:
    case RecurrenceFrequency.yearly:
      return startDate;
  }
}

/// Cursor to store after an edit.
///
/// [existingNextDue] is the rule's current cursor. When it is still in the
/// future the cursor has already moved past this month's occurrence (or the
/// rule starts later), so we keep it - only re-aligning the day for a
/// monthly rule. When it is today/past the rule has not generated yet, so we
/// fall back to [firstOccurrence] and let the idempotent generator catch up.
DateTime resolveNextDue({
  required RecurrenceFrequency frequency,
  DateTime? existingNextDue,
  required DateTime start,
  int? dayOfMonth,
  required DateTime now,
}) {
  final nowDate = dateOnly(now);
  final first = firstOccurrence(
    frequency: frequency,
    start: start,
    dayOfMonth: dayOfMonth,
    now: now,
  );
  if (existingNextDue == null) return first;
  final cursor = dateOnly(existingNextDue);
  if (!cursor.isAfter(nowDate)) return first;
  if (frequency != RecurrenceFrequency.monthly) return cursor;

  final month = _monthOnly(cursor);
  final day = _clampDay(dayOfMonth ?? cursor.day, month.year, month.month);
  final aligned = DateTime(month.year, month.month, day);
  if (aligned.isAfter(nowDate)) return aligned;

  final nextMonth = DateTime(month.year, month.month + 1);
  return DateTime(
    nextMonth.year,
    nextMonth.month,
    _clampDay(dayOfMonth ?? cursor.day, nextMonth.year, nextMonth.month),
  );
}

/// The FIRST occurrence on or after [now] for a rule being resumed.
///
/// Advancing the cursor this way means a paused rule never backfills the
/// period it was paused: resuming continues from the next occurrence today
/// or later.
DateTime nextOccurrenceOnOrAfter({
  required RecurrenceFrequency frequency,
  DateTime? start,
  int? dayOfMonth,
  required DateTime now,
}) {
  final today = dateOnly(now);
  switch (frequency) {
    case RecurrenceFrequency.monthly:
      final day = dayOfMonth ?? start?.day ?? today.day;
      final thisMonth = DateTime(
        today.year,
        today.month,
        day.clamp(1, daysInMonth(today.year, today.month)),
      );
      if (!thisMonth.isBefore(today)) return thisMonth;
      final next = DateTime(today.year, today.month + 1);
      return DateTime(
        next.year,
        next.month,
        day.clamp(1, daysInMonth(next.year, next.month)),
      );
    case RecurrenceFrequency.weekly:
      final anchor = dateOnly(start ?? today);
      if (anchor.isAfter(today)) return anchor;
      final steps = (today.difference(anchor).inDays / 7).ceil();
      return anchor.add(Duration(days: steps * 7));
    case RecurrenceFrequency.yearly:
      final anchor = start ?? today;
      var candidate = DateTime(
        today.year,
        anchor.month,
        anchor.day.clamp(1, daysInMonth(today.year, anchor.month)),
      );
      if (candidate.isBefore(today)) {
        candidate = DateTime(
          today.year + 1,
          anchor.month,
          anchor.day.clamp(1, daysInMonth(today.year + 1, anchor.month)),
        );
      }
      return candidate;
  }
}

/// Occurrence dates of [rule] that fall inside [month].
///
/// Monthly rules compare by MONTH (not by the exact day), so an occurrence
/// whose day is earlier than the start date's day still belongs to the start
/// month - that is what makes a current-month catch-up possible. Dates
/// outside `[startDate, endDate]` are excluded.
List<DateTime> occurrencesInMonth(RecurringRule rule, DateTime month) {
  final monthStart = _monthOnly(month);
  final days = daysInMonth(monthStart.year, monthStart.month);
  final ruleStart = rule.startDate == null ? null : dateOnly(rule.startDate!);
  final ruleEnd = rule.endDate == null ? null : dateOnly(rule.endDate!);
  final results = <DateTime>[];

  void add(int day) {
    final occurs = DateTime(monthStart.year, monthStart.month, day);
    if (ruleStart != null) {
      final startMonth = _monthOnly(ruleStart);
      if (monthStart.isBefore(startMonth)) return;
      if (rule.frequency != RecurrenceFrequency.monthly &&
          occurs.isBefore(ruleStart)) {
        return;
      }
    }
    if (ruleEnd != null && occurs.isAfter(ruleEnd)) return;
    results.add(occurs);
  }

  switch (rule.frequency) {
    case RecurrenceFrequency.monthly:
      final anchorDay =
          rule.dayOfMonth ?? rule.startDate?.day ?? rule.nextDue.day;
      add(anchorDay > days ? days : anchorDay);
    case RecurrenceFrequency.yearly:
      final anchor = rule.startDate ?? rule.nextDue;
      if (anchor.month != monthStart.month) return const [];
      add(anchor.day > days ? days : anchor.day);
    case RecurrenceFrequency.weekly:
      final anchor = dateOnly(rule.startDate ?? rule.nextDue);
      for (var day = 1; day <= days; day++) {
        final date = DateTime(monthStart.year, monthStart.month, day);
        if (date.isBefore(anchor)) continue;
        if (date.difference(anchor).inDays % 7 == 0) add(day);
      }
  }
  return results;
}
