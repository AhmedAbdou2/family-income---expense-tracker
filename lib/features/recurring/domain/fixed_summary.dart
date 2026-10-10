import 'entities.dart';

/// This-month summary of a household's fixed commitments (recurring rules).
///
/// Expense rules only: occurrences already posted (date <= today) and
/// occurrences still due (date > today) inside [month]. Income rules are
/// ignored here - the dashboard combines this with the month's actual
/// income to show what is left after fixed costs.
class FixedMonthSummary {
  const FixedMonthSummary({required this.postedMinor, required this.dueMinor});

  const FixedMonthSummary.empty() : postedMinor = 0, dueMinor = 0;

  final int postedMinor;
  final int dueMinor;

  int get totalMinor => postedMinor + dueMinor;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

List<int> _occurrenceDays(
  RecurringRule rule,
  DateTime monthStart,
  int daysInMonth,
) {
  switch (rule.frequency) {
    case RecurrenceFrequency.monthly:
      final anchorDay =
          rule.dayOfMonth ?? rule.startDate?.day ?? rule.nextDue.day;
      return [anchorDay > daysInMonth ? daysInMonth : anchorDay];
    case RecurrenceFrequency.yearly:
      final anchor = rule.startDate ?? rule.nextDue;
      if (anchor.month != monthStart.month) return const [];
      return [anchor.day > daysInMonth ? daysInMonth : anchor.day];
    case RecurrenceFrequency.weekly:
      final anchor = _dateOnly(rule.startDate ?? rule.nextDue);
      final days = <int>[];
      for (var day = 1; day <= daysInMonth; day++) {
        final date = DateTime(monthStart.year, monthStart.month, day);
        if (date.isBefore(anchor)) continue;
        if (date.difference(anchor).inDays % 7 == 0) days.add(day);
      }
      return days;
  }
}

/// Splits fixed expense occurrences of [month] into posted vs still-due.
FixedMonthSummary fixedMonthSummary({
  required List<RecurringRule> rules,
  required Set<String> incomeCategoryIds,
  required DateTime month,
  DateTime? today,
}) {
  final reference = today ?? DateTime.now();
  final monthStart = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

  var posted = 0;
  var due = 0;
  for (final rule in rules) {
    if (!rule.isActive) continue;
    if (incomeCategoryIds.contains(rule.categoryId)) continue;
    final ruleStart = rule.startDate == null ? null : _dateOnly(rule.startDate!);
    final ruleEnd = rule.endDate == null ? null : _dateOnly(rule.endDate!);
    for (final day in _occurrenceDays(rule, monthStart, daysInMonth)) {
      final occurs = DateTime(month.year, month.month, day);
      if (ruleStart != null && occurs.isBefore(ruleStart)) continue;
      if (ruleEnd != null && occurs.isAfter(ruleEnd)) continue;
      if (!occurs.isAfter(reference)) {
        posted += rule.amountMinorUnits;
      } else {
        due += rule.amountMinorUnits;
      }
    }
  }
  return FixedMonthSummary(postedMinor: posted, dueMinor: due);
}
