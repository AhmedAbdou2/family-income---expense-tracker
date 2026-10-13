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

/// What a reminder is for. `vaccine`/`vet` also decide which pet category a
/// completed reminder's expense lands in (migration 17).
enum PetReminderKind {
  vaccine('vaccine'),
  vet('vet'),
  other('other');

  const PetReminderKind(this.dbValue);

  final String dbValue;

  static PetReminderKind fromDb(String value) => PetReminderKind.values
      .firstWhere((kind) => kind.dbValue == value);
}

/// A vaccine / vet-visit / other reminder for one pet.
///
/// Completing one sets [doneAt]; a repeating reminder inserts the NEXT row
/// server-side (same title/kind), so history is preserved as separate rows.
class PetReminder {
  const PetReminder({
    required this.id,
    required this.householdId,
    required this.petId,
    required this.title,
    required this.kind,
    required this.dueDate,
    this.repeatMonths,
    this.doneAt,
  });

  final String id;
  final String householdId;
  final String petId;
  final String title;
  final PetReminderKind kind;
  final DateTime dueDate;

  /// Repeat every N months (1..120), or null for a one-off.
  final int? repeatMonths;

  /// When it was ticked off, or null while it is still due.
  final DateTime? doneAt;

  bool get isDone => doneAt != null;
}
