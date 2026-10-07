/// A person tracked inside a household (members table). Pure Dart - no
/// Flutter or Supabase imports.
class Member {
  const Member({
    required this.id,
    required this.householdId,
    required this.name,
    required this.isActive,
    this.avatar,
    this.userId,
  });

  final String id;
  final String householdId;
  final String name;
  final bool isActive;
  final String? avatar;

  /// Supabase Auth login linked to this person, null while unlinked.
  final String? userId;

  bool get isLinked => userId != null;
}
