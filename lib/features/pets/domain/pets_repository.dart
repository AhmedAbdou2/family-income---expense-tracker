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
