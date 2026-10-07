import 'entities.dart';

/// Household contract. The Supabase implementation lives in `data/`; note
/// that household creation/joining go through SQL RPCs (create_household /
/// accept_invite), never through table inserts.
abstract interface class HouseholdRepository {
  /// The caller's membership, or null when they belong to no household.
  Future<Membership?> currentMembership();

  Future<void> createHousehold({required String name, required String currency});

  Future<void> acceptInvite({required String code});

  /// Returns the freshly generated 6-character code. When [memberId] is
  /// given the invite is bound to that (still unlinked) person: whoever
  /// accepts is linked to them automatically (migration 11).
  Future<String> createInvite({
    required String householdId,
    required MemberRole role,
    int ttlDays = 7,
    String? memberId,
  });

  Future<List<Invite>> listInvites({required String householdId});
}
