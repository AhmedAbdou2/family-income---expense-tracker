import 'entities.dart';

/// Pets of the household (owner/adult only - RLS narrows children to an
/// empty list). Writes go straight to the table.
abstract interface class PetsRepository {
  /// All pets, archived included (the UI filters), oldest first.
  Future<List<Pet>> listPets({required String householdId});

  /// One row by id, or null when it doesn't exist / RLS hides it.
  Future<Pet?> getPet({required String id});

  Future<Pet> createPet({
    required String householdId,
    required String name,
    required PetType type,
    DateTime? birthDate,
    String? notes,
  });

  Future<void> updatePet({
    required String id,
    required String name,
    required PetType type,
    required bool isActive,
    DateTime? birthDate,
    String? notes,
  });
}

/// Reminders of a pet. Adult-only: every write is an RPC, reads go through
/// the SELECT policy (a child sees zero rows).
abstract interface class PetRemindersRepository {
  /// All reminders of [petId], any state (the UI splits due vs done).
  Future<List<PetReminder>> listReminders({required String petId});

  Future<PetReminder> createReminder({
    required String petId,
    required String title,
    required PetReminderKind kind,
    required DateTime dueDate,
    int? repeatMonths,
  });

  /// Edits the schedule of a still-open reminder. Completed rows are kept
  /// as history and are not editable.
  Future<void> updateReminder({
    required String id,
    required String title,
    required PetReminderKind kind,
    required DateTime dueDate,
    int? repeatMonths,
  });

  /// Ticks the reminder off. When [amountMinorUnits] is given, a pet
  /// expense is posted in the same server-side call (categories: Vaccines
  /// for a vaccine, Vet otherwise); that needs the caller to have a person
  /// of their own, otherwise the RPC refuses with `no_linked_person` and
  /// writes nothing at all.
  Future<void> completeReminder({
    required String id,
    int? amountMinorUnits,
    String? note,
  });

  Future<void> deleteReminder({required String id});
}
