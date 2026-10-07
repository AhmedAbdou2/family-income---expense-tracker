import 'entities.dart';

/// Household contract. The Supabase implementation lives in `data/`; note
/// that household creation/joining/role changes go through SQL RPCs
/// (create_household / accept_invite / claim_member / update_household_role /
/// remove_household_login / leave_household), never through raw table writes.
abstract interface class HouseholdRepository {
  /// The caller's membership, or null when they belong to no household.
  Future<Membership?> currentMembership();

  /// Creates the household, seeds categories and creates the owner's own
  /// linked person in one step (`create_household`, migration 12).
  Future<void> createHousehold({
    required String name,
    required String currency,
    required String displayName,
  });

  /// Joins via a 6-char code (`accept_invite`, migration 12).
  ///
  /// - join-only invite: [displayName] is required (1-40 chars) and becomes
  ///   the joiner's own person;
  /// - person-bound invite: [displayName] is ignored - the joiner is linked
  ///   to the person the owner picked.
  Future<void> acceptInvite({required String code, String? displayName});

  /// Links the caller's login to a person of their household
  /// (`claim_member`) - for pre-existing logins created before migration 12.
  Future<void> claimMember({required String displayName});

  /// All logins of the household merged with their linked person.
  /// No emails are ever returned (`household_users` has no email column).
  Future<List<HouseholdLogin>> listLogins({required String householdId});

  /// Owner-only: promotes/demotes any login of the household
  /// (`update_household_role`). The RPC refuses self role changes.
  Future<void> updateHouseholdRole({
    required String householdId,
    required String userId,
    required MemberRole role,
  });

  /// Owner-only: removes another login from the household
  /// (`remove_household_login`). Self-removal is refused by the RPC.
  Future<void> removeHouseholdLogin({
    required String householdId,
    required String userId,
  });

  /// Leaves the current household (`leave_household`). Keeps the caller's
  /// person and transactions, just unlinks the login. The RPC refuses the
  /// last owner.
  Future<void> leaveHousehold();

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
