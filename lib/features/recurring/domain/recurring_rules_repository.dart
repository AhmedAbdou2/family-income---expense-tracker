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
  });

  Future<void> deleteRule({required String id});

  /// Generate every due occurrence for the caller's households. Returns
  /// how many transactions were created (0 when nothing was due). Safe to
  /// call on every app open - duplicates are impossible.
  Future<int> generateDue();
}
