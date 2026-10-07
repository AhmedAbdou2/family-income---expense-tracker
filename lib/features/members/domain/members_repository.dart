import 'entities.dart';

/// People of a household. All writes go through RLS-protected tables:
/// owner/adult roles may create/edit/delete, a child sees (only) their own
/// row and can never write.
abstract interface class MembersRepository {
  Future<List<Member>> listMembers({required String householdId});

  Future<Member> createMember({
    required String householdId,
    required String name,
  });

  Future<void> renameMember({required String memberId, required String name});

  /// True when a person of [householdId] is linked to the caller's login.
  /// Used by the router to send legacy logins to /claim.
  Future<bool> hasLinkedPerson({required String householdId});

  Future<void> setMemberActive({
    required String memberId,
    required bool isActive,
  });

  Future<void> deleteMember({required String memberId});
}
