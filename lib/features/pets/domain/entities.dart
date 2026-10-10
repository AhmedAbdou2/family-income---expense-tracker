/// Pets (Phase 3.5). Pure Dart - no Flutter or Supabase imports.
///
/// A pet is a light household record used to attribute expenses (mirrors
/// vehicles). Reminders for pets are a later phase; this only stores the
/// pet itself plus optional birth date / notes.
enum PetType {
  cat('cat'),
  dog('dog'),
  bird('bird'),
  fish('fish'),
  other('other');

  const PetType(this.dbValue);

  final String dbValue;

  static PetType fromDb(String value) =>
      PetType.values.firstWhere((type) => type.dbValue == value);
}

/// A pet of the household. Archived (isActive == false) pets stay for
/// history but are hidden from pickers.
class Pet {
  const Pet({
    required this.id,
    required this.householdId,
    required this.name,
    required this.type,
    required this.isActive,
    this.birthDate,
    this.notes,
  });

  final String id;
  final String householdId;
  final String name;
  final PetType type;
  final DateTime? birthDate;
  final String? notes;
  final bool isActive;
}
