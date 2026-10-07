import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../auth/presentation/providers.dart';
import '../data/household_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// The caller's current membership. null while signed out or when the user
/// belongs to no household yet (router sends them to /setup in that case).
final membershipProvider = FutureProvider<Membership?>((ref) async {
  final userId = ref.watch(authStateProvider).value;
  if (userId == null) return null;
  return ref.watch(householdRepositoryProvider).currentMembership();
});

/// Invite codes of the current household (settings screen).
final invitesProvider = FutureProvider<List<Invite>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Invite>[];
  return ref
      .watch(householdRepositoryProvider)
      .listInvites(householdId: membership.household.id);
});

/// All logins of the current household, merged with their linked person
/// (Household-members screen + Settings leave-row owner count). Readable by
/// every member - `household_users` has no emails, only user id / role /
/// joined-at / linked person name.
final householdLoginsProvider = FutureProvider<List<HouseholdLogin>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <HouseholdLogin>[];
  return ref
      .watch(householdRepositoryProvider)
      .listLogins(householdId: membership.household.id);
});
