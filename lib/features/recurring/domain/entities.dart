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
    this.vehicleId,
    this.petId,
    this.archivedAt,
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

  /// Optional links copied onto each generated transaction.
  final String? vehicleId;
  final String? petId;

  /// Set when the rule was archived (migration 15). An archived rule is
  /// inactive, hidden from the list, never generated again, but the
  /// transactions it already posted keep their `recurringRuleId` link - so
  /// past/current-month figures do not move.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}
