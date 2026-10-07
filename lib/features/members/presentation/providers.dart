import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_providers.dart';
import '../../auth/presentation/providers.dart';
import '../../household/presentation/providers.dart';
import '../data/members_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/members_repository.dart';

final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepositoryImpl(ref.watch(supabaseClientProvider)),
);

/// People of the current household. A child's RLS narrows this to their
/// own row, so every screen must render an empty list gracefully.
final membersProvider = FutureProvider<List<Member>>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  if (membership == null) return const <Member>[];
  return ref
      .watch(membersRepositoryProvider)
      .listMembers(householdId: membership.household.id);
});

/// Whether the caller's login is linked to a person of their household.
///
/// The router uses this to send legacy (pre-migration-12) logins to /claim.
/// Errors resolve to `true` (assume linked) so a transient failure can never
/// block the whole app behind the claim screen.
final linkedMemberProvider = FutureProvider<bool>((ref) async {
  final membership = ref.watch(membershipProvider).value;
  final userId = ref.watch(authStateProvider).value;
  if (membership == null || userId == null) return true;
  try {
    return await ref
        .watch(membersRepositoryProvider)
        .hasLinkedPerson(householdId: membership.household.id);
  } catch (_) {
    return true;
  }
});
