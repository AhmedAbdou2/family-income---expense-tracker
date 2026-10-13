import 'entities.dart';

/// How urgent a pet reminder is, computed against today. Pure Dart so the
/// thresholds are unit-tested.
enum PetReminderStatus { done, ok, dueSoon, overdue }

abstract final class PetReminderStatuses {
  /// "Due soon" window, in days.
  static const int dueSoonDays = 14;

  static PetReminderStatus status(
    PetReminder reminder, {
    required DateTime today,
  }) {
    if (reminder.isDone) return PetReminderStatus.done;

    final day = DateTime(today.year, today.month, today.day);
    final due = DateTime(
      reminder.dueDate.year,
      reminder.dueDate.month,
      reminder.dueDate.day,
    );
    if (due.isBefore(day)) return PetReminderStatus.overdue;

    final soonest = day.add(const Duration(days: dueSoonDays));
    if (!due.isAfter(soonest)) return PetReminderStatus.dueSoon;
    return PetReminderStatus.ok;
  }

  /// The next due date a repeating reminder would schedule after
  /// completion: `dueDate + repeatMonths`. Null for a one-off.
  ///
  /// Clamps the day to the target month (Jan 31 + 1 month -> Feb 28/29) so
  /// the label never shows a rolled-over day.
  static DateTime? nextDueDate(PetReminder reminder) {
    final months = reminder.repeatMonths;
    if (months == null) return null;
    final base = reminder.dueDate;
    final targetMonth = base.month + months;
    final year = base.year + (targetMonth - 1) ~/ 12;
    final month = (targetMonth - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, base.day > lastDay ? lastDay : base.day);
  }

  /// Due reminders first (most overdue at the top), done ones last.
  static List<PetReminder> sorted(
    List<PetReminder> reminders, {
    required DateTime today,
  }) {
    final list = [...reminders];
    list.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return list;
  }
}
