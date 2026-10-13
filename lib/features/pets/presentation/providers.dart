import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../household/presentation/providers.dart';
import '../data/pets_repository_impl.dart';
import '../data/pet_reminders_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/pets_repository.dart';

final petsRepositoryProvider = Provider<PetsRepository>(
  (ref) => PetsRepositoryImpl(ref.watch(supabaseClientProvider)),
);

final petRemindersRepositoryProvider = Provider<PetRemindersRepository>(
  (ref) => PetRemindersRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// Reminders of one pet (family key = pet id). A child's RLS returns an
/// empty list, so the section renders as empty for them.
final petRemindersProvider =
    FutureProvider.family<List<PetReminder>, String>((ref, petId) {
  return ref
      .watch(petRemindersRepositoryProvider)
      .listReminders(petId: petId);
});

/// Pets of the current household. A child's RLS returns an empty list
/// (pets are an adult feature), so the UI must render that gracefully.
final petsProvider = FutureProvider<List<Pet>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Pet>[];
  return ref
      .watch(petsRepositoryProvider)
      .listPets(householdId: membership.household.id);
});
