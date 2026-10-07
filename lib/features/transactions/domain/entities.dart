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
  final String? createdBy;
}
