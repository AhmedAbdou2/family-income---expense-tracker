import 'entities.dart';

/// Money movement. All writes hit the `transactions` table directly;
/// RLS narrows children to their own linked person.
abstract interface class TransactionsRepository {
  /// Transactions of one calendar [month], newest first. When [memberId]
  /// is given only that person's rows are returned; [petId] narrows to one
  /// pet.
  Future<List<Transaction>> listTransactions({
    required String householdId,
    required DateTime month,
    String? memberId,
    String? petId,
  });

  /// One row by id, or null when it doesn't exist / RLS hides it.
  Future<Transaction?> getTransaction({required String id});

  Future<Transaction> createTransaction({
    required String householdId,
    required TransactionType type,
    required int amountMinorUnits,
    required String categoryId,
    required String memberId,
    required DateTime date,
    String? note,
    String? petId,
  });

  Future<void> updateTransaction({
    required String id,
    required TransactionType type,
    required int amountMinorUnits,
    required String categoryId,
    required String memberId,
    required DateTime date,
    String? note,
    String? petId,
  });

  /// Deletes the row and returns the storage paths of its receipts (the
  /// metadata rows cascade away). The caller removes those objects from the
  /// private bucket; an empty list means there was nothing attached.
  Future<List<String>> deleteTransaction({required String id});
}
