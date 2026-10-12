import 'entities.dart';
import 'recurring_schedule.dart';

/// This-month summary of a household's fixed commitments (recurring rules).
///
/// Expense rules only: occurrences already posted (date <= today) and
/// occurrences still due (date > today) inside [month]. Income rules are
/// ignored here - the dashboard combines this with the month's actual
/// income to show what is left after fixed costs.
///
/// Note the dashboard takes its *posted* figure from the real posted
/// transactions (single source of truth) and uses [dueMinor] from here for
/// "still due"; [postedMinor] is a rule-level projection used by tests.
class FixedMonthSummary {
  const FixedMonthSummary({required this.postedMinor, required this.dueMinor});

  const FixedMonthSummary.empty() : postedMinor = 0, dueMinor = 0;

  final int postedMinor;
  final int dueMinor;

  int get totalMinor => postedMinor + dueMinor;
}

/// Splits fixed expense occurrences of [month] into posted vs still-due.
FixedMonthSummary fixedMonthSummary({
  required List<RecurringRule> rules,
  required Set<String> incomeCategoryIds,
  required DateTime month,
  DateTime? today,
}) {
  final reference = today ?? DateTime.now();

  var posted = 0;
  var due = 0;
  for (final rule in rules) {
    if (!rule.isActive) continue;
    if (rule.isArchived) continue;
    if (incomeCategoryIds.contains(rule.categoryId)) continue;
    for (final occurs in occurrencesInMonth(rule, month)) {
      if (!occurs.isAfter(reference)) {
        posted += rule.amountMinorUnits;
      } else {
        due += rule.amountMinorUnits;
      }
    }
  }
  return FixedMonthSummary(postedMinor: posted, dueMinor: due);
}
