import 'entities.dart';

/// Recurring fixed commitments. Rules are plain rows (owner/adult only);
/// generating the due transactions is an idempotent RPC run on app open.
abstract interface class RecurringRulesRepository {
  Future<List<RecurringRule>> listRules({required String householdId});

  /// One rule by id, or null when it doesn't exist / RLS hides it.
  Future<RecurringRule?> getRule({required String id});

  Future<RecurringRule> createRule({
    required String householdId,
    required String categoryId,
    required String memberId,
    required int amountMinorUnits,
    required RecurrenceFrequency frequency,
    int? dayOfMonth,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? vehicleId,
    String? petId,
  });

  Future<void> updateRule({
    required String id,
    required String categoryId,
    required String memberId,
    required int amountMinorUnits,
    required RecurrenceFrequency frequency,
    required DateTime nextDue,
    required bool isActive,
    int? dayOfMonth,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? vehicleId,
    String? petId,
  });

  /// Archives a rule instead of deleting it (migration 15). The rule becomes
  /// inactive and hidden, but the transactions it already posted keep their
  /// link, so past/current-month dashboard figures do not change.
  ///
  /// When [deleteMonthTransactions] is true, this rule's already-posted rows
  /// of the current calendar month are deleted in the SAME server-side call
  /// (atomic - if anything fails, nothing is deleted and the rule stays
  /// live). The result carries how many transactions were deleted (0 for a
  /// plain archive) plus the storage paths of every receipt that went with
  /// them, so the caller can clean the objects up.
  Future<ArchiveRuleResult> archiveRule({
    required String id,
    bool deleteMonthTransactions = false,
  });

  /// Pauses or resumes a rule. When resuming, [nextDue] advances the cursor
  /// so the paused period is not backfilled.
  Future<void> setRuleActive({
    required String id,
    required bool isActive,
    DateTime? nextDue,
  });

  /// Generate every due occurrence for the caller's households. Returns
  /// how many transactions were created (0 when nothing was due). Safe to
  /// call on every app open - duplicates are impossible.
  Future<int> generateDue();
}
