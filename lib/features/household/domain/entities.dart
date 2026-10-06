/// Household-related entities. Pure Dart - no Flutter or Supabase imports.
class Household {
  const Household({required this.id, required this.name, required this.currency});

  final String id;
  final String name;
  final String currency;
}

/// The caller's membership inside a household.
class Membership {
  const Membership({required this.household, required this.role});

  final Household household;
  final MemberRole role;
}

enum MemberRole {
  owner('owner'),
  adult('adult'),
  child('child');

  const MemberRole(this.dbValue);

  /// Value stored in `household_users.role` / `members` policies.
  final String dbValue;

  static MemberRole fromDb(String value) =>
      MemberRole.values.firstWhere((role) => role.dbValue == value);
}

class Invite {
  const Invite({
    required this.id,
    required this.code,
    required this.role,
    this.expiresAt,
    this.usedBy,
  });

  final String id;
  final String code;
  final MemberRole role;
  final DateTime? expiresAt;
  final String? usedBy;

  bool get isUsed => usedBy != null;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());

  bool get isActive => !isUsed && !isExpired;
}
