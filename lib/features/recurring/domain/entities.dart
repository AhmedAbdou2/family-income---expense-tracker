/// Recurring fixed commitments (rent, installments, subscriptions,
/// salaries). Pure Dart - no Flutter or Supabase imports.
///
/// `type` (income/expense) is NOT stored twice: it is derived from the
/// category's group, exactly like the generator RPC does.
enum RecurrenceFrequency {
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequency(this.dbValue);

  final String dbValue;

  static RecurrenceFrequency fromDb(String value) => RecurrenceFrequency.values
      .firstWhere((frequency) => frequency.dbValue == value);
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.householdId,
    required this.categoryId,
    required this.memberId,
    required this.amountMinorUnits,
    required this.frequency,
    required this.nextDue,
    required this.isActive,
    this.name,
    this.dayOfMonth,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String householdId;
  final String categoryId;
  final String memberId;
  final int amountMinorUnits;
  final RecurrenceFrequency frequency;

  /// Cursor the generator walks forward from. Written on create/update.
  final DateTime nextDue;
  final bool isActive;
  final String? name;
  final int? dayOfMonth;
  final DateTime? startDate;
  final DateTime? endDate;
}
