import '../../../core/utils/money.dart';

enum TransactionType {
  income('income'),
  expense('expense');

  const TransactionType(this.dbValue);

  final String dbValue;

  static TransactionType fromDb(String value) => TransactionType.values
      .firstWhere((type) => type.dbValue == value);
}

/// One row of money movement (transactions table). Amounts are always
/// integer minor units - see [Money].
class Transaction {
  const Transaction({
    required this.id,
    required this.householdId,
    required this.type,
    required this.amountMinorUnits,
    required this.categoryId,
    required this.memberId,
    required this.date,
    this.note,
    this.vehicleId,
    this.petId,
    this.recurringRuleId,
    this.createdBy,
  });

  final String id;
  final String householdId;
  final TransactionType type;
  final int amountMinorUnits;
  final String categoryId;
  final String memberId;

  /// Calendar day of the transaction (time part is always midnight).
  final DateTime date;
  final String? note;
  final String? vehicleId;

  /// Pet this expense is attributed to, or null. Same-household enforced
  /// by RLS (migration 14).
  final String? petId;

  /// The recurring rule that generated this row, or null for manual
  /// entries. Set by the generator RPC (migration 13+).
  final String? recurringRuleId;
  final String? createdBy;
}

/// Columns every transaction read selects. `amount::text` keeps Postgres'
/// numeric(12,2) out of Dart's `double` world entirely - see AGENTS.md.
const String transactionColumns =
    'id, household_id, type, amount::text, category_id, member_id, '
    'vehicle_id, pet_id, recurring_rule_id, date, note, created_by';

/// Maps one PostgREST row to a [Transaction]. Shared by the list repository
/// and the export repository so both read identical values.
Transaction transactionFromRow(Map<String, dynamic> row) => Transaction(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      type: TransactionType.fromDb(row['type'] as String),
      amountMinorUnits:
          Money.decimalStringToMinorUnits(row['amount'] as String),
      categoryId: row['category_id'] as String,
      memberId: row['member_id'] as String,
      date: DateTime.parse(row['date'] as String),
      note: row['note'] as String?,
      vehicleId: row['vehicle_id'] as String?,
      petId: row['pet_id'] as String?,
      recurringRuleId: row['recurring_rule_id'] as String?,
      createdBy: row['created_by'] as String?,
    );
